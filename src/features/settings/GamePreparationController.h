#pragma once
#include "platform/emulation/GamePreparation.h"
#include "features/library/FilePickerController.h"
#include <QFuture>
#include "platform/process/ProcessService.h"
#include <QTimer>

namespace trainer {
class GamePreparationController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList rows READ rows NOTIFY changed)
    Q_PROPERTY(QVariantList platforms READ platforms NOTIFY changed)
    Q_PROPERTY(QVariantList files READ fileRows NOTIFY changed)
    Q_PROPERTY(QString platformTitle READ platformTitle NOTIFY changed)
    Q_PROPERTY(QString platformNote READ platformNote NOTIFY changed)
    Q_PROPERTY(bool hasOnline READ hasOnline NOTIFY changed)
    Q_PROPERTY(QString onlineStatus READ onlineStatus NOTIFY changed)
    Q_PROPERTY(QString report READ report NOTIFY changed)
    Q_PROPERTY(QVariantMap selected READ selected NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString group READ group NOTIFY changed)
    Q_PROPERTY(QStringList groups READ groups NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool setupAvailable READ setupAvailable NOTIFY changed)
    Q_PROPERTY(bool setupRunning READ setupRunning NOTIFY changed)
    Q_PROPERTY(int focusIndex READ focusIndex NOTIFY changed)
    Q_PROPERTY(trainer::FilePickerController* picker READ picker CONSTANT)
public:
    explicit GamePreparationController(QObject* parent=nullptr);
    ~GamePreparationController() override;
    void configure(QString stateDirectory,QHash<QString,QJsonObject> profiles);
    std::function<bool()> canImport;
    std::function<QString()> setupGuard;
    bool busy() const{return busy_;}
    bool setupAvailable() const;
    bool setupRunning() const{return setup_.active();}
    Q_INVOKABLE void openSetup();
    QVariantList rows() const;
    QVariantList platforms() const;
    QVariantList fileRows() const;
    QString platformTitle() const;
    QString platformNote() const;
    bool hasOnline() const;
    QString onlineStatus() const;
    QString report() const{return packReport_;}
    QVariantMap selected() const;
    QVariantList tasks() const;
    QString status() const{return status_;}
    QString group() const{return group_;}
    QStringList groups() const;
    int focusIndex() const{return focus_;}
    FilePickerController* picker(){return &picker_;}
    void begin(const QString& platform = {}, const QString& adapter = {});
    void dispatch(Action);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void choose();
    Q_INVOKABLE void choosePack();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void close();
    Q_INVOKABLE void select(int index);
    Q_INVOKABLE void selectGroup(const QString& group);
    Q_INVOKABLE void selectPlatform(int index);
    Q_INVOKABLE void importRequirement(int index);
    Q_INVOKABLE void onlineAction(int index);
    Q_INVOKABLE void activate(int index);
signals:
    void changed();
    void tasksChanged();
    void installed();
    void setupStarted(qint64 pid,QString title);
    void setupFinished();
    void resumeSetup();
    void closeRequested();
    void onlineSettingsRequested();
    void scrollRequested(int direction);
    void platformSelected(QString platform);
    void onlineActionRequested(int action);
private:
    void importSelected(const QString&);
    void importPack(const QString&);
    QJsonObject setupProfile() const;
    ProcessService setup_;
    FilePickerController picker_{nullptr};
    QHash<QString,QJsonObject> profiles_;
    QString setupAdapter_;
    QString directory_,status_,group_,selected_,picking_,taskName_,taskState_,taskDetail_,packReport_;
    QVariantList rows_;
    QList<gamePreparation::File> files_;
    QFuture<void> future_;
    std::atomic_bool cancel_{false};
    std::atomic<qint64> received_{0},total_{0};
    QTimer progress_;
    int focus_=0;
    bool busy_=false;
    bool packJob_=false;
};
}
