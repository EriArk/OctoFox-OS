#pragma once
#include <QByteArray>
#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <functional>
#include <optional>

namespace trainer {
// Presentation identity only. Steam changes playtime/download bookkeeping in
// appmanifest after launch; those fields do not replace the installed build.
// This fingerprint must never authorize semantic save reads or writes.
inline QString steamMediaIdentity(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || file.size() < 1 || file.size() > 1024*1024) return {};
    const auto data=file.read(1024*1024+1);
    if(data.isEmpty()||data.size()>1024*1024||file.error()!=QFile::NoError)return {};
    qsizetype at=0;
    auto space=[&] { while(at<data.size() && (data[at]==' '||data[at]=='\t'||data[at]=='\r'||data[at]=='\n'))++at; };
    auto token=[&]() -> std::optional<QString> {
        space(); if(at>=data.size()||data[at++]!='"')return {};
        QByteArray text;
        while(at<data.size()) {
            char c=data[at++];if(c=='"')return QString::fromUtf8(text);
            if(c=='\\') {if(at>=data.size())return {};c=data[at++];if(c!='\\'&&c!='"')return {};}
            if(c=='\0')return {};
            text+=c;
        }
        return {};
    };
    std::function<std::optional<QJsonObject>(int)> object=[&](int depth)->std::optional<QJsonObject> {
        if(depth>16)return {};
        space();if(at>=data.size()||data[at++]!='{')return {};
        QJsonObject result;QSet<QString> keys;
        while(true) {
            space();if(at>=data.size())return {};
            if(data[at]=='}'){++at;return result;}
            auto key=token();if(!key)return {};*key=key->toLower();
            if(keys.contains(*key))return {};
            keys.insert(*key);space();
            if(at<data.size()&&data[at]=='{') {auto child=object(depth+1);if(!child)return {};result[*key]=*child;}
            else {auto value=token();if(!value)return {};result[*key]=*value;}
        }
    };
    auto root=token();if(!root||root->compare("AppState",Qt::CaseInsensitive))return {};
    auto state=object(0);space();if(!state||at!=data.size())return {};
    const auto app=(*state)["appid"].toString(), build=(*state)["buildid"].toString(), directory=(*state)["installdir"].toString();
    static const QRegularExpression number("^[1-9][0-9]{0,19}$");
    if(!number.match(app).hasMatch()||!number.match(build).hasMatch()||directory.isEmpty()
       ||QFileInfo(path).fileName()!=QString("appmanifest_%1.acf").arg(app))return {};
    const QJsonObject identity{{"app",app},{"build",build},{"directory",directory}};
    return "steam-build-v1:"+QString::fromLatin1(QCryptographicHash::hash(QJsonDocument(identity).toJson(QJsonDocument::Compact),QCryptographicHash::Sha256).toHex());
}
}
