// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QVector3D>
#include <QTimer>
#include <QElapsedTimer>
#include <qqmlregistration.h>
#include <memory>

namespace trainer {
// Trusted, resolved SDK GLB only. Shared native presenter, independent of care logic.
class AvatarScene : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY modelChanged)
    Q_PROPERTY(QVariantList parts READ parts NOTIFY modelChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY modelChanged)
    Q_PROPERTY(QString error READ error NOTIFY modelChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY changed)
    Q_PROPERTY(QString expression READ expression WRITE setExpression NOTIFY changed)
    Q_PROPERTY(QString clip READ clip WRITE setClip NOTIFY changed)
    Q_PROPERTY(qreal clipPosition READ clipPosition WRITE setClipPosition NOTIFY changed)
    Q_PROPERTY(QVariantMap pose READ pose WRITE setPose NOTIFY changed)
    Q_PROPERTY(QVector3D rightHand READ rightHand NOTIFY frameChanged)
    Q_PROPERTY(QVariantMap sockets READ sockets NOTIFY frameChanged)
    Q_PROPERTY(QVariantMap face READ face WRITE setFace NOTIFY changed)
    Q_PROPERTY(int vertexCount READ vertexCount NOTIFY modelChanged)
public:
    explicit AvatarScene(QObject* parent=nullptr);
    ~AvatarScene() override;
    QUrl source() const{return source_;} void setSource(const QUrl&);
    QVariantList parts() const{return parts_;}
    bool ready() const{return !parts_.isEmpty();}
    QString error() const{return error_;}
    bool running() const{return running_;} void setRunning(bool);
    QString expression() const{return expression_;} void setExpression(const QString&);
    QString clip() const{return clip_;} void setClip(const QString&);
    qreal clipPosition() const{return clipPosition_;} void setClipPosition(qreal);
    QVariantMap pose() const{return pose_;} void setPose(const QVariantMap&);
    QVector3D rightHand() const{return rightHand_;}
    QVariantMap sockets() const{return sockets_;}
    QVariantMap face() const{return face_;} void setFace(const QVariantMap&);
    int vertexCount() const;
    Q_INVOKABLE bool supportsExpression(const QString&) const;
    Q_INVOKABLE bool supportsClip(const QString&) const;
signals:
    void changed();
    void modelChanged();
    void frameChanged();
private:
    void frame();
    struct Data;
    std::shared_ptr<Data> d_;
    quint64 loadGeneration_=0;
    QUrl source_;
    QVariantList parts_;
    QString expression_="neutral",clip_,error_;
    qreal clipPosition_=-1;
    QVariantMap pose_;
    QVariantMap sockets_,face_;
    QVector3D rightHand_;
    bool running_=false;
    bool dirty_=true;
    double clipSeconds_=0;
    QTimer timer_;
    QElapsedTimer clock_;
};
}
