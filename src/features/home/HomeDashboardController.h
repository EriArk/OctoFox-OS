#pragma once
#include "core/input/Action.h"
#include "core/repository/LibraryRepository.h"
#include "integrations/achievements/AchievementProvider.h"
#include "features/social/SocialController.h"
#include <QObject>
#include "HomeCompanion.h"

namespace trainer {
// Read-only game projections; shared Home focus and per-profile widget choice.
class HomeDashboardController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList people READ people NOTIFY changed)
    Q_PROPERTY(QVariantList achievements READ achievements NOTIFY changed)
    Q_PROPERTY(bool genericLayout READ genericLayout NOTIFY changed)
    Q_PROPERTY(QString focus READ focus NOTIFY changed)
    Q_PROPERTY(QVariantMap widget READ widget NOTIFY changed)
    Q_PROPERTY(QVariantList widgetChoices READ widgetChoices NOTIFY changed)
    Q_PROPERTY(bool widgetPicking READ widgetPicking NOTIFY changed)
    Q_PROPERTY(int widgetChoiceIndex READ widgetChoiceIndex NOTIFY changed)
    Q_PROPERTY(trainer::HomeCompanion* companion READ companion CONSTANT)
public:
    HomeDashboardController(LibraryRepository&,AchievementProvider&,SocialController&,QObject* parent=nullptr);
    QVariantList people() const;
    QVariantList achievements() const;
    void setContext(QString adventure,bool generic);
    void setOwner(const QString& owner);
    HomeCompanion* companion(){return &companion_;}
    QVariantMap widget() const;
    QVariantList widgetChoices() const;
    bool widgetPicking() const {return widgetPicking_;}
    int widgetChoiceIndex() const {return widgetChoiceIndex_;}
    void editWidget();
    void activateWidget();
    Q_INVOKABLE void chooseWidget(const QString& id);
    Q_INVOKABLE void closeWidgetPicker();
    bool genericLayout() const {return generic_;}
    QString focus() const{return focus_;}
    void select(const QString&);
    void move(Action);
    QVariantMap target(const QString&) const;
    void reset(){companion_.end();focus_="play";emit changed();}
signals:
    void changed();
    void scrollRequested(int direction);
    void widgetActivated(QString id);
private:
    QList<QStringList> zones() const;
    LibraryRepository& library_;
    AchievementProvider& provider_;
    SocialController& social_;
    HomeCompanion companion_{this};
    QString focus_="play",adventure_;
    QString ownerKey_,widgetId_;
    bool widgetPicking_=false;
    int widgetChoiceIndex_=0;
    bool generic_=false;
    mutable bool achievementsCached_=false;
    mutable std::optional<quint64> achievementsRevision_;
    mutable AchievementContext achievementsContext_;
    mutable QVariantList achievementsCache_;
};
}
