#pragma once
#include "core/input/Action.h"
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include <QSet>
#include <QQueue>

namespace trainer {
// Profile-owned care state. Rendering and background timers are not its clock.
class HomeCompanion final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap needs READ needs NOTIFY changed)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY changed)
    Q_PROPERTY(bool interacting READ interacting NOTIFY changed)
    Q_PROPERTY(bool menuOpen READ menuOpen NOTIFY changed)
    Q_PROPERTY(int focus READ focus NOTIFY changed)
    Q_PROPERTY(bool quiet READ quiet NOTIFY changed)
    Q_PROPERTY(QString background READ background NOTIFY changed)
    Q_PROPERTY(QString activity READ activity NOTIFY changed)
    Q_PROPERTY(QString expression READ expression NOTIFY changed)
    Q_PROPERTY(QString prop READ prop NOTIFY changed)
    Q_PROPERTY(QString bubble READ bubble NOTIFY changed)
    Q_PROPERTY(QString bubbleKind READ bubbleKind NOTIFY changed)
    Q_PROPERTY(QVariantMap achievement READ achievement NOTIFY changed)
public:
    explicit HomeCompanion(QObject* parent=nullptr);
    ~HomeCompanion() override;
    void setOwner(const QString& owner);
    void advanceTo(qint64 utcMs);
    void addGameplaySeconds(qint64 seconds);
    void setActive(bool value);
    bool active() const { return active_; }
    bool interacting() const { return interacting_; }
    bool menuOpen() const { return menuOpen_; }
    int focus() const { return focus_; }
    bool quiet() const { return quiet_; }
    QVariantMap needs() const;
    QString background() const;
    QString activity() const;
    QString expression() const;
    QString prop() const;
    QString bubble() const { return bubble_; }
    QString bubbleKind() const { return bubbleKind_; }
    QVariantMap achievement() const { return achievement_; }
    Q_INVOKABLE void begin();
    Q_INVOKABLE void end();
    Q_INVOKABLE void toggleMenu();
    Q_INVOKABLE void perform(int index);
    Q_INVOKABLE void openHint();
    Q_INVOKABLE void setNotifications(const QVariantList& rows);
    void dispatch(Action action);
    void celebrate(const QString& game,const QStringList& titles);
    void celebrateAwards(const QString& set,const QVariantList& awards);
    void clearAchievements();
signals:
    void changed();
    void inboxRequested();
    void widgetChangeRequested();
private:
    void tick();
    void save();
    void presentPending();
    QString key_,scene_="cozy-room",activity_,bubble_,bubbleKind_;
    double food_=80,mood_=80,energy_=80;
    qint64 stamp_=0,lastSave_=0,actionUntil_=0,bubbleUntil_=0,lastHint_=0;
    bool active_=false,interacting_=false,quiet_=false,resting_=false;
    bool menuOpen_=false;
    int focus_=0,foodIndex_=0;
    QQueue<QVariantMap> awards_;
    QVariantMap achievement_;
    QStringList seenAwards_;
    QSet<QString> unreadIds_;
    bool pendingUnread_=false;
    QTimer timer_;
};
}
