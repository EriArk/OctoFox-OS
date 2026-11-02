// SPDX-License-Identifier: GPL-3.0-or-later
#include "GroupRemoteSession.h"
#include <QCoreApplication>
#include <QThread>
#include <iostream>
using namespace traineros::ds;
void require(bool value,const char* message){if(!value)throw std::runtime_error(message);}
void run(const QString& python,const QString& helper,unsigned count,const QString& mode) {
    const bool clean=mode=="normal"||mode=="early-close";
    std::array<std::unique_ptr<GroupRemoteSession>,4> nodes;
    std::array<uint32_t,4> next{};
    std::array<bool,4> prepared{},retained{};
    std::array<std::optional<std::vector<uint8_t>>,4> seeds;
    for(unsigned i=0;i<count;++i)if(i!=1)seeds[i]=std::vector<uint8_t>(32768,uint8_t(0x30+i));
    const QJsonObject host{{"host",true},{"mode","nearby"},{"address","127.0.0.1"},{"players",int(count)},
        {"identity",QString(64,'a')},{"python",python},{"helper",helper}};
    nodes[0]=std::make_unique<GroupRemoteSession>(host,QString(64,'b'),0,[&](QJsonObject endpoint){
        const unsigned seat=endpoint["seat"].toInt()-1;require(seat>0&&seat<count&&!nodes[seat],"Targeted endpoint seat");
        auto guest=host;guest["host"]=false;const auto connection=endpoint["connection"].toObject();
        for(auto it=connection.begin();it!=connection.end();++it)guest[it.key()]=it.value();
        nodes[seat]=std::make_unique<GroupRemoteSession>(guest,QString(64,mode=="admission"&&seat==count-1?'c':'b'),seat,
            [](QJsonObject){throw std::runtime_error("Guest emitted endpoint");},NetworkSession::OwnerSeed{32768,seeds[seat]});
    },NetworkSession::OwnerSeed{32768,seeds[0]});
    QElapsedTimer timeout;timeout.start();bool injected=false;unsigned complete=0;
    while(timeout.elapsed()<30000) {
        QCoreApplication::processEvents();complete=0;
        for(unsigned p=0;p<count;++p) {
            if(!nodes[p])continue;auto& n=*nodes[p];n.Tick(next[p]);
            if(n.Failed()) {
                if(clean)throw std::runtime_error(n.Failure().toStdString());
                require(!n.ReturnSafe()&&!n.Finished(),"Failed group admitted return");++complete;continue;
            }
            if(!prepared[p]&&n.StartupReady()) {
                for(unsigned other=0;other<count;++other)if(other!=p)require(n.TakePeerState(other)==seeds[other],"Group mixed owner seeds");
                prepared[p]=true;n.MachinesReady();
            }
            if(!n.Ready())continue;
            if(n.ReturnSafe()&&!retained[p]){n.OwnerRetained();retained[p]=true;}
            if(n.Finished()){++complete;continue;}
            if(retained[p])continue;
            if(p==1&&next[p]>=80&&clean&&!n.Finishing())n.Finish(next[p]);
            FrameInput own;own.keys=0xfff^(1u<<p);
            std::vector<FrameInput> inputs;
            if(n.Inputs(next[p],own,inputs)) {
                require(inputs.size()==count,"Missing controller seat");
                for(unsigned seat=0;seat<count;++seat)
                    require(inputs[seat].frame==next[p]&&inputs[seat].keys<=0xfff,"Input frame mismatch");
                const auto frame=next[p];n.Committed(frame);++next[p];
                if(frame%10==0||(n.EndFrame()&&frame==*n.EndFrame()))for(unsigned seat=0;seat<count;++seat) {
                    FrameResult value;value.seat=seat;value.frame=frame;value.stateHash=uint64_t(frame+1)*100+seat+1;
                    if(mode=="mismatch"&&p==count-1&&frame==50&&seat==0){++value.stateHash;injected=true;}
                    n.Checkpoint(value);
                }
            }
        }
        if(mode=="loss"&&!injected&&nodes[count-1]&&next[count-1]>40){nodes[count-1].reset();injected=true;}
        if(mode=="early-close"&&!injected&&nodes[count-1]&&nodes[count-1]->Finished()) {
            require(nodes[count-1]->ReturnSafe(),"Early clean exit without verified progress");
            nodes[count-1].reset();injected=true;
            // Deliver the real EOF/error events before checking the other peers.
            QElapsedTimer drain;drain.start();while(drain.elapsed()<100){QCoreApplication::processEvents();QThread::msleep(1);}
        }
        if(mode=="loss"&&injected&&complete==count-1)break;
        if(mode=="early-close"&&injected&&complete==count-1)break;
        if(complete==count)break;
        QThread::msleep(1);
    }
    require(timeout.elapsed()<30000,"Group lifecycle timeout");
    if(clean)for(unsigned p=0;p<count-(mode=="early-close"?1:0);++p) {
        require(nodes[p]&&nodes[p]->Finished()&&nodes[p]->ReturnSafe()&&nodes[p]->VerifiedChecks()>count,"Group clean return");
        require(nodes[p]->EndFrame()==nodes[0]->EndFrame(),"Different exit boundaries");
    }
    else require(complete==(mode=="loss"?count-1:count),"Group did not stop together");
    std::cout<<"PASS players="<<count<<" scenario="<<mode.toStdString()<<" elapsed-ms="<<timeout.elapsed()<<'\n';
}
int main(int argc,char**argv) {
    QCoreApplication app(argc,argv);
    try {
        require(argc==3,"Usage: group_session_checks PYTHON SECURE_CHANNEL");
        for(unsigned count:{3u,4u})for(const auto& mode:{"normal","early-close","admission","mismatch","loss"})run(argv[1],argv[2],count,mode);
        // A fresh room after loss uses fresh endpoints and has no stale roster.
        run(argv[1],argv[2],4,"normal");return 0;
    } catch(const std::exception& e){std::cerr<<"FAIL "<<e.what()<<'\n';return 1;}
}
