#pragma once
#include "core/input/Action.h"
#include <QObject>
#include <QVariantMap>
#include <QJsonObject>
#include <QJsonArray>
#include <functional>
#include <QFutureWatcher>
#include <QTemporaryDir>
namespace trainer {
class BackendAccount;
class TrainerController;
class OutfitController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap view READ view NOTIFY changed)
public:
    OutfitController(BackendAccount&,TrainerController&,QObject* parent=nullptr);
    ~OutfitController() override;
    QVariantMap view() const;
    QJsonArray shipLooks() const;
    QJsonArray shipParts(const QJsonObject& recipe,const QString& field) const;
    void wearShipLook(const QString& slot,const QJsonObject& expected,const QString& field,const QString& item,std::function<void(QString)> done);
    void refreshGarments(std::function<void()> done = {});
    Q_INVOKABLE void nextDyeChannel();
    void open(); void close(); void dispatch(Action); void acceptName(const QString&);
    Q_INVOKABLE void select(int);
    Q_INVOKABLE void activate(int);
    Q_INVOKABLE void confirm(bool);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void selectCategory(int);
    Q_INVOKABLE void selectItem(int);
    Q_INVOKABLE void equip();
    Q_INVOKABLE void chooseColour(int);
    Q_INVOKABLE void conflict(bool keepLocal);
    Q_INVOKABLE int posePreview(QObject* loader, qreal amount);
signals:
    void changed(); void backRequested(); void nameRequested(const QString&); void editRequested();
    void admired(); void rotateRequested(int degrees);
private:
    QStringList dyeChannels() const;
    QStringList unlockedDyes() const;
    void loadPalette();
    void paintGarment(const QString& dye);
    QJsonObject palette_;
    QString paletteOwner_;
    int dyeChannel_=0;
    bool painting_=false;
    QJsonArray ownedGarments() const;
    void readGarments(QString player,QString after,QJsonArray rows,quint64 generation,std::function<void()> done);
    QJsonArray garments_;QString garmentOwner_;quint64 garmentGeneration_=0;
    QVariantList rows() const; QVariantMap selected() const; QVariantList items() const;
    QString colourKey() const; QJsonObject recipe() const;
    QStringList colours() const;
    bool commit(const QJsonObject&); void saveLive(); void preview(); void startPreview();
    BackendAccount& account_; TrainerController& trainer_;
    bool open_=false,liveFailed_=false,livePending_=false;
    int index_=0,focus_=2,category_=1,item_=0,colour_=0,command_=0;
    QString owner_,player_,status_,previewUrl_,previewError_,nameSlot_;
    QJsonObject appearance_,free_,previewAppearance_;
    QFutureWatcher<QJsonObject> job_; QTemporaryDir cache_;
    quint64 generation_=0,jobGeneration_=0;
};
}
