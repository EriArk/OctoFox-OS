#pragma once
#include "platform/device/NetworkService.h"
#include "core/input/Action.h"
#include <QVariantList>
#include <QTimer>
#include <QNetworkInformation>
namespace trainer {
class NetworkController final:public QObject {
    Q_OBJECT
    Q_PROPERTY(bool bluetooth READ bluetooth NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(int focusIndex READ focusIndex NOTIFY changed)
    Q_PROPERTY(QVariantList rows READ rows NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString prompt READ prompt NOTIFY changed)
    Q_PROPERTY(QString confirmLabel READ confirmLabel NOTIFY changed)
    Q_PROPERTY(QString actionLabel READ actionLabel NOTIFY changed)
    Q_PROPERTY(bool canForget READ canForget NOTIFY changed)
    Q_PROPERTY(bool detailsOpen READ detailsOpen NOTIFY changed)
    Q_PROPERTY(QVariantMap networkInfo READ networkInfo NOTIFY changed)
    Q_PROPERTY(QVariantList detailActions READ detailActions NOTIFY changed)
    Q_PROPERTY(int detailFocus READ detailFocus NOTIFY changed)
    Q_PROPERTY(bool failed READ failed NOTIFY changed)
    Q_PROPERTY(QVariantMap connection READ connection NOTIFY connectionChanged)
public:
    explicit NetworkController(QObject* parent=nullptr);
    void configure(NetworkService* service);
    void setActive(bool active);
    void openWifi(){openFace(false);}
    void openBluetooth(){openFace(true);}
    bool bluetooth() const{return bluetooth_;}
    bool busy() const{return busy_;}
    int focusIndex() const{return focus_;}
    QVariantList rows() const{return rows_;}
    QString status() const{return status_;}
    QString prompt() const{return prompt_;}
    QString confirmLabel() const;
    QString actionLabel() const {return selected().value("connected").toBool()?(bluetooth_?"Disconnect":"Details"):bluetooth_&&!selected().value("saved").toBool()?"Pair":"Connect";}
    bool canForget() const {return selected().value("saved").toBool();}
    bool detailsOpen() const {return !detail_.isEmpty();}
    QVariantMap networkInfo() const;
    QVariantList detailActions() const;
    int detailFocus() const {return detailFocus_;}
    bool failed() const {return failed_;}
    QVariantMap connection() const;
    void dispatch(Action action);
    void applyText(const QString& text);
    void cancelText();
    void leave();
    Q_INVOKABLE void selectFace(bool bluetooth);
    Q_INVOKABLE void activate(int index);
    Q_INVOKABLE void showDetails(int index);
    Q_INVOKABLE void activateDetail(const QString& id);
    Q_INVOKABLE void otherNetwork();
    Q_INVOKABLE void search(){dispatch(Action::ToggleContinue);}
    Q_INVOKABLE void forget(){dispatch(Action::LocalAction);}
    Q_INVOKABLE void back(){dispatch(Action::Back);}
    Q_INVOKABLE void toggleRadio(){if(!busy_&&prompt_.isEmpty()&&textMode_.isEmpty())emit radioRequested(bluetooth_?3:2);}
signals:
    void connectionChanged();
    void changed();
    void backRequested();
    void textRequested(const QString& title,int limit,bool secret);
    void closeKeyboardRequested();
    void radioRequested(int index);
private:
    void openFace(bool bluetooth);
    void run(const QString& op,const QJsonObject& extra={});
    void receive(const QJsonObject& event);
    void confirm();
    void connectWifi(const QVariantMap& row,bool editPassword=false);
    QVariantMap selected() const{return rows_.value(focus_).toMap();}
    NetworkService* service_=nullptr;
    QNetworkInformation* information_=nullptr;
    QTimer poll_;
    QVariantList rows_;
    QJsonObject pending_;
    QVariantMap detail_,target_;
    QString operation_;
    int detailFocus_=0;
    bool failed_=false;
    QString status_,prompt_,textMode_,confirmation_;
    bool bluetooth_=false,busy_=false,active_=false;
    int pendingFace_=-1;
    int focus_=0;
};
}
