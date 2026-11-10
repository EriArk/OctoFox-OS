#pragma once
#include "core/input/Action.h"
#include <QObject>
#include <QJsonObject>
#include <QSet>
#include <QStringList>
#include <QPointer>
#include <QVariantList>

namespace trainer {
class BackendAccount;
// Presentation state only. Directory admission, hosting and commerce remain
// with Lobby/SDK/Backend; this preparation does not advertise those services.
class BazaarCatalogue final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList rooms READ rooms NOTIFY rowsChanged)
    Q_PROPERTY(QString selection READ selection NOTIFY changed)
    Q_PROPERTY(int selectedIndex READ selectedIndex NOTIFY changed)
    Q_PROPERTY(QString search READ search NOTIFY changed)
    Q_PROPERTY(bool favoritesOnly READ favoritesOnly NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString dialog READ dialog NOTIFY changed)
    Q_PROPERTY(QVariantList realms READ realms NOTIFY changed)
    Q_PROPERTY(int realmIndex READ realmIndex NOTIFY changed)
    Q_PROPERTY(QVariantList dialogRows READ dialogRows NOTIFY changed)
    Q_PROPERTY(int dialogIndex READ dialogIndex NOTIFY changed)
    Q_PROPERTY(QVariantMap account READ account NOTIFY changed)
    Q_PROPERTY(QString summary READ summary NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool more READ more NOTIFY changed)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY changed)
    Q_PROPERTY(qreal scroll READ scroll WRITE setScroll NOTIFY scrollChanged)
public:
    explicit BazaarCatalogue(QObject* parent=nullptr):QObject(parent){}
    QVariantList rooms() const { return visible_; }
    QString selection() const { return selection_; }
    int selectedIndex() const;
    QString search() const { return search_; }
    bool favoritesOnly() const { return favoritesOnly_; }
    QString status() const { return status_; }
    QString dialog() const { return dialog_; }
    QVariantList realms() const { return realms_; }
    int realmIndex() const { return realmIndex_; }
    qreal scroll() const { return scroll_; }
    void setScroll(qreal value);
    void setOwner(QString owner);
    void setBackend(BackendAccount* backend);
    void setActive(bool value);
    bool active() const { return active_; }
    bool busy() const;
    bool more() const { return !next_.isEmpty(); }
    QString summary() const;
    QString message() const { return message_; }
    QVariantMap account() const;
    QVariantList dialogRows() const;
    int dialogIndex() const { return dialogIndex_; }
    QString editorTitle() const;
    int editorLimit() const;
    void applyText(QString text);
    Q_INVOKABLE void refresh(bool append=false);
    Q_INVOKABLE void dialogAction(QString action);
    Q_INVOKABLE void openMenu();
    void setConnectionState(QString state);
    QJsonObject navigation() const;
    void restore(const QJsonObject& state);
    bool dispatch(Action action);
    void applySearch(QString text);
    Q_INVOKABLE void focus(QString id);
    Q_INVOKABLE void activate(QString id);
    Q_INVOKABLE void editSearch();
    Q_INVOKABLE void toggleFilter();
    Q_INVOKABLE void toggleFavorite(QString id);
    Q_INVOKABLE void closeDialog(bool all=false);
    Q_INVOKABLE void chooseRealm(int index);
signals:
    void changed();
    void rowsChanged();
    void scrollChanged();
    void textRequested(QString initial);
    void notice(QString text);
private:
    friend class BazaarCatalogueTests;
    friend class BazaarFixture;
    void syncBackend();
    void beginForm(bool editing);
    QJsonObject formDetails() const;
    void rebuild();
    void focusRoom(int index);
    // Supplied only by isolated UI fixtures today. No guessed provider schema,
    // raw game-lobby rows or user-controlled launch commands enter this model.
    void setPresentation(QVariantList rooms,QVariantList realms,QString status);
    QPointer<BackendAccount> backend_;
    QJsonObject draft_, own_;
    QString backendPlayer_, next_, message_, textField_, detailId_;
    bool active_=false, loading_=false, saving_=false, connected_=false, fixture_=false, reloadDraft_=false;
    quint64 generation_=0;
    int dialogIndex_=0;
    QString owner_, search_, selection_="official", lastRoom_;
    QString connection_, status_="Sign in to browse player bazaars.", dialog_;
    QVariantList all_, visible_, realms_;
    QSet<QString> favorites_;
    bool favoritesOnly_=false;
    qreal scroll_=0;
    int realmIndex_=0;
};
}
