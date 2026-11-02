// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "NetworkSession.h"
#include "PreparedSession.h"
#include <QElapsedTimer>
#include <QProcess>
#include <QtEndian>
#include <array>
#include <deque>
#include <map>
#include <memory>
#include <functional>
#include <cstring>

namespace traineros::ds {
// DetMP still owns emulation. This coordinator exchanges each owner's inputs
// and opaque cartridge seed over the existing authenticated record helper.
// Host routes a bounded star: each private endpoint belongs to one Lobby seat.
class GroupRemoteSession final : public NetworkSession {
    using Check=std::pair<uint32_t,uint32_t>;
    struct Out {QByteArray data;bool finish=false;};
    struct Link {
        QProcess process;QByteArray buffer;
        std::deque<Out> out;
        std::deque<bool> awaiting;
        std::map<qint64,bool> pending;
        qint64 sent=0,received=0;
        bool connected=false,endpoint=false,finishAck=false,closed=false;
    };
    struct State {
        bool hello=false,offered=false,received=false,taken=false,machines=false,retained=false;
        QString digest;
        std::optional<std::vector<uint8_t>> bytes;
        std::array<bool,4> receipts{};
        std::optional<uint32_t> end;
        uint32_t nextInput=0;
        int pongs=0;
        std::map<uint32_t,FrameInput> inputs;
        std::map<Check,uint64_t> checks;
    };
public:
    GroupRemoteSession(const QJsonObject& config,const QString& admission,unsigned owner,
                       std::function<void(QJsonObject)> endpoint,std::optional<OwnerSeed> seed)
        : count(config["players"].toInt()),owner(owner),admission(admission),endpoint(std::move(endpoint)),seed(std::move(seed)) {
        if(count<3||count>4||owner>=count||!config["host"].isBool()||config["host"].toBool()!=(owner==0)
            ||!StateDigest(config["identity"].toString())||!StateDigest(admission)
            ||!QFileInfo(config["python"].toString()).isExecutable()||!QFileInfo(config["helper"].toString()).isFile()
            ||!this->seed||this->seed->expectedSize>MaxCartridgeSaveBytes
            ||(this->seed->bytes&&(this->seed->bytes->empty()||this->seed->bytes->size()!=this->seed->expectedSize)))
            throw std::runtime_error("Invalid DS group preparation");
        auto& own=states[owner];own.hello=own.offered=own.received=true;
        own.digest=this->seed->bytes?StateHash(QByteArray(reinterpret_cast<const char*>(this->seed->bytes->data()),this->seed->bytes->size())):"fresh";
        own.receipts[owner]=true;
        clock.start();lastAdvance=0;
        for(unsigned peer=0;peer<count;++peer)if(peer!=owner&&(owner==0||peer==0)) {
            const unsigned guest=owner?owner:peer;
            auto link=std::make_unique<Link>();auto* l=link.get();links[peer]=std::move(link);
            QJsonObject channel{{"host",owner==0},{"identity",StateHash((config["identity"].toString()+"/ds-group-v2/"+QString::number(count)+"/"+QString::number(guest)).toUtf8())}};
            if(config["mode"]=="nearby") {
                channel["mode"]="nearby";channel["address"]=config["address"];
                if(owner)for(const auto* key:{"port","fingerprint","token"})channel[key]=config[key];
            } else if(config["mode"]=="online") {
                if(owner)channel["code"]=config["code"];
                if(config.contains("relayOnly"))channel["relayOnly"]=config["relayOnly"];
            } else throw std::runtime_error("Unknown DS group transport");
            QObject::connect(&l->process,&QProcess::started,&l->process,[this,l,channel]{command(*l,channel);});
            QObject::connect(&l->process,&QProcess::readyReadStandardOutput,&l->process,[this,peer,l]{l->buffer+=l->process.readAllStandardOutput();read(peer);});
            QObject::connect(&l->process,&QProcess::readyReadStandardError,&l->process,[l]{l->process.readAllStandardError();});
            QObject::connect(&l->process,&QProcess::errorOccurred,&l->process,[this,peer](auto){channelClosed(peer);});
            QObject::connect(&l->process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),&l->process,[this,peer](int,QProcess::ExitStatus){channelClosed(peer);});
            l->process.start(config["python"].toString(),{"-I",config["helper"].toString()});
        }
    }
    ~GroupRemoteSession() override {closing=true;for(auto& [_,l]:links){l->process.disconnect();l->process.kill();l->process.waitForFinished(1000);}}
    bool Ready() const override {return running&&!failed;}
    bool StartupReady() const override {
        if(failed||!opened)return false;
        for(unsigned i=0;i<count;++i)if(!states[i].received||!states[owner].receipts[i])return false;
        return true;
    }
    std::optional<std::vector<uint8_t>> TakePeerState(unsigned seat) override {
        if(!StartupReady()||seat>=count||seat==owner||states[seat].taken)throw std::runtime_error("DS group state not prepared");
        states[seat].taken=true;return std::move(states[seat].bytes);
    }
    void MachinesReady() override {
        if(!StartupReady()||states[owner].machines){fail("machines before state admission");return;}
        states[owner].machines=true;control({{"kind","machines"}});maybeStart();
    }
    bool Failed() const override {return failed;}
    QString Failure() const override {return failure;}
    uint64_t VerifiedChecks() const override {return verified;}
    unsigned Delay() const override {return delay;}
    bool Finishing() const override {return ending;}
    std::optional<uint32_t> EndFrame() const override {return endFrame;}
    bool ReturnSafe() const override {
        if(failed||!endFrame)return false;
        for(unsigned seat=0;seat<count;++seat)if(!verifiedFrame[seat]||*verifiedFrame[seat]<*endFrame)return false;
        return true;
    }
    void OwnerRetained() override {
        if(!ReturnSafe()||states[owner].retained){fail("unverified owner return");return;}
        states[owner].retained=true;control({{"kind","retained"}},true);
    }
    bool Finished() const override {return !failed&&finishedAt>=0&&clock.elapsed()-finishedAt>=250;}
    void Tick(uint32_t next) override {
        nextFrame=next;if(failed)return;
        if((!running&&clock.elapsed()>180000)||(running&&!states[owner].retained&&clock.elapsed()-lastAdvance>10000)){fail("group deadline");return;}
        // Delayed consumption applies record-layer backpressure to the sender.
        for(auto& [peer,l]:links){flush(*l);read(peer);}
        if(opened&&seed->bytes&&!ownDelivered())while(!failed&&sentState<seed->bytes->size()&&room(16)) {
            const auto size=std::min<size_t>(16000,seed->bytes->size()-sentState);
            QByteArray bytes(5+qsizetype(size),0);bytes[0]=10;qToLittleEndian<uint32_t>(sentState,bytes.data()+1);
            std::memcpy(bytes.data()+5,seed->bytes->data()+sentState,size);sentState+=size;broadcast(bytes);
        }
        if(ownDelivered())seed->bytes.reset();
        if(allRetained()) {
            bool drained=true;for(const auto& [_,l]:links)drained&=l->closed||(l->finishAck&&l->out.empty()&&l->awaiting.empty()&&l->pending.empty());
            if(drained&&finishedAt<0)finishedAt=clock.elapsed();
        }
    }
    void Finish(uint32_t next) override {
        nextFrame=next;if(!Ready()){fail("finish before start");return;}
        if(!ending){ending=true;states[owner].end=next;control({{"kind","end-request"},{"next",qint64(next)}});}
        chooseEnd();
    }
    bool Inputs(uint32_t frame,FrameInput live,std::vector<FrameInput>& result) override {
        if(!Ready()||(endFrame&&frame>*endFrame+8))return false;
        nextFrame=frame;const auto target=frame+delay;auto& own=states[owner];
        if(!own.inputs.count(target)) {
            if(own.inputs.size()>=32){fail("input window");return false;}
            live.frame=target;if(ending){live.keys=0xfff;live.touching=false;live.x=live.y=0;}
            own.inputs[target]=live;
            QByteArray b(14,0);b[0]=6;qToLittleEndian<uint32_t>(target,b.data()+1);qToLittleEndian<uint32_t>(live.keys,b.data()+5);
            b[9]=live.touching?1:0;qToLittleEndian<uint16_t>(live.x,b.data()+10);qToLittleEndian<uint16_t>(live.y,b.data()+12);broadcast(b);
        }
        for(unsigned i=0;i<count;++i)if(!states[i].inputs.count(frame))return false;
        result.clear();for(unsigned i=0;i<count;++i)result.push_back(states[i].inputs.at(frame));return true;
    }
    void Committed(uint32_t frame) override {for(unsigned i=0;i<count;++i)states[i].inputs.erase(frame);nextFrame=frame+1;lastAdvance=clock.elapsed();}
    void Checkpoint(const FrameResult& value) override {
        if(!value.stateHash||failed)return;
        const Check key{value.seat,value.frame};
        if(value.seat>=count||localChecks.size()>=64||!localChecks.emplace(key,value.stateHash).second){fail("local checkpoint");return;}
        QByteArray b(14,0);b[0]=7;b[1]=char(value.seat);qToLittleEndian<uint32_t>(value.frame,b.data()+2);qToLittleEndian<uint64_t>(value.stateHash,b.data()+6);
        broadcast(b);compare(key);
    }
private:
    bool ownDelivered() const {for(unsigned i=0;i<count;++i)if(!states[owner].receipts[i])return false;return true;}
    bool allRetained() const {for(unsigned i=0;i<count;++i)if(!states[i].retained)return false;return true;}
    void channelClosed(unsigned peer) {
        if(closing||failed)return;
        // A faster frontend may close after every owner retained the verified
        // boundary, before the slower host drains the helper's final receipt.
        // Earlier disconnects still invalidate the session and its return.
        if(!allRetained()){fail("group channel closed");return;}
        auto& link=*links.at(peer);link.closed=true;
        link.out.clear();link.awaiting.clear();link.pending.clear();link.buffer.clear();
    }
    void fail(QString reason){if(failed)return;failed=true;failure=std::move(reason);for(auto& [_,l]:links)l->process.kill();}
    bool room(size_t maximum) const {for(const auto& [_,l]:links)if(l->out.size()+l->awaiting.size()+l->pending.size()>=maximum)return false;return true;}
    void command(Link& link,const QJsonObject& value) {
        if(failed||closing||link.closed)return;const auto bytes=QJsonDocument(value).toJson(QJsonDocument::Compact)+'\n';
        if(bytes.size()>32768||link.process.bytesToWrite()+bytes.size()>1024*1024||link.process.write(bytes)!=bytes.size())fail("helper write");
    }
    void flush(Link& link) {
        while(!failed&&!link.out.empty()&&link.awaiting.size()+link.pending.size()<32) {
            auto msg=std::move(link.out.front());link.out.pop_front();link.awaiting.push_back(msg.finish);
            command(link,{{"send",QString::fromLatin1(msg.data.toBase64())}});
        }
    }
    void enqueue(Link& link,const QByteArray& bytes,bool finish=false) {
        if(bytes.isEmpty()||bytes.size()>16384||link.out.size()>=128){fail("group send window");return;}
        link.out.push_back({bytes,finish});flush(link);
    }
    void broadcast(const QByteArray& data,bool finish=false) {
        QByteArray bytes(1,char(owner));bytes+=data;for(auto& [_,l]:links)enqueue(*l,bytes,finish);
    }
    void control(const QJsonObject& value,bool finish=false){broadcast(QJsonDocument(value).toJson(QJsonDocument::Compact),finish);}
    void open() {
        opened=true;control({{"kind","state"},{"bytes",qint64(seed->expectedSize)},{"digest",states[owner].digest}});
    }
    void receivedState(unsigned from) {
        auto& state=states[from];
        if(state.bytes&&StateHash(QByteArray(reinterpret_cast<const char*>(state.bytes->data()),state.bytes->size()))!=state.digest){fail("seed checksum");return;}
        state.received=true;control({{"kind","state-ack"},{"owner",int(from)},{"digest",state.digest}});
    }
    void maybeStart() {
        if(owner||pingRound)return;for(unsigned i=0;i<count;++i)if(!states[i].machines)return;
        pingRound=1;pingAt=clock.elapsed();control({{"kind","ping"},{"round",pingRound}});
    }
    void begin(unsigned lag) {
        if(running||lag<4||lag>15||!StartupReady()){fail("group start");return;}
        for(unsigned i=0;i<count;++i)if(!states[i].machines){fail("missing ready machine");return;}
        delay=lag;running=true;lastAdvance=clock.elapsed();
        for(unsigned i=0;i<count;++i){states[i].nextInput=lag;for(unsigned f=0;f<lag;++f){FrameInput input;input.frame=f;states[i].inputs[f]=input;}}
    }
    void chooseEnd() {
        if(owner||!ending||endFrame)return;uint32_t last=nextFrame;
        for(unsigned i=0;i<count;++i){if(!states[i].end)return;last=std::max(last,*states[i].end);}
        endFrame=last+delay+8;control({{"kind","end"},{"frame",qint64(*endFrame)}});
    }
    void compare(Check key) {
        if(!localChecks.count(key))return;
        for(unsigned i=0;i<count;++i)if(i!=owner) {
            if(!states[i].checks.count(key))return;
            if(states[i].checks.at(key)!=localChecks.at(key)){fail("group checkpoint mismatch");return;}
        }
        verifiedFrame[key.first]=key.second;++verified;localChecks.erase(key);
        for(unsigned i=0;i<count;++i)states[i].checks.erase(key);
    }
    // Returns whether a guest's accepted message is multicast by the host.
    bool receive(unsigned from,const QByteArray& b) {
        auto& state=states[from];
        if(b.size()>5&&quint8(b[0])==10) {
            if(!opened||!state.offered||state.received||!state.bytes||qFromLittleEndian<uint32_t>(b.data()+1)!=state.bytes->size()
                ||size_t(b.size()-5)!=std::min<size_t>(16000,seed->expectedSize-state.bytes->size())){fail("group seed chunk");return false;}
            state.bytes->insert(state.bytes->end(),b.begin()+5,b.end());if(state.bytes->size()==seed->expectedSize)receivedState(from);
        } else if(b.size()==14&&quint8(b[0])==6) {
            FrameInput f;f.frame=qFromLittleEndian<uint32_t>(b.data()+1);f.keys=qFromLittleEndian<uint32_t>(b.data()+5);
            const auto touch=quint8(b[9]);f.touching=touch==1;f.x=qFromLittleEndian<uint16_t>(b.data()+10);f.y=qFromLittleEndian<uint16_t>(b.data()+12);
            if(!running||f.frame!=state.nextInput||f.frame>uint64_t(nextFrame)+delay+16||f.keys>0xfff||touch>1||f.x>255||f.y>191||state.inputs.size()>=32){fail("group input");return false;}
            ++state.nextInput;state.inputs[f.frame]=f;
        } else if(b.size()==14&&quint8(b[0])==7) {
            Check key{quint8(b[1]),qFromLittleEndian<uint32_t>(b.data()+2)};auto hash=qFromLittleEndian<uint64_t>(b.data()+6);
            if(!running||key.first>=count||!hash||key.second>uint64_t(nextFrame)+16||state.checks.size()>=64
                ||(verifiedFrame[key.first]&&key.second<=*verifiedFrame[key.first])||!state.checks.emplace(key,hash).second){fail("remote checkpoint");return false;}
            compare(key);
        } else {
            QJsonParseError parse;auto doc=QJsonDocument::fromJson(b,&parse);const auto v=doc.object();const auto kind=v["kind"].toString();
            if(b.size()>4096||parse.error!=QJsonParseError::NoError||!doc.isObject()){fail("group control");return false;}
            if(kind=="hello"&&!owner&&!state.hello&&v.size()==3&&v["admission"]==admission&&v["players"]==int(count)) {
                state.hello=true;bool all=true;for(unsigned i=0;i<count;++i)all&=states[i].hello;
                if(all){control({{"kind","open"}});open();}return false;
            } else if(kind=="open"&&owner&&from==0&&!opened&&v.size()==1) {open();}
            else if(kind=="state"&&opened&&!state.offered&&v.size()==3&&v["bytes"]==qint64(seed->expectedSize)) {
                state.digest=v["digest"].toString();
                if(state.digest!="fresh"&&(!seed->expectedSize||!StateDigest(state.digest))){fail("seed description");return false;}
                state.offered=true;if(state.digest=="fresh")receivedState(from);else{state.bytes.emplace();state.bytes->reserve(seed->expectedSize);}
            } else if(kind=="state-ack"&&opened&&v.size()==3) {
                const int subject=v["owner"].toInt(-1);
                if(subject<0||subject>=int(count)||subject==int(from)||!states[subject].offered||v["digest"]!=states[subject].digest||states[subject].receipts[from]
                    ||(subject==int(owner)&&seed->bytes&&sentState!=seed->expectedSize)){fail("seed receipt");return false;}
                states[subject].receipts[from]=true;
            } else if(kind=="machines"&&opened&&!state.machines&&state.received&&v.size()==1) {state.machines=true;maybeStart();}
            else if(kind=="ping"&&owner&&from==0&&!running&&v.size()==2&&v["round"].toInt()==pingRound+1&&pingRound<3) {
                pingRound++;control({{"kind","pong"},{"round",pingRound}});
            } else if(kind=="pong"&&!owner&&!running&&pingRound&&v.size()==2&&v["round"]==pingRound&&state.pongs==pingRound-1) {
                state.pongs=pingRound;maxRtt=std::max(maxRtt,clock.elapsed()-pingAt);bool all=true;
                for(unsigned i=1;i<count;++i)all&=states[i].pongs==pingRound;
                if(all){if(pingRound<3){++pingRound;pingAt=clock.elapsed();control({{"kind","ping"},{"round",pingRound}});}
                    else {const unsigned lag=qBound(qint64(4),(maxRtt+32)/33+2,qint64(15));control({{"kind","start"},{"delay",int(lag)}});begin(lag);}}
                return false;
            } else if(kind=="start"&&owner&&from==0&&pingRound==3&&v.size()==2) {begin(v["delay"].toInt());}
            else if(kind=="end-request"&&running&&!state.end&&v.size()==2) {
                const auto next=v["next"].toInteger(-1);if(next<0||next>qint64(nextFrame)+32||next+32<nextFrame){fail("end range");return false;}
                state.end=uint32_t(next);Finish(nextFrame);chooseEnd();
            } else if(kind=="end"&&owner&&from==0&&ending&&!endFrame&&v.size()==2) {
                const auto end=v["frame"].toInteger(-1);if(end<nextFrame||end>qint64(nextFrame)+64){fail("end frame");return false;}endFrame=uint32_t(end);
            } else if(kind=="retained"&&endFrame&&!state.retained&&v.size()==1) {state.retained=true;}
            else {fail("unexpected group control");return false;}
        }
        return !failed;
    }
    void read(unsigned peer) {
        if(reading||failed||links.at(peer)->closed)return;reading=true;auto& l=*links.at(peer);
        if(l.buffer.size()>2*1024*1024)fail("helper buffer");
        while(!failed&&l.buffer.contains('\n')) {
            const auto at=l.buffer.indexOf('\n');if(at>32768){fail("helper line");break;}
            QJsonParseError parse;const auto doc=QJsonDocument::fromJson(l.buffer.left(at),&parse);const auto v=doc.object();const auto event=v["event"].toString();
            if(parse.error!=QJsonParseError::NoError||!doc.isObject()){fail("helper event");break;}
            if(event=="data"&&!owner&&!room(64))break;
            l.buffer.remove(0,at+1);
            if(event=="ready"&&!owner&&!l.endpoint) {
                QJsonObject value;
                if(v.contains("endpoint"))value=v["endpoint"].toObject();else value={{"mode","online"},{"code",v["code"]}};
                l.endpoint=true;endpoint({{"seat",int(peer+1)},{"connection",value}});
            } else if(event=="connected"&&!l.connected) {
                l.connected=true;if(owner)control({{"kind","hello"},{"admission",admission},{"players",int(count)}});
            } else if(event=="sent"&&!l.awaiting.empty()&&v["sequence"]==l.sent) {
                l.pending[l.sent++]=l.awaiting.front();l.awaiting.pop_front();
            } else if(event=="ack"&&!l.pending.empty()&&v["sequence"]==l.pending.begin()->first) {
                if(l.pending.begin()->second)l.finishAck=true;l.pending.erase(l.pending.begin());flush(l);
            } else if(event=="data"&&l.connected&&v["sequence"]==l.received) {
                const auto decoded=QByteArray::fromBase64Encoding(v["data"].toString().toLatin1(),QByteArray::AbortOnBase64DecodingErrors);
                if(!decoded||decoded.decoded.size()<2||decoded.decoded.size()>16384){fail("group record");break;}
                const auto from=quint8(decoded.decoded[0]);
                if(from>=count||from==owner||(!owner&&from!=peer)){fail("seat impersonation");break;}
                // Forward before handlers send derived acknowledgements: every
                // receiver must observe an owner's offer before its receipts.
                const auto payload=decoded.decoded.mid(1);
                bool direct=payload.startsWith("{")&&(QJsonDocument::fromJson(payload).object()["kind"]=="hello"||QJsonDocument::fromJson(payload).object()["kind"]=="pong");
                if(!owner&&!direct)for(auto& [other,destination]:links)if(other!=peer)enqueue(*destination,decoded.decoded);
                receive(from,payload);
                if(!failed)command(l,{{"consume",l.received++}});
            } else if(event=="error"||event=="closed") {channelClosed(peer);break;}
            else {fail("helper protocol");break;}
        }
        reading=false;
    }
    unsigned count,owner,delay=0,nextFrame=0,sentState=0;
    int pingRound=0;
    bool opened=false,running=false,ending=false,failed=false,closing=false,reading=false;
    QString admission,failure;
    std::function<void(QJsonObject)> endpoint;
    std::optional<OwnerSeed> seed;
    std::array<State,4> states;
    std::map<unsigned,std::unique_ptr<Link>> links;
    std::map<Check,uint64_t> localChecks;
    std::array<std::optional<uint32_t>,4> verifiedFrame;
    std::optional<uint32_t> endFrame;
    QElapsedTimer clock;
    qint64 lastAdvance=0,pingAt=0,maxRtt=0,finishedAt=-1;
    uint64_t verified=0;
};
}
