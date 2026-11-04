// SPDX-License-Identifier: GPL-3.0-or-later
#include "../sdk/qt/AvatarResource.h"
#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QDebug>
int main(int argc,char** argv) {
    QCoreApplication app(argc,argv);const auto args=app.arguments();if(args.size()!=3)return 2;
    const QDir source(args[1]),output(args[2]);
    if(source.canonicalPath().isEmpty()||output.absolutePath()==source.absolutePath()||
        output.absolutePath().startsWith(source.absolutePath()+"/")||QFileInfo(args[2]).isSymLink())return 2;
    QDirIterator it(source.absolutePath(),QDir::Files,QDirIterator::Subdirectories);int count=0;
    while(it.hasNext()) {
        const auto path=it.next();const auto info=it.fileInfo();if(info.isSymLink())return 3;
        const auto ext=info.suffix().toLower();
        if(!QStringList{"glb","bin","png","json","md","txt"}.contains(ext)){qCritical()<<"Unexpected avatar asset"<<path;return 3;}
        const bool geometry=ext=="glb"||ext=="bin";
        const auto dest=output.absoluteFilePath(source.relativeFilePath(path)+(geometry?".tav":""));
        if(!QDir().mkpath(QFileInfo(dest).absolutePath()))return 4;
        auto bytes=trainer::AvatarResource::read(path);
        if(bytes.isEmpty())return 4;
        // Git's canonical LF manifest is also the installed recipe identity.
        // Windows checkouts may use CRLF; never ship that host-specific hash.
        if(info.fileName()=="manifest.json")bytes.replace("\r\n","\n");
        if(geometry) {if(!trainer::AvatarResource::write(dest,bytes)||trainer::AvatarResource::read(dest)!=bytes)return 5;}
        else {QSaveFile f(dest);if(!f.open(QIODevice::WriteOnly)||f.write(bytes)!=bytes.size()||!f.commit())return 5;}
        ++count;
    }
    qInfo()<<"Packed and verified"<<count<<"avatar resources";return count?0:6;
}
