// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QFile>
#include <QSaveFile>
#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QtEndian>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <memory>

namespace trainer::AvatarResource {
// Incorporated asset storage, NOT a secret or an authorization boundary.
// TAV1 | plaintext length (LE32) | IV (16) | CBC/PKCS7 | HMAC-SHA256.
inline constexpr qsizetype Limit=64*1024*1024;
inline QByteArray key(const char* purpose) {
    return QCryptographicHash::hash(QByteArray("TrainerOS/avatar-resource/v1/")+purpose,QCryptographicHash::Sha256);
}
inline QByteArray crypt(const QByteArray& bytes,const QByteArray& iv,bool encrypt) {
    std::unique_ptr<EVP_CIPHER_CTX,decltype(&EVP_CIPHER_CTX_free)> ctx(EVP_CIPHER_CTX_new(),EVP_CIPHER_CTX_free);
    const auto k=key("encryption");
    if(!ctx||EVP_CipherInit_ex(ctx.get(),EVP_aes_256_cbc(),nullptr,
        reinterpret_cast<const unsigned char*>(k.constData()),reinterpret_cast<const unsigned char*>(iv.constData()),encrypt)!=1)return {};
    QByteArray out(bytes.size()+16,Qt::Uninitialized);int n=0,last=0;
    if(EVP_CipherUpdate(ctx.get(),reinterpret_cast<unsigned char*>(out.data()),&n,
        reinterpret_cast<const unsigned char*>(bytes.constData()),int(bytes.size()))!=1||
        EVP_CipherFinal_ex(ctx.get(),reinterpret_cast<unsigned char*>(out.data()+n),&last)!=1)return {};
    out.resize(n+last);return out;
}
inline QByteArray encode(const QByteArray& plain) {
    if(plain.isEmpty()||plain.size()>Limit)return {};
    QByteArray iv(16,Qt::Uninitialized);if(RAND_bytes(reinterpret_cast<unsigned char*>(iv.data()),16)!=1)return {};
    QByteArray out("TAV1",4);char size[4];qToLittleEndian(quint32(plain.size()),size);out.append(size,4);out+=iv;
    const auto cipher=crypt(plain,iv,true);if(cipher.isEmpty())return {};out+=cipher;
    out+=QMessageAuthenticationCode::hash(out,key("authentication"),QCryptographicHash::Sha256);return out;
}
inline QByteArray decode(const QByteArray& resource,qsizetype limit=Limit) {
    if(resource.size()<72||resource.size()>Limit+72||resource.first(4)!="TAV1")return {};
    const auto size=qFromLittleEndian<quint32>(resource.constData()+4);
    if(!size||size>quint64(qMax(qsizetype(0),qMin(limit,Limit)))||resource.size()!=24+(size/16+1)*16+32)return {};
    const auto tag=QMessageAuthenticationCode::hash(resource.first(resource.size()-32),key("authentication"),QCryptographicHash::Sha256);
    unsigned mismatch=0;for(int i=0;i<32;++i)mismatch|=quint8(tag[i])^quint8(resource[resource.size()-32+i]);
    if(mismatch)return {};
    const auto plain=crypt(resource.mid(24,resource.size()-56),resource.mid(8,16),false);
    return plain.size()==size?plain:QByteArray();
}
inline QByteArray read(const QString& path,qsizetype limit=Limit) {
    // Logical manifest filenames are stable: packaging adds .tav, never rewrites recipes.
    const bool packed=path.endsWith(".tav")||QFile::exists(path+".tav");
    QFile f(path.endsWith(".tav")||!packed?path:path+".tav");
    if(!f.open(QIODevice::ReadOnly)||f.size()<=0||f.size()>qMin(limit,Limit)+(packed?72:0))return {};
    const auto bytes=f.readAll();return packed?decode(bytes,limit):bytes;
}
inline bool write(const QString& path,const QByteArray& plain) {
    const auto bytes=encode(plain);if(bytes.isEmpty())return false;
    QSaveFile f(path);return f.open(QIODevice::WriteOnly)&&f.write(bytes)==bytes.size()&&f.commit();
}
}
