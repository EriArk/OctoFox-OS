// SPDX-License-Identifier: GPL-3.0-or-later
#include "../../src/integrations/adventure/standalone/CabinetConnection.h"
#include <QCoreApplication>
#include <QLocalSocket>
#include <QNetworkInterface>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QProcess>
#include <QtEndian>

// Supermodel retains its own TCP ring. Only its two adjacent streams cross the
// existing reliable cabinet carrier. Each child has a private network namespace.
int main(int argc,char** argv) {
    QCoreApplication app(argc,argv);const auto args=app.arguments();if(args.size()<4)return 2;
    for(const auto& i:QNetworkInterface::allInterfaces())if(!(i.flags()&QNetworkInterface::IsLoopBack))return 2;
    const auto c=trainer::flycast::CabinetConnection::read(args[1]);if(!c.valid())return 2;
    constexpr int Queue=1024*1024,Chunk=16000;
    const int next=c.seat%c.players+1,previous=(c.seat+c.players-2)%c.players+1;
    QMap<int,QLocalSocket*> channels;QMap<int,QByteArray> buffers;
    QTcpServer server;QTcpSocket incoming;QTcpSocket* outgoing=nullptr;
    QTimer retry;retry.setInterval(100);int attempts=0;bool network=true,opened=false,accepted=false;
    QByteArray pending;
    const auto revoke=[&]{if(!network)return;network=false;retry.stop();server.close();incoming.abort();if(outgoing)outgoing->abort();pending.clear();for(auto* s:channels)s->abort();};
    const auto send=[&](int target,const QByteArray& data){
        auto* s=channels.value(c.seat==1?target:1);
        if(!network||!s||s->bytesToWrite()+data.size()+2>Queue){revoke();return;}
        QByteArray frame(2,0);qToBigEndian<quint16>(data.size(),frame.data());frame+=data;
        if(s->write(frame)!=frame.size())revoke();
    };
    const auto packet=[&](int target,int origin,int kind,const QByteArray& payload){
        QByteArray p;p+=char(c.seat);p+=char(target);p+=char(origin);p+=char(kind);p+=payload;send(target,p);
    };
    const auto readNative=[&](QTcpSocket* socket,int target,int origin){
        while(network&&socket->bytesAvailable()>0)packet(target,origin,2,socket->read(Chunk));
    };
    incoming.setReadBufferSize(Queue);
    QObject::connect(&retry,&QTimer::timeout,&app,[&]{
        if(!network)return;
        if(++attempts>300){revoke();return;}
        if(incoming.state()==QAbstractSocket::UnconnectedState)incoming.connectToHost(QHostAddress::LocalHost,19700+c.seat);
    });
    QObject::connect(&incoming,&QTcpSocket::connected,&app,[&]{retry.stop();if(incoming.write(pending)!=pending.size())revoke();pending.clear();});
    QObject::connect(&incoming,&QTcpSocket::readyRead,&app,[&]{readNative(&incoming,previous,previous);});
    QObject::connect(&incoming,&QTcpSocket::disconnected,&app,[&]{if(!retry.isActive())revoke();});
    QObject::connect(&server,&QTcpServer::newConnection,&app,[&]{
        while(server.hasPendingConnections()) {
            auto* s=server.nextPendingConnection();
            if(accepted||!network){s->abort();s->deleteLater();continue;}
            accepted=true;outgoing=s;s->setReadBufferSize(Queue);
            packet(next,c.seat,1,{});
            QObject::connect(s,&QTcpSocket::readyRead,&app,[&,s]{readNative(s,next,c.seat);});
            QObject::connect(s,&QTcpSocket::disconnected,&app,revoke);
            readNative(s,next,c.seat);
        }
    });
    for(auto it=c.sockets.cbegin();it!=c.sockets.cend();++it) {
        const int peer=it.key();auto* s=new QLocalSocket(&app);channels[peer]=s;s->setReadBufferSize(Queue);
        s->connectToServer(it.value());if(!s->waitForConnected(3000))return 3;
        QObject::connect(s,&QLocalSocket::disconnected,&app,revoke);
        QObject::connect(s,&QLocalSocket::readyRead,&app,[&,s,peer]{
            if(!network)return;
            while(network&&s->bytesAvailable()>0) {
                auto& b=buffers[peer];b+=s->read(65536);
                while(b.size()>=2) {
                    const int size=qFromBigEndian<quint16>(b.constData());
                    if(size<4||size>Chunk+4){revoke();return;}
                    if(b.size()<size+2)break;
                    const auto p=b.mid(2,size);b.remove(0,size+2);
                    const int source=quint8(p[0]),target=quint8(p[1]),origin=quint8(p[2]),kind=quint8(p[3]);
                    const int end=origin%c.players+1;
                    if(origin<1||origin>c.players||source==target||kind<1||kind>2
                       ||!((source==origin&&target==end)||(source==end&&target==origin))
                       ||(c.seat==1?source!=peer:target!=c.seat)
                       ||(kind==1&&(size!=4||source!=origin))||(kind==2&&size==4)){revoke();return;}
                    if(target!=c.seat){send(target,p);if(!network)return;continue;}
                    if(kind==1) {
                        if(origin!=previous||opened){revoke();return;}
                        opened=true;retry.start();incoming.connectToHost(QHostAddress::LocalHost,19700+c.seat);
                    } else {
                        const auto data=p.mid(4);QTcpSocket* local=origin==c.seat?outgoing:&incoming;
                        if((origin==c.seat&&!accepted)||(origin==previous&&!opened)){revoke();return;}
                        if(local==&incoming&&retry.isActive()) {
                            if(pending.size()+data.size()>Queue){revoke();return;}pending+=data;
                        } else if(!local||local->state()!=QAbstractSocket::ConnectedState
                                  ||local->bytesToWrite()+data.size()>Queue||local->write(data)!=data.size()){revoke();return;}
                    }
                }
            }
        });
    }
    if(!server.listen(QHostAddress::LocalHost,19700+next))return 3;
    QProcess game;game.setProcessChannelMode(QProcess::ForwardedChannels);game.setInputChannelMode(QProcess::ForwardedInputChannel);
    QObject::connect(&game,&QProcess::finished,&app,[&](int code,QProcess::ExitStatus status){app.exit(status==QProcess::NormalExit?code:1);});
    game.start(args[2],args.mid(3));if(!game.waitForStarted(5000))return 4;
    return app.exec();
}
