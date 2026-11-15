#include "BackendAccount.h"
#include <QCryptographicHash>
#include <QPointer>
#include <QRandomGenerator>
#include <QUuid>

namespace trainer {
void BackendAccount::setSocialConnection(const QString& subject,bool connected) {
    const auto previous=socialSubject_;const bool wasConnected=socialConnected_;
    if(previous!=subject || (!wasConnected&&connected)){autoPaused_=false;socialFailures_=0;socialRetry_.stop();}
    socialConnected_=connected;
    setSocialSubject(subject);
    if(!previous.isEmpty() && subject.isEmpty() && socialCredential) {
        autoPaused_=true;
        if(state_=="connected")logout();
        else {reset();cachedIdentity_={};profileSnapshot_={};write({},[](bool){});state("signed_out","Sign in to Fluxer to connect your OctoFox OS profile");}
    }
    if(socialConnected_ && socialLogin_ && state_=="claiming" && !socialRetry_.isActive())claimSocial();
    else reconcileSocial();
}
void BackendAccount::reconcileSocial() {
    if(!socialCredential||!socialConnected_||socialSubject_.isEmpty()||owner_.isEmpty()||autoPaused_||socialRetry_.isActive())return;
    if(state_=="signed_out"||state_=="error")beginSocial();
}
void BackendAccount::retrySocial(const QString& message) {
    reset();restoreCachedProfile();
    socialFailures_=qMin(socialFailures_+1,6);
    socialRetry_.start(qMin(60000,2000*(1<<qMin(socialFailures_-1,5))));
    state("error",message);
}
void BackendAccount::beginSocial() {
    if(!socialCredential||!socialConnected_||socialSubject_.isEmpty())return;
    reset();restoreCachedProfile();socialLogin_=true;
    QByteArray secret(32,Qt::Uninitialized);for(auto& c:secret)c=char(QRandomGenerator::system()->generate());
    verifier_=QString::fromLatin1(secret.toBase64(QByteArray::Base64UrlEncoding|QByteArray::OmitTrailingEquals));
    state("connecting","Connecting your OctoFox OS account…");
    const auto epoch=epoch_;const auto subject=socialSubject_;
    QJsonObject body{{"provider","fluxer"},{"flow","social"},{"device_label","OctoFox OS"},{"expected_subject",subject},
        {"claim_challenge_method","S256"},{"claim_challenge",QString::fromLatin1(QCryptographicHash::hash(verifier_.toLatin1(),QCryptographicHash::Sha256).toBase64(QByteArray::Base64UrlEncoding|QByteArray::OmitTrailingEquals))}};
    request("POST","/v1/auth/login-attempts",body,[this,epoch,subject](int status,QJsonObject result){
        if(status!=201||QUuid(result["attempt_id"].toString()).isNull()){retrySocial("Account connection interrupted. Retrying automatically…");return;}
        attempt_=result["attempt_id"].toString();QPointer<BackendAccount> self(this);
        socialCredential(subject,[self,epoch,subject](QByteArray credential){
            if(!self||epoch!=self->epoch_||subject!=self->socialSubject_)return;
            if(credential.isEmpty()){self->retrySocial("Waiting for your verified Fluxer session…");return;}
            self->request("POST","/v1/auth/fluxer/session",{{"attempt_id",self->attempt_},{"claim_verifier",self->verifier_},{"fluxer_token",QString::fromUtf8(credential)}},[self](int status,QJsonObject){
                if(!self)return;
                if(status!=204){
                    if(status==401||status==403){self->autoPaused_=true;self->fail("Fluxer could not verify this session. Sign in to Fluxer again.");}
                    else self->retrySocial("Could not connect your OctoFox OS profile. Retrying automatically…");
                    return;
                }
                self->state("claiming","Synchronizing your OctoFox OS profile…");
                self->claimSocial();
            });
        });
    });
}
void BackendAccount::claimSocial() {
    if(!socialLogin_||socialClaimBusy_||attempt_.isEmpty()||verifier_.isEmpty()||!socialConnected_)return;
    socialClaimBusy_=true;
    request("POST","/v1/auth/login-attempts/claim",{{"attempt_id",attempt_},{"claim_verifier",verifier_}},[this](int status,QJsonObject value){
        socialClaimBusy_=false;
        if(status==0||status==408||status==429||status>=500){
            socialFailures_=qMin(socialFailures_+1,6);socialRetry_.start(qMin(60000,2000*(1<<qMin(socialFailures_-1,5))));
            detail_="Finishing sign-in was interrupted. Retrying automatically…";emit changed();return;
        }
        if(status!=200){retrySocial("Sign-in was interrupted. Reconnecting automatically…");return;}
        socialFailures_=0;socialLogin_=false;tokens(value);
    });
}
QVariantMap BackendAccount::onlineProfile() const {
    return {{"ready",profileReady_},{"name",profileName_},{"needsName",needsName_},{"needsAvatar",needsAvatar_},
        {"busy",profileBusy_},{"detail",detail_}};
}
bool BackendAccount::applyOnlineProfile(const QJsonObject& profile) {
    const auto name=profile["display_name"].toString().trimmed();
    if(player_.isEmpty()||profile["player_id"].toString()!=player_||name.isEmpty()||name.size()>256)return false;
    profileName_=name;profileRevision_=profile["revision"].toString();
    needsName_=profile["needs_name"].toBool();needsAvatar_=profile["needs_avatar"].toBool();
    profileSnapshot_["player_id"]=player_;profileSnapshot_["display_name"]=name;profileSnapshot_["avatar"]=profile["avatar"];
    saveCommerce();return true;
}
void BackendAccount::loadOnlineProfile() {
    if(state_!="connected"||profileBusy_)return;
    profileBusy_=true;
    request("GET","/v1/me/profile",{},[this](int status,QJsonObject profile){
        if(status!=200||!applyOnlineProfile(profile)){
            profileBusy_=false;profileRetry_.start(5000);detail_="Your profile has not synchronized yet. Retrying automatically…";emit changed();return;
        }
        const auto epoch=epoch_;QPointer<BackendAccount> self(this);
        auto finish=[self,epoch,profile](bool ok){
            if(!self||epoch!=self->epoch_)return;
            self->profileBusy_=false;
            if(!ok){self->profileRetry_.start(3000);self->detail_="Waiting to restore your saved profile…";emit self->changed();return;}
            self->profileReady_=true;
            if(!self->avatarIntent_)self->publishedAvatar_=profile["avatar"].toObject();
            self->detail_=self->needsName_?"Your account is ready. Choose your nickname and avatar whenever you like.":"Your OctoFox OS profile is synchronized";
            emit self->changed();self->syncPublicAvatar();
        };
        if(restoreProfile)restoreProfile(profile,std::move(finish));else finish(true);
    },access_);
}
void BackendAccount::editNickname(){if(profileReady_&&state_=="connected"&&!profileBusy_){nicknameEditor_=player_;emit nicknameRequested(needsName_?QString():profileName_);}}
void BackendAccount::saveNickname(const QString& name) {
    if(!profileReady_||state_!="connected"||profileBusy_||nicknameEditor_!=player_)return;
    nicknameEditor_.clear();profileBusy_=true;
    request("PUT","/v1/me/profile/name",{{"display_name",name},{"revision",profileRevision_}},[this](int status,QJsonObject profile){
        profileBusy_=false;
        if(status==200 && applyOnlineProfile(profile)){loadOnlineProfile();return;}
        detail_=status==422?"Choose a single-line nickname of 1–24 characters.":status==409?"Your profile changed on another device. Refreshing; please try the name again.":"Could not save your nickname. Please try again.";
        if(status==409)profileRetry_.start(1000);
        emit changed();
    },access_);
}
void BackendAccount::publishSelectedAvatar(const QJsonObject& recipe) {
    if(!profileReady_||state_!="connected"||recipe.isEmpty())return;
    avatarIntent_=true;publicAvatar_=recipe;syncPublicAvatar();
}
}
