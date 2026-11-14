#include "HomeSmokeScenario.h"
#include "../fixtures/HomeSocialFixture.h"
#include "../fixtures/HomeWidgetPackage.h"
#include "features/home/PlayHistoryController.h"
#include <QCoreApplication>
#include <QQuickItem>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QTimer>
#include <QTemporaryDir>
#include <QSettings>
#include <QQmlComponent>
#include <QQmlEngine>
#include "features/home/BadgeAssets.h"
#include <memory>

using namespace trainer;
namespace {
class HomeProgressFixture final : public GameProgressProvider {
public:
    using GameProgressProvider::GameProgressProvider;
    QString selected = "home-0";
    GameProgress value;
    QString adventureId() const override { return selected; }
    GameProgress snapshot() const override { return value; }
    void publish() { emit changed(); }
};
}
void startHomeSmoke(QQuickWindow* window, ShellController& shell, SessionState& session, LocalStateStore& store,
        ControllerInput& input, ProbeAdventureAdapter& adapter, SDL_Joystick* joystick, bool reopen,
        const QString& screenshotDir, bool& completed, int& warnings, QStringList& diagnostics) {
    // Offscreen screen dimensions differ from the window. Exercise actual logical
    // 960x540 and 800x450 layouts without inheriting the developer's density.
    QSettings settings;
    const auto previousController=input.profile();
    QObject::connect(window,&QObject::destroyed,[&input,previousController]{input.setProfile(previousController);});
    const auto previousProfile=settings.value("display/profile"),previousScale=settings.value("display/interfaceScale");
    QObject::connect(window,&QObject::destroyed,[previousProfile,previousScale]{
        QSettings restored;
        if(previousProfile.isValid())restored.setValue("display/profile",previousProfile);else restored.remove("display/profile");
        if(previousScale.isValid())restored.setValue("display/interfaceScale",previousScale);else restored.remove("display/interfaceScale");
    });
    settings.setValue("display/profile","auto");settings.setValue("display/interfaceScale",100);
    emit shell.settings()->changed();
    auto* process = new ProcessService(window);
    auto* launch = new AdventureLaunchController(*process, window);
    auto* history = new PlayHistoryController(*launch, store, window);
    auto* progress = new HomeProgressFixture(window);
    // The focused fixture supplies its own owner; the full tour selects one later.
    const bool resourcesOnly=qEnvironmentVariableIsSet("TRAINEROS_HOME_RESOURCE_PROBE");
    auto stage = std::make_shared<int>(0);
    auto starts = std::make_shared<int>(0), returns = std::make_shared<int>(0);
    auto failed = std::make_shared<bool>(false);
    QObject::connect(window, &QQuickWindow::afterAnimating, window, [=, &diagnostics] {
        if (*stage < 41 || *stage > 51) return;
        QQuickItem* panels[2]{};
        QList<QQuickItem*> pending{window->contentItem()};
        while (!pending.isEmpty()) {
            auto* item = pending.takeLast(); pending.append(item->childItems());
            if (item->objectName()=="quick-apps-drawer") panels[0]=item;
            if (item->objectName()=="continue-drawer") panels[1]=item;
        }
        const auto require = [&](bool ok, const QString& message) {
            if (!ok) { *failed=true; if (!diagnostics.contains(message)) diagnostics.append(message); }
        };
        for (auto* panel : panels) if (panel) {
            require(qAbs(panel->width()-panel->property("closedWidth").toReal())<.1 ||
                    qAbs(panel->width()-panel->property("expandedWidth").toReal())<.1,
                    "Drawer animation never stretches horizontally");
            if (panel->property("panelVisible").toBool())
                for (auto* other : panels) if (other)
                    require(other->property("handleDrop").toReal()>43.8,
                            "Both handles sink before a panel rises");
        }
        if (panels[0] && panels[1])
            require(!(panels[0]->property("panelVisible").toBool() && panels[1]->property("panelVisible").toBool()),
                    "Switching drawers closes one before raising the next");
    });
    auto widgetPackage = std::make_shared<QTemporaryDir>();
    auto artworkWaits = std::make_shared<int>(0);
    auto returningToSelector = std::make_shared<bool>(false);
    const auto program = QDir(QCoreApplication::applicationDirPath()).filePath(
#ifdef Q_OS_WIN
        "trainer_process_probe.exe"
#else
        "trainer_process_probe"
#endif
    );
    adapter.request = [&, launch, program] { return launch->launch({program, {}, {}}, shell.navigationState(), shell.home()["adventureId"].toString()); };
    QObject::connect(launch, &AdventureLaunchController::adventureStarted, window, [starts](const QString&) { ++*starts; });
    QObject::connect(launch, &AdventureLaunchController::checkpointRequested, &store, [&, launch](quint64 token, const QJsonObject& state) {
        store.saveNavigation(state, launch, [launch, token](const QString& error) { launch->checkpointCompleted(token, error); });
    });
    QObject::connect(launch, &AdventureLaunchController::changed, &session, [&, launch] { session.setAdventureActive(launch->active()); });
    QObject::connect(launch, &AdventureLaunchController::suspendRequested, window, [&, window] { input.setEnabled(false); window->hide(); });
    QObject::connect(launch, &AdventureLaunchController::restoreRequested, window, [&, window, returns](const QJsonObject& state) {
        ++*returns; shell.restoreNavigation(state); window->show(); window->requestActivate(); input.setEnabled(true);
    });
    auto* timer = new QTimer(window); timer->setInterval(250);
    QObject::connect(timer, &QTimer::timeout, window, [=, &shell, &session, &store, &input, &completed, &warnings, &diagnostics] {
        const auto check = [&](bool condition, const QString& text) { if (!condition) { *failed = true; diagnostics.append(QString("Home stage %1: %2").arg(*stage).arg(text)); } };
        const auto press = [&](SDL_GameControllerButton button) {
            SDL_JoystickSetVirtualButton(joystick, button, 1); input.poll(); SDL_JoystickSetVirtualButton(joystick, button, 0); input.poll();
        };
        const auto focusIs = [&](const QString& name) { return window->activeFocusItem() && window->activeFocusItem()->objectName() == name; };
        const auto itemNamed = [&](const QString& name, QQuickItem* scope = nullptr) -> QQuickItem* {
            QList<QQuickItem*> pending{scope ? scope : window->contentItem()};
            while (!pending.isEmpty()) {
                auto* item = pending.takeLast();
                if (item->objectName() == name) return item;
                pending.append(item->childItems());
            }
            return nullptr;
        };
        const auto capture = [&](const QString& name) { if (!screenshotDir.isEmpty()) check(window->grabWindow().save(screenshotDir + "/" + name + ".png"), "Capture failed"); };
        if (session.blocked() || launch->active() || store.pending()) return;
        switch ((*stage)++) {
        case 0:
            if(resourcesOnly) {
                store.saveAsync({"home-resource-probe","Resource Test","compass",{},QDateTime::currentDateTimeUtc()},window,
                    [failed,&shell,&diagnostics](ProfileWriteResult result){
                        *failed|=!result.success;
                        if(result.success)shell.trainer()->reload();else diagnostics.append(result.error);
                    });
                *stage=91;break;
            }
            capture("home-first-use");
            if (reopen) { *stage = 9; break; }
            store.saveAsync({"home-owner", "Fixture", "compass", {}, QDateTime::currentDateTimeUtc()}, window,
                [failed](ProfileWriteResult result) { if (!result.success) *failed = true; });
            for (int i = 0; i < 5; ++i) {
                AdventureRegistration record; record.adventure.id = "home-" + QString::number(i);
                record.adventure.title = "Original Adventure " + QString::number(i + 1);
                record.adventure.worldId = i % 2 ? "johto" : "hoenn"; record.adventure.adapterId = "test-process";
                record.contentPath = program;
                store.saveAdventureAsync(record, window, [&, window, i, failed](LibraryWriteResult result) {
                    if (!result.success) { *failed = true; return; }
                    PlaySession value{"seed-" + QString::number(i), "home-" + QString::number(i), QDateTime::fromString("2026-09-01T10:00:00.000Z", Qt::ISODateWithMs).addSecs(i * 1000), {}, {}, PlaySessionOutcome::Running};
                    const ExitMediaSource source{"home-owner", "pokemon", *store.registration(value.adventureId)};
                    store.saveSessionMediaAsync(value, source, {}, window, [&, window, value, source, failed](const QString& error) mutable {
                        if (!error.isEmpty()) { *failed = true; return; }
                        value.endedAt = value.startedAt.addSecs(720); value.elapsedSeconds = 720; value.outcome = PlaySessionOutcome::Returned;
                        QImage image(640, 360, QImage::Format_RGB32); image.fill(QColor("#638eca"));
                        QPainter paint(&image);
                        paint.fillRect(0, 210, 640, 150, QColor("#497643"));
                        paint.fillRect(240, 220, 115, 140, QColor("#ddb467"));
                        paint.setBrush(QColor("#fff2b1")); paint.setPen(Qt::NoPen); paint.drawEllipse(470, 45, 65, 65);
                        paint.fillRect(0, 0, 50, 360, Qt::black); paint.fillRect(590, 0, 50, 360, Qt::black); paint.end();
                        store.saveSessionMediaAsync(value, source, ExitCapture{image, value.endedAt}, window,
                            [failed](const QString& e) { if (!e.isEmpty()) *failed = true; });
                    });
                });
            }
            break;
        case 1:
            check(store.recentSessions().size() == 5 && shell.home()["adventureId"] == "home-4", "Latest launch is the default Home");
            check(focusIs("home-launch"), "Main button has initial focus");
            { auto legacy=shell.navigationState();legacy.remove("drawer");legacy["resume"]=shell.resumePoints().last().toMap()["id"].toString();shell.restoreNavigation(legacy); }
            press(SDL_CONTROLLER_BUTTON_X); break;
        case 2:
            if(auto* drawer=itemNamed("continue-drawer");drawer && qAbs(drawer->height()-162)>.1){--*stage;return;}
            if(auto* selected=window->activeFocusItem()) {
                const auto bounds=selected->mapRectToScene(selected->boundingRect());
                check(focusIs("resume-4") && bounds.left()>=0 && bounds.right()<=window->width(),QString("Legacy selection without scroll must be revealed on first open (index=%1 focus=%2 left=%3 right=%4 width=%5)").arg(shell.focusIndex()).arg(selected->objectName()).arg(bounds.left()).arg(bounds.right()).arg(window->width()));
            } else check(false,"Migrated drawer selection has no focus");
            for (int i = 0; i < 4; ++i) press(SDL_CONTROLLER_BUTTON_DPAD_RIGHT);
            break;
        case 3: {
            check(focusIs("resume-4"), QString("Controller reaches fifth card (index=%1, focus=%2)").arg(shell.focusIndex()).arg(window->activeFocusItem()?window->activeFocusItem()->objectName():"none"));
            auto* card = window->activeFocusItem();
            if (card) { const auto rect = card->mapRectToScene(card->boundingRect()); check(rect.left() >= 0 && rect.right() <= window->width(), "Scrolled card stays inside screen"); }
            capture("home-recent-scroll"); press(SDL_CONTROLLER_BUTTON_START); break;
        }
        case 4:
            if (!*returningToSelector) {
                check(shell.menuOpen(), "Start opens system menu above selector");
                press(SDL_CONTROLLER_BUTTON_A);
                *returningToSelector = true; --*stage; break;
            }
            // Deferred QML focus settles after closing the system overlay.
            check(focusIs("resume-4"), "Back restores selected card");
            press(SDL_CONTROLLER_BUTTON_B); break;
        case 5: {
            check(*starts == 0 && *returns == 0 && shell.notice().isEmpty(), "Selecting a card must never launch");
            check(!shell.drawerOpen() && focusIs("home-launch") && shell.home()["adventureId"] == "home-0", "Selection rebuilds Home and focuses main button");
            check(shell.home()["recordedTime"] == "12 min" && shell.home()["badges"] == "—", "Real duration and unknown progress remain separate");
            progress->value.availability = ProgressAvailability::Available;
            progress->value.badgeMask = 0xa5; progress->value.caught = 241;
            progress->value.badgeSet = "kanto-frlg";
            progress->value.message = "Last in-game save · National Pokédex";
            PartySnapshot team;
            for (int i = 0; i < 6; ++i) {
                PokemonRecord member; member.kind = PokemonSlotKind::Known;
                member.nickname = "Partner " + QString::number(i + 1);
                member.speciesId = "pikachu"; member.formId = "25";
                team.party.append(member);
            }
            progress->value.party = team;
            shell.configureProgress(progress);
            window->resize(1920, 1080); break;
        }
        case 6:
            {
                auto* party = itemNamed("home-party");
                check(party && party->isVisible() && itemNamed("home-party-5"), "Home renders the observed six-member Party without opening Center");
                if (party) {
                    const auto bounds = party->mapRectToScene(party->boundingRect());
                    check(bounds.left() > window->width() * .29 && bounds.bottom() < window->height() * .91,
                        "Living Party fits beside the Y tab and above chassis legends");
                }
                check(focusIs("home-launch"), "Living Party never steals Home A focus");
            }
            check(shell.home()["badges"] == "4" && shell.home()["caught"] == "241"
                && shell.home()["badgeSlots"].toList().size() == 8 && shell.home()["badgeSet"] == "kanto-frlg", "Verified save fields reach Home independently of recorded time");
            capture("home-selected-1080p"); press(SDL_CONTROLLER_BUTTON_B); break;
        case 7:
            check(*starts == 1 && *returns == 1 && focusIs("home-launch"), "Main button alone launches and restores Home");
            check(store.recentSessions().first().adventureId == "home-0" && store.recentSessions().size() == 5, "History replaces the latest card without duplicates");
            check(history->error().isEmpty(), "History writes succeeded");
            HomeSocialFixture::publish(*shell.social(),{{"state","connected"},{"userId","home-fixture"},{"chats",QVariantList{HomeSocialFixture::chat("home-chat","home-peer","Test friend")}}});
            press(SDL_CONTROLLER_BUTTON_DPAD_UP);
            check(shell.dashboard()->focus()=="lobbies","D-pad reaches the lobby row");
            press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);
            check(shell.dashboard()->focus()=="person:home-peer","D-pad reaches the Home conversation without launch");
            press(SDL_CONTROLLER_BUTTON_B);check(shell.primaryId()=="online" && *starts==1,"A opens selected conversation, not game");
            press(SDL_CONTROLLER_BUTTON_A);check(shell.primaryId()=="home" && shell.dashboard()->focus()=="person:home-peer","Back preserves exact Home target");
            press(SDL_CONTROLLER_BUTTON_DPAD_RIGHT);
            check(shell.dashboard()->focus()=="play","Right returns to Play");
            press(SDL_CONTROLLER_BUTTON_B); break;
        case 8:
            check(*starts == 2 && *returns == 2 && !shell.drawerOpen(), "A launches only after returning focus to Play");
            press(SDL_CONTROLLER_BUTTON_X); check(shell.drawerOpen(), "Y opens the selector independently"); press(SDL_CONTROLLER_BUTTON_A);
            check(focusIs("home-launch"), "Cancel restores the fixed page action");
            press(SDL_CONTROLLER_BUTTON_START);
            if (auto* party = itemNamed("home-party")) check(!party->property("playing").toBool(), "Home Party pauses behind the system menu");
            shell.activate(0); // The Start Settings action, independent of widget order.
            check(shell.service()=="settings" && *starts == 2, "Start opens Settings without launching Home's Adventure");
            shell.dispatch(Action::Back);
            press(SDL_CONTROLLER_BUTTON_RIGHTSHOULDER); press(SDL_CONTROLLER_BUTTON_LEFTSHOULDER);
            check(shell.primaryId()=="home" && shell.home()["adventureId"] == "home-0", "Shoulders retain the selected Home Adventure");
            progress->selected = "another-adventure"; progress->publish();
            if (auto* party = itemNamed("home-party")) check(!party->isVisible(), "Another Adventure's Party must disappear from Home");
            check(shell.home()["badges"] == "—" && shell.home()["caught"] == "—", "An unrelated Adventure cannot populate Home");
            progress->selected = "home-0"; progress->value = {};
            progress->value.message = "Progress is not supported for this edition yet."; progress->publish();
            check(shell.home()["badges"] == "—" && shell.home()["badgeSlots"].toList().isEmpty(), "Unsupported progress stays unknown");
            break;
        case 9:
            check(focusIs("home-launch"), "Home focus is restored after the page transition settles");
            check(shell.home()["exitPreview"] == (reopen?QString():QString("image://exit-media/seed-0")), "Home uses only its selected game's clean exit image");
            {
                bool found = false;
                for (const auto& row : shell.resumePoints()) if (row.toMap()["id"] == "recent:home-0") {
                    found = row.toMap()["preview"] == "image://exit-media/seed-0";
                }
                check(found, "Canonical clean exit image survives newer uncaptured sessions and restart");
            }
            check(shell.navigationState()["homeAdventure"] == (reopen?"home-generic":"home-0") && shell.home()["adventureId"] == (reopen?"home-generic":"home-0"), "Last explicit Home choice survives restart, including the later generic-card fixture");
            check(store.recentSessions().size() == 5 && store.recordedSeconds("home-0").has_value(), "History survives restart");
            check(!reopen || *starts == 0, "Reopening the journal does not launch anything");
            capture(reopen ? "home-reopened" : "home-return");
            if (reopen) { *stage = 19; break; }
            progress->value.availability = ProgressAvailability::Available;
            progress->value.badgeMask = 255; progress->value.caught = 386; progress->value.badgeSet = "kanto-frlg";
            progress->value.message = "Last in-game save · National Pokédex"; progress->publish();
            window->resize(960, 540); break;
        case 10:
            for (int i = 0; i < 8; ++i) {
                QQuickItem* badge = nullptr;
                QList<QQuickItem*> pending{window->contentItem()};
                while (!pending.isEmpty()) {
                    auto* item = pending.takeLast();
                    if (item->objectName() == "home-badge-" + QString::number(i)) { badge = item; break; }
                    pending.append(item->childItems());
                }
                check(badge && badge->width() >= 26 && badge->height() >= 40, "Large badge remains readable at handheld size");
                if (badge) {
                    check(badge->property("imageReady").toBool(), "Real badge asset loads in the rendered app");
                    const auto bounds = badge->mapRectToScene(badge->boundingRect());
                    check(bounds.left() >= 0 && bounds.right() <= window->width() && bounds.bottom() <= window->height(), "Badge stays inside the viewport");
                }
            }
            check(focusIs("home-launch"), "Decorative badges add no directional focus stops");
            capture("home-badges-kanto-960");
            progress->value.badgeSet = "hoenn-rse"; progress->publish(); break;
        case 11:
            {
                auto* art=itemNamed("home-card-illustration");
                auto* card=itemNamed("home-game-card");
                check(art && card && art->parentItem()==card,"Illustration must belong only to the game card");
                auto* awards=itemNamed("home-awards");auto* widget=itemNamed("home-widget-slot");
                check(awards && card && awards->parentItem()==card,"Adapter achievements stay inside its card");
                check(widget && qAbs(widget->height()-208)<1 && widget->width()>=232,"Adapter Home leaves the shared 4 by 4 widget slot intact");
            }
            check(!itemNamed("home-exit-picture"), "Owner temporarily disabled screenshot backgrounds on Home");
            if(auto* card=itemNamed("home-game-card"))check(card->width()>card->parentItem()->width()*.63,"Home reserves roughly two thirds for the game card");
            check(itemNamed("home-screens") && itemNamed("home-launch-label"),"Screens collage and launch label are present");
            if (auto* launchButton = itemNamed("home-launch"))
                check(qAbs(launchButton->width()-launchButton->height()) < 1, "Sculpted A keeps a circular footprint");
            capture("home-badges-hoenn-960");
            progress->value.badgeMask = 0; progress->publish(); break;
        case 12:
            check(shell.home()["badges"] == "0", "An empty badge tray represents verified zero, not unknown");
            capture("home-badges-empty-960");
            progress->value.badgeSet = "paldea"; progress->publish(); break;
        case 13:
            check(shell.home()["badgeSlots"].toList().isEmpty() && shell.home()["badges"] == "0", "Unsupported art keeps a truthful count without substituting another set");
            capture("home-badges-unmapped-960");
            progress->value.badgeSet = "kanto-frlg"; progress->value.badgeMask.reset(); progress->publish(); break;
        case 14: {
            check(shell.home()["badges"] == "—", "Unavailable exact bits do not become zero");
            for (const auto& slot : shell.home()["badgeSlots"].toList())
                check(slot.toMap()["state"] == "unknown" && slot.toMap()["image"].toString().isEmpty(), "Unknown identities use neutral mounts");
            capture("home-badges-unknown-960");
            QQmlComponent component(qmlEngine(window), QUrl("qrc:/TrainerOS/BadgeTray.qml"));
            auto* tray = qobject_cast<QQuickItem*>(component.create());
            check(tray != nullptr, "Reusable large badge case can be instantiated");
            if (tray) {
                tray->setParent(window); tray->setParentItem(window->contentItem());
                tray->setObjectName("badge-case-fixture"); tray->setX(50); tray->setY(180); tray->setWidth(860); tray->setHeight(165); tray->setZ(100);
                tray->setProperty("slots", BadgeAssets::entries("hoenn-rse", 255)); tray->setProperty("count", "8");
            }
            break;
        }
        case 15:
            capture("badges-large-case-fixture");
            delete window->findChild<QQuickItem*>("badge-case-fixture");
            progress->value.badgeMask = 255; progress->publish();
            shell.goToTrainerFace("journey"); break;
        case 16:
            check(!shell.adapterMenuOpen(), "A direct Journey route enters its content, not the adapter menu");
            check(focusIs("journey-primary") && shell.home()["badgeSlots"].toList().size() == 8, "Journey keeps a fixed action beside verified badge data");
            capture("journey-badges-960");
            progress->value.badgeMask = 0; progress->publish(); break;
        case 17:
            check(shell.home()["badges"] == "0", "Journey keeps verified zero distinct from unknown");
            capture("journey-zero-960"); progress->selected = "another-adventure"; progress->publish(); break;
        case 18:
            check(shell.home()["badgeSlots"].toList().isEmpty(), "Unrelated save data cannot populate Journey");
            capture("journey-unknown-960"); shell.goToPage(0); break;
        case 19:
            window->resize(1920,1080);progress->selected=shell.currentAdventureId();
            progress->value.badgeMask=255;progress->publish();break;
        case 20: case 21: case 22: case 23: case 24: {
            const auto theme=shell.settings()->theme();
            auto* background=itemNamed("home-card-illustration");
            if(background && !background->property("artworkReady").toBool() && ++*artworkWaits<20){--*stage;return;}
            check(background && background->property("artworkReady").toBool(),"Themed artwork loaded and painted before capture");*artworkWaits=0;
            check(background && background->property("themeId").toString()==theme,"Home backdrop follows the active theme live");
            check(!itemNamed("home-exit-picture"),"A saved screenshot must not replace the themed landscape");
            capture("home-theme-"+theme);
            shell.settings()->cycleTheme(1);break;
        }
        case 25:
            shell.activateDashboard("screens");break;
        case 26:
            check(shell.service()=="profile" && shell.profileRoute()=="story" && shell.overviewFace()=="screens","Collage opens Screens in the profile");
            shell.dispatch(Action::Back);break;
        case 27:
            check(shell.primaryId()=="home" && shell.dashboard()->focus()=="screens","Back restores the Home collage focus");
            check(focusIs("home-screens"),"Collage owns visual controller focus");capture("home-collage-focus");break;
        case 28: {
            if (store.registration("home-generic")) break; // Reopen reuses the persisted fixture.
            AdventureRegistration record;record.adventure.id="home-generic";
            record.adventure.title="A long adventure across the valley";record.adventure.domain="multiverse";
            record.adventure.platformId="gba";record.adventure.adapterId="test-process";
            record.adventure.description="Explore the valley, meet your friends and discover a new story together. A long description should stay in its own readable column beside the photo album.";
            record.contentPath=program;
            store.saveAdventureAsync(record,window,[failed,&diagnostics](LibraryWriteResult r){if(!r.success){*failed=true;diagnostics.append("Generic Home fixture: "+r.error);}});break;
        }
        case 29: {
            shell.refreshLibrary();auto state=shell.navigationState();state["homeAdventure"]="home-generic";shell.restoreNavigation(state);
            shell.goToPage(0);window->resize(960,540);break;
        }
        case 30: {
            check(shell.dashboard()->genericLayout() && shell.homeGame()["id"]=="home-generic","A real selected game without an adapter uses the generic card");
            auto* card=itemNamed("home-game-card");auto* awards=itemNamed("home-awards");
            auto* screens=itemNamed("home-screens");auto* description=itemNamed("home-description");
            check(card && awards && awards->parentItem()==card,"Generic achievements are inside the game card");
            auto* widget=itemNamed("home-widget-slot");
            check(widget && qAbs(widget->height()-208)<1 && widget->width()>=232,"Generic Home has the same 4 by 4 widget slot");
            check(screens && description && screens->x()>description->x()+description->width(),"Description leaves space for the top-right collage");
            check(screens && awards && screens->y()+screens->height()<awards->y(),"Collage sits above achievements");
            if(screens && awards)check(qAbs((screens->y()+screens->property("visualTop").toDouble())-(awards->y()-screens->y()-screens->property("visualBottom").toDouble()))<1,"Collage visible bounds have equal top and divider spacing");
            if(auto* button=itemNamed("home-launch"))check(!button->property("showGlyph").toBool() && button->width()>=116,"Generic launch button is larger and uses a centered word");
            auto* summary=itemNamed("home-summary");
            check(summary && description && summary->isVisible() && summary->mapRectToScene(summary->boundingRect()).bottom()<=description->mapRectToScene(description->boundingRect()).bottom()+1,"Compact generic card keeps its description visible");
            check(shell.dashboard()->achievements().isEmpty(),"Generic game never receives another game's achievements");
            capture("home-generic-960");
            shell.dispatch(Action::Up);break;
        }
        case 31:
            check(focusIs("home-screens"),"Up from generic Play reaches the top-right collage");
            shell.dispatch(Action::Confirm);break;
        case 32:
            check(shell.overviewFace()=="screens","Generic collage opens Screens");shell.dispatch(Action::Back);break;
        case 33:
            check(shell.dashboard()->focus()=="screens","Generic Screens return keeps focus");
            shell.dispatch(Action::Down);window->resize(1920,1080);break;
        case 34:
            check(focusIs("home-launch"),"Down from the generic collage returns to Play");capture("home-generic-1080p");break;
        case 35: {
            HomeSocialFixture::publish(*shell.social(),{{"state","connected"},{"userId","home-fixture"},{"chats",QVariantList{
                HomeSocialFixture::chat("a","aa","Ren",4000),HomeSocialFixture::chat("b","bb","Iris",3000),
                HomeSocialFixture::chat("c","cc","Mika",2000),HomeSocialFixture::chat("d","dd","Theo",1000)}}});
            QVariantList rows;const QStringList names{"The first trail","A team to remember","Across the valley","A new chapter","The scenic route","Lasting memory"};
            for(int i=0;i<names.size();++i)rows.append(QVariantMap{{"key","visual-fixture-"+QString::number(i)},{"name",names[i]},{"game","Original fixture"},{"icon",""}});
            if(auto* trophies=itemNamed("home-achievements"))trophies->setProperty("model",rows);
            if(auto* chips=itemNamed("home-metadata")) {
                auto game=shell.homeGame();game["year"]="2004";game["genre"]="Adventure";game["playInfo"]=QVariantMap{{"label","1-4 players"}};
                chips->setProperty("game",game);
                if(auto* marks=itemNamed("home-connection-marks",itemNamed("home-game-card")))marks->setProperty("modes",QVariantList{QVariantMap{{"id","link"},{"label","Link"},{"online",true},{"nearby",true}},QVariantMap{{"id","remoteplay"},{"label","Remote Play"},{"online",true},{"nearby",false}}});
            }
            break;
        }
        case 36: {
            auto* trophies=itemNamed("home-achievements");
            for(int i=0;i<5;++i)if(auto* medal=itemNamed("home-award-"+QString::number(i))) {
                const auto bounds=medal->mapRectToScene(medal->boundingRect());const auto row=trophies->mapRectToScene(trophies->boundingRect());
                check(bounds.left()>=row.left()-1 && bounds.right()<=row.right()+1,"Five captioned achievement slots fit the row");
            } else check(false,"Visible achievement fixture is missing");
            capture("home-five-achievements-1080p");window->resize(960,540);break;
        }
        case 37: {
            auto* summary=itemNamed("home-summary");auto* description=itemNamed("home-description");
            check(summary && description && summary->mapRectToScene(summary->boundingRect()).bottom()<=description->mapRectToScene(description->boundingRect()).bottom()+1,"Compact card keeps description above colourful chips");
            auto* people=itemNamed("home-people");
            for(int i=0;i<4;++i)if(auto* person=itemNamed("home-person-"+QString::number(i))) {
                check(person->mapRectToScene(person->boundingRect()).right()<=people->mapRectToScene(people->boundingRect()).right()+1,"Four named people fit Home");
            }else check(false,"Recent person is missing");
            check(itemNamed("home-connection-marks",itemNamed("home-game-card")) && itemNamed("home-connection-marks",itemNamed("home-game-card"))->isVisible() && itemNamed("home-connection-marks",itemNamed("home-game-card"))->height()==18,"Connection marks sit quietly beside platform");
            capture("home-five-achievements-960");shell.dispatch(Action::NextFace);break;
        }
        case 38:
            check(shell.dashboard()->focus()=="lobbies","R2 reaches people and lobby");shell.dispatch(Action::NextFace);break;
        case 39:
            check(shell.dashboard()->focus()=="play","R2 returns directly to game");shell.openNotifications();capture("header-notifications");shell.closeHomeMenu();break;
        case 40: {
            check(shell.dashboard()->focus()=="play","R2 returns to game card");break;
        }
        case 41:
            shell.dispatch(Action::Secondary);break;
        case 42: {
            auto* apps=itemNamed("quick-apps-drawer");auto* games=itemNamed("continue-drawer");
            if(apps && qAbs(apps->height()-100)>0.1){--*stage;return;}
            check(apps && games && apps->width()==games->property("expandedWidth").toReal(),"Quick Apps shares the Recent games expanded width");
            check(apps && qAbs(apps->height()-100)<0.1 && apps->height()<games->property("expandedHeight").toReal(),"Quick Apps keeps a shorter one-row body");
            check(itemNamed("quick-apps-handle") && !itemNamed("quick-apps-handle")->isVisible(),"Expanded X hides its header");
            capture("quick-apps-empty-960");
            QJsonArray rows,running;
            for(int i=0;i<12;++i) {const auto id=QString("fixture-%1.desktop").arg(i,2,10,QChar('0'));rows.append(QJsonObject{{"id",id},{"name",QString("Application %1").arg(i+1)},{"icon","application-x-executable"}});running.append(id);}
            shell.apps()->accept({{"event","catalogue"},{"rows",rows}});shell.apps()->accept({{"event","state"},{"running",running},{"current",""}});shell.apps()->accept({{"event","ready"}});
            QTemporaryDir preferences; shell.apps()->configure(preferences.path(),"quick-apps-fixture");
            shell.apps()->options(0);shell.apps()->menuAction(0);
            shell.apps()->options(1);shell.apps()->menuAction(0);
            shell.dispatch(Action::Right);break;
        }
        case 43:
            capture("quick-apps-full-960");shell.dispatch(Action::LocalAction);break;
        case 44:
            check(!shell.apps()->menu().isEmpty() && shell.quickAppsOpen(),"Select opens an owned app menu without dismissing the tray");
            shell.dispatch(Action::Back);check(shell.quickAppsOpen(),"B closes the child menu first");
            for(int i=0;i<14;++i)shell.dispatch(Action::Right);break;
        case 45:
            check(itemNamed("quick-apps-favorites") && itemNamed("quick-apps-favorites")->property("contentX").toReal()==0,"Favorites stay fixed while navigating running apps");
            if(auto* list=itemNamed("quick-apps-list"))check(list->property("contentWidth").toReal()<=list->width()+1 ? list->property("contentX").toReal()==0 : list->property("contentX").toReal()>0,"Running apps scroll only when they overflow the actual viewport");else check(false,"Running app list exists");
            check(shell.apps()->focusIndex()==11,"Horizontal app navigation reaches the last app");capture("quick-apps-overflow-960");
            shell.dispatch(Action::ToggleContinue);break;
        case 46:
            if(auto* d=itemNamed("continue-drawer");d && qAbs(d->height()-162)>0.1){--*stage;return;}
            check(shell.drawerOpen() && !shell.quickAppsOpen(),"Y replaces X");
            check(itemNamed("continue-toggle") && !itemNamed("continue-toggle")->isVisible(),"Expanded Y hides its old header");
            if(auto* card=itemNamed("resume-0"))if(auto* panel=itemNamed("continue-drawer"))
                check(card->width()*4+3*10+4*8<=panel->width()-38+.1,"Four recent cards fit the available drawer width");
            capture("adventures-shared-frame-960");shell.dispatch(Action::Back);break;
        case 47: {
            auto* apps=itemNamed("quick-apps-drawer");auto* games=itemNamed("continue-drawer");
            if(apps && games && (qAbs(apps->width()-174)>0.1 || qAbs(games->width()-174)>0.1 || apps->property("handleDrop").toReal()>.1 || games->property("handleDrop").toReal()>.1)){--*stage;return;}
            check(apps && games && apps->width()==games->width() && apps->width()==174,"Closed X/Y handles share the shorter width");
            check(apps && games && games->x()>apps->x() && games->x()+games->width()<400 && apps->height()==36 && games->height()==36,"Compact handles sit side by side at the left bezel");
            check(apps && games && qAbs(apps->mapRectToScene(apps->boundingRect()).right()-games->mapRectToScene(games->boundingRect()).left()-32*apps->mapRectToScene(apps->boundingRect()).width()/apps->width())<2 && apps->z()>games->z(),"Quick Apps is in front of the yellow right handle");
            check(itemNamed("quick-apps-handle") && itemNamed("quick-apps-handle")->isVisible(),"Folded X keeps its handle");
            check(itemNamed("quick-apps-handle-content") && !itemNamed("quick-apps-handle-content")->isVisible(),"Folded X hides app icons below its handle");
            capture("paired-handles-960");window->resize(1920,1080);shell.dispatch(Action::Secondary);break;
        }
        case 48:
            if(auto* d=itemNamed("quick-apps-drawer");d && qAbs(d->height()-100)>0.1){--*stage;return;}
            capture("quick-apps-full-1080p");shell.closeDrawers();break;
        case 49:
            if(auto* d=itemNamed("quick-apps-drawer");d && (qAbs(d->height()-36)>0.1 || qAbs(d->width()-174)>0.1 || d->property("handleDrop").toReal()>.1)){--*stage;return;}
            if(auto* launchButton=itemNamed("home-launch"))if(auto* d=itemNamed("quick-apps-drawer"))check(launchButton->mapRectToScene(launchButton->boundingRect()).bottom()<=d->mapRectToScene(d->boundingRect()).top(),"Folded Quick Apps never covers Start");
            check(!shell.quickAppsOpen() && shell.primaryId()=="home","Outside-close preserves the Home route");capture("paired-handles-1080p");break;
        case 50: {
            QJsonArray rows{QJsonObject{{"id","fixture-single.desktop"},{"name","One application"},{"icon","application-x-executable"}}};
            shell.apps()->accept({{"event","catalogue"},{"rows",rows}});
            shell.apps()->accept({{"event","state"},{"running",QJsonArray{"fixture-single.desktop"}},{"current",""}});
            shell.dispatch(Action::Secondary);break;
        }
        case 51: {
            auto* apps=itemNamed("quick-apps-drawer");
            if(apps && qAbs(apps->height()-100)>0.1){--*stage;return;}
            auto* icon=itemNamed("quick-app-slot-0");
            check(apps && icon && apps->mapRectToScene(apps->boundingRect()).contains(icon->mapRectToScene(icon->boundingRect())),"A single app stays inside the shared drawer");
            check(apps && icon && qAbs(apps->mapRectToScene(apps->boundingRect()).center().x()-icon->mapRectToScene(icon->boundingRect()).center().x())<1,"A single app is centered in the drawer");
            capture("quick-apps-single-1080p");shell.closeDrawers();break;
        }
        case 52:
            shell.goToPage(4);break;
        case 53: {
            auto* previous=itemNamed("face-previous");auto* next=itemNamed("face-next");
            auto* first=itemNamed("face-tab-0");auto* last=itemNamed("face-tab-3");
            check(previous && next && first && last,"Apps has separate shoulder hints around its faces");
            if(previous && next && first && last) {
                check(previous->mapRectToScene(previous->boundingRect()).right()<=first->mapRectToScene(first->boundingRect()).left() &&
                      next->mapRectToScene(next->boundingRect()).left()>=last->mapRectToScene(last->boundingRect()).right(),"Shoulder hints bracket the switched items");
                QMetaObject::invokeMethod(next,"activated");
            }
            break;
        }
        case 54:
            check(shell.appsFace()=="crates","Touch R2 advances Apps to Crates like the controller");
            if(auto* previous=itemNamed("face-previous"))QMetaObject::invokeMethod(previous,"activated");break;
        case 55:
            check(shell.appsFace()=="apps","Touch L2 returns to Apps");capture("navigation-apps-1080p");shell.goToPage(3);break;
        case 56:
            capture("navigation-social-1080p");shell.goToPage(2);break;
        case 57:
            check(shell.primaryId()=="home","A generic game has no empty adapter page");capture("navigation-no-adapter-home-1080p");break;
        case 58: {
            auto state=shell.social()->account();state["userId"]="profile-fixture";state["name"]="Mika";state["presence"]="idle";
            state["profile"]=QVariantMap{{"name","Mika"},{"tag","mika#1234"},{"bio","One more adventure."},{"avatar","qrc:/home-backdrops/green.png"}};
            HomeSocialFixture::publish(*shell.social(),state);
            shell.openAccountProfile();break;
        }
        case 59:
            check(shell.service()=="account-profile" && shell.primaryId()=="home","Account profile overlays the original route");
            check(itemNamed("account-profile-card") && itemNamed("account-profile-card")->isVisible(),"Profile card is visible");
            capture("account-profile-1080p");shell.settings()->communication()->editProfile();break;
        case 60:
            capture("account-profile-editor-1080p");shell.settings()->communication()->activate(0);break;
        case 61:
            check(shell.keyboard()->isOpen(),"Profile editor uses the shared keyboard");
            shell.dispatch(Action::Back);check(!shell.keyboard()->isOpen() && shell.settings()->communication()->profileEditing(),"Keyboard Back returns to profile editing");
            shell.dispatch(Action::Back);check(!shell.settings()->communication()->profileEditing() && shell.service()=="account-profile","Editor Back returns to profile");
            shell.dispatch(Action::Back);check(shell.service().isEmpty() && shell.primaryId()=="home","Profile Back restores the underlying route");break;
        case 62: {
            window->resize(960,540);shell.goToPage(0);
            shell.trainer()->beginEdit();shell.trainer()->setDraftName("Ren");shell.trainer()->activate(shell.trainer()->editRows().size()-2);break;
        }
        case 63: {
            if(shell.trainer()->saving()){--*stage;break;}
            auto* level=itemNamed("header-account-level");auto* label=itemNamed("header-account-name");auto* progress=itemNamed("header-account-progress");
            check(level && label && progress && label->x()+label->width()<level->x()
                && qAbs(level->y()-label->y())<1
                && qAbs(label->x()-progress->x())<1,
                "Compact level follows the name, with Sparks below");
            auto* hints=itemNamed("shell-button-hints");auto* status=itemNamed("footer-status");
            check(hints && status && hints->x()==18
                && hints->mapRectToScene(hints->boundingRect()).right()<status->mapRectToScene(status->boundingRect()).left(),
                "Footer hints stay left of clock, network and battery");
            auto* clock=itemNamed("footer-clock");
            auto* bell=itemNamed("footer-notification-bell");
            check(clock && bell && status && clock->x()+clock->width()<bell->x() && qAbs(bell->x()+bell->width()-status->width())<1,"Footer bell follows clock at right edge");
            auto* name=itemNamed("header-account-name");check(name && name->property("lineCount").toInt()==1,"Short profile name stays on one line");capture("header-short-name-960");
            shell.trainer()->beginEdit();shell.trainer()->setDraftName("VLADISLAV TVTIKAUSHI");shell.trainer()->activate(shell.trainer()->editRows().size()-2);break;
        }
        case 64: {
            if(shell.trainer()->saving()){--*stage;break;}
            auto* name=itemNamed("header-account-name");check(name && name->property("lineCount").toInt()==1,"Two-word profile name stays above the Sparks row");capture("header-two-word-name-960");
            shell.trainer()->beginEdit();shell.trainer()->setDraftName("ExtraordinarilyLongName");shell.trainer()->activate(shell.trainer()->editRows().size()-2);break;
        }
        case 65: {
            if(shell.trainer()->saving()){--*stage;break;}
            auto* name=itemNamed("header-account-name");check(name && name->property("contentWidth").toReal()<=name->width()+1,"Long profile name stays within its chassis area");capture("header-long-name-960");break;
        }
        case 66:
            shell.editHomeWidget();break;
        case 67: {
            check(shell.dashboard()->widgetPicking(),"Home widget picker opens");capture("home-widget-picker");
            auto* choice=itemNamed("home-widget-choice-clock");
            check(choice && QMetaObject::invokeMethod(choice,"pressAction"),"Clock has an accessible picker action");
            break;
        }
        case 68:
            check(!shell.dashboard()->widgetPicking() && shell.dashboard()->widget()["id"]=="clock","Picker applies the selected Home widget");
            check(itemNamed("start-widget-clock"),"Existing widget renderer is used on Home");capture("home-widget-clock");
            shell.editHomeWidget();shell.dispatch(Action::Back);window->resize(800,450);break;
        case 69: {
            auto* widget=itemNamed("home-widget-slot");
            check(widget && widget->height()>100 && widget->height()<150 && widget->width()>200,"Compact screen adapts without a 4 by 4 overflow");
            capture("home-widget-800");window->resize(960,540);break;
        }
        case 70:
            shell.editHomeWidget();shell.dashboard()->chooseWidget("storage");break;
        case 71:
            if(shell.device()->busy()){--*stage;break;}
            check(shell.device()->status()[1].toMap()["value"].toString().contains("32.0"),"Home Storage receives the real device-service fixture");
            capture("home-widget-storage");shell.editHomeWidget();shell.dashboard()->chooseWidget("clock");break;
        case 72: {
            auto profile=input.profile();profile["family"]="generic";check(input.setProfile(profile),"Select keyboard fallback glyphs");break;
        }
        case 73: {
            check(itemNamed("drawer-key-X")->property("text")=="X" && itemNamed("drawer-key-Y")->property("text")=="Y","Unrecognized pad uses actual keyboard X/Y shortcuts in drawer ears");
            capture("footer-keyboard");
            auto profile=input.profile();profile["family"]="playstation";check(input.setProfile(profile),"Select PlayStation glyphs");break;
        }
        case 74: {
            check(itemNamed("drawer-key-X")->property("text").toString()==QString::fromUtf8("△")
                && itemNamed("drawer-key-Y")->property("text").toString()==QString::fromUtf8("□"),"Drawer ears follow actual PlayStation button positions");
            capture("footer-playstation");auto profile=input.profile();profile["family"]="xbox";input.setProfile(profile);break;
        }
        case 75: {
            check(itemNamed("drawer-key-X")->property("text")=="Y" && itemNamed("drawer-key-Y")->property("text")=="X","Drawer ears update immediately to Xbox");
            capture("footer-xbox");auto profile=input.profile();profile["family"]="nintendo";input.setProfile(profile);break;
        }
        case 76:
            check(itemNamed("drawer-key-X")->property("text")=="X" && itemNamed("drawer-key-Y")->property("text")=="Y","Drawer ears update immediately to Nintendo");
            capture("footer-nintendo");break;
        case 77: {
            auto* network=itemNamed("footer-network");
            check(network && QMetaObject::invokeMethod(network,"pressAction"),"Footer Wi-Fi has a direct accessible action");break;
        }
        case 78: {
            auto* popup=itemNamed("footer-network-popup");auto* network=itemNamed("footer-network");
            check(shell.controlsNetworkOpen()&&!shell.menuOpen() && popup && popup->isVisible(),"Footer opens shared connections without Start");
            if(popup&&network)check(popup->mapRectToScene(popup->boundingRect()).bottom()<network->mapRectToScene(network->boundingRect()).top(),"Wi-Fi popover opens above its icon");
            capture("footer-wifi-960");window->resize(800,450);break;
        }
        case 79: {
            auto* popup=itemNamed("footer-network-popup");
            check(popup && popup->x()>=0 && popup->x()+popup->width()<=800 && popup->y()>=0,"Anchored Wi-Fi stays inside compact screen");
            capture("footer-wifi-800");
            QMetaObject::invokeMethod(itemNamed("footer-network"),"pressAction");window->resize(960,540);break;
        }
        case 80:
            check(!shell.controlsNetworkOpen()&&!shell.menuOpen(),"Second Wi-Fi press closes popover without navigation");break;
        case 81:
            shell.goToPage(1);shell.dispatch(Action::Home);
            check(shell.page()==0 && !shell.homeMenuOpen(),"Home returns directly from Games");
            shell.dispatch(Action::Home);check(!shell.homeMenuOpen() && !itemNamed("shell-home-menu"),"Repeated Home has no Now overlay");
            check(itemNamed("header-ship") && !itemNamed("notification-bell"),"Ship replaces upper bell");
            QMetaObject::invokeMethod(itemNamed("footer-notification-bell"),"pressAction");break;
        case 82: {
            auto* popup=itemNamed("notification-popover");auto* bell=itemNamed("footer-notification-bell");
            check(shell.notificationsOpen() && popup && popup->isVisible(),"Footer opens shared inbox");
            if(popup&&bell)check(popup->mapRectToScene(popup->boundingRect()).bottom()<bell->mapRectToScene(bell->boundingRect()).top(),"Inbox anchors above footer bell");
            capture("inbox-footer-960");break;
        }
        case 83: {
            auto* popup=itemNamed("notification-popover");
            check(shell.notificationsOpen(),"Inbox remains open without the removed upper bell");
            if(popup)check(popup->x()>500,"Inbox stays on the right");
            capture("inbox-lower-960");window->resize(800,450);break;
        }
        case 84: {
            auto* popup=itemNamed("notification-popover");
            check(popup && popup->x()>=0 && popup->x()+popup->width()<=800 && popup->y()>=0,"Lower inbox fits compact screen");
            capture("inbox-lower-800");shell.closeHomeMenu();
            auto chat=HomeSocialFixture::chat("call-fixture","peer-fixture","Mika");chat["ringing"]=true;chat["call"]=true;
            HomeSocialFixture::publish(*shell.social(),{{"state","connected"},{"userId","profile-fixture"},{"notificationSound",false},{"voice",QVariantMap{{"available",true}}},{"chats",QVariantList{chat}}});break;
        }
        case 85: {
            check(itemNamed("footer-hint-X") && itemNamed("footer-hint-X")->isVisible(),"Incoming call shows the Decline controller shortcut");
            auto* card=itemNamed("incoming-call-card");auto* bell=itemNamed("footer-notification-bell");
            check(card && card->isVisible() && card->height()<170 && card->x()>400,"Incoming call is a compact bottom-right banner");
            if(card&&bell)check(card->mapRectToScene(card->boundingRect()).bottom()<bell->mapRectToScene(bell->boundingRect()).top(),"Call banner stays above footer");
            capture("incoming-call-800");
            check(QMetaObject::invokeMethod(itemNamed("incoming-call-banner"),"dismiss"),"Call banner offers hide independently from decline");break;
        }
        case 86:
            check(shell.social()->incomingCall().isEmpty(),"Hidden call no longer blocks shell input");
            QMetaObject::invokeMethod(itemNamed("footer-notification-bell"),"pressAction");break;
        case 87:
            check(itemNamed("footer-hint-X") && itemNamed("footer-hint-X")->isVisible(),"Inbox shows the Decline controller shortcut");            check(shell.notificationsOpen() && itemNamed("notification-call-answer") && itemNamed("notification-call-answer")->isVisible(),"Hidden call retains direct Answer action in bell");
            check(itemNamed("notification-call-decline") && itemNamed("notification-call-decline")->isVisible(),"Hidden call retains direct Decline action in bell");
            capture("incoming-call-inbox-800");window->resize(960,540);break;
        case 88:
            capture("incoming-call-inbox-960");shell.closeHomeMenu();
            HomeSocialFixture::publish(*shell.social(),{{"state","connected"},{"userId","profile-fixture"},{"notificationSound",false},{"chats",QVariantList{}}});
            shell.showAchievements("Adventure complete",{"First steps"});break;
        case 89: {
            auto* toast=itemNamed("passive-notification");auto* bell=itemNamed("footer-notification-bell");
            if(toast&&bell)check(toast->x()>500 && toast->mapRectToScene(toast->boundingRect()).bottom()<bell->mapRectToScene(bell->boundingRect()).top(),"Ordinary notification originates above lower bell");
            capture("notification-toast-960");shell.settings()->cycleTheme();break;
        }
        case 90:
            capture("notification-toast-alternate-theme-960");shell.settings()->cycleTheme();shell.dismissPassiveNotice();break;
        case 91: {
            shell.goToPage(1); // Hide the ordinary Home while probing the real widget QML.
            const auto receipt=homeWidgetPackage(widgetPackage->path());
            const auto base=widgetPackage->path()+"/objects/"+receipt["object"].toString()+"/assets/backgrounds/";
            QImage backdrop(8,8,QImage::Format_RGB32);backdrop.fill(QColor("#58786a"));
            for(const auto& name:{"cozy-room","sunny-garden","evening-nook"})backdrop.save(base+name+".png");
            shell.dashboard()->setInstalledWidgets(widgetPackage->path(),{receipt});
            check(shell.dashboard()->selectPackageWidget("home-companion"),QString("Installed package selects its contribution (owner=%1, choices=%2)")
                .arg(shell.trainer()->profile()["id"].toString(),QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(shell.dashboard()->widgetChoices())).toJson(QJsonDocument::Compact))));
            QQmlComponent component(qmlEngine(window));
            component.setData(R"QML(import QtQuick
import TrainerOS
Item {
    id: probe; objectName: "companion-integration-probe"
    required property var liveShell
    x: 30; y: 80; width: 269; height: 208; z: 200
    property QtObject proxy: QtObject {
        property var dashboard: probe.liveShell.dashboard
        property var trainer: ({avatarModel:"",avatarRendererAvailable:false,avatarBusy:false})
        property bool unobstructed: true
        property bool quickAppsOpen: false
        property bool drawerOpen: false
        property var keyboard: ({open:false})
        property var notifications: []
    }
    property bool presentationActive: true
    HomeWidgetSlot { anchors.fill:parent; shell:probe.proxy; selected:true;presentationActive:probe.presentationActive }
})QML",QUrl("qrc:/TrainerOS/CompanionIntegrationProbe.qml"));
            auto* probe=qobject_cast<QQuickItem*>(component.createWithInitialProperties({{"liveShell",QVariant::fromValue(&shell)}}));
            check(probe,component.errorString());
            if(probe){
                probe->setParent(window);probe->setParentItem(window->contentItem());
                // This offscreen fixture controls focus; real application focus
                // remains a separate handheld acceptance condition.
                if(auto* shutter=probe->findChild<QObject*>("home-widget-shutter"))shutter->setProperty("windowRenderable",true);
            }
            break;
        }
        case 92: {
            auto* widget=itemNamed("home-companion");
            check(widget && shell.dashboard()->companion()->active(),"Real widget loader activates care without a binding loop");
            if(widget)check(QMetaObject::invokeMethod(widget,"use",Q_ARG(QVariant,QVariant(0))),"QML touch action invokes shared Home focus and Feed");
            check(shell.dashboard()->companion()->activity()=="feed","Feed actually reaches the controller");
            shell.dashboard()->setInstalledWidgets({},{});break;
        }
        case 93: {
            check(!itemNamed("home-companion") && !shell.dashboard()->companion()->active(),"Package removal unloads the renderer and stops care");
            const auto restoredReceipt=homeWidgetPackage(widgetPackage->path());
            // Restore valid image assets before republishing the installed receipt.
            {const auto base=widgetPackage->path()+"/objects/home-companion-"+QString(64,'a')+"/assets/backgrounds/";
             QImage backdrop(8,8,QImage::Format_RGB32);backdrop.fill(QColor("#58786a"));
             for(const auto& name:{"cozy-room","sunny-garden","evening-nook"})backdrop.save(base+name+".png");}
            shell.dashboard()->setInstalledWidgets(widgetPackage->path(),{restoredReceipt});
            check(shell.dashboard()->selectPackageWidget("home-companion"),"Crates selection works after a rendered widget");break;
        }
        case 94:
            check(!shell.dashboard()->widgetPicking() && shell.dashboard()->widget()["id"]=="crates:home-companion:pet",
                  "QML lifecycle cannot reopen picker or discard package selection");
            check(shell.dashboard()->companion()->active(),"Replacement renderer reactivates care");
            if(auto* probe=itemNamed("companion-integration-probe"))probe->setProperty("presentationActive",false);break;
        case 95:
            check(!shell.dashboard()->companion()->active()&&!itemNamed("home-companion"),"Inactive Home presentation destroys the whole widget and stops care");
            if(auto* probe=itemNamed("companion-integration-probe"))probe->setProperty("presentationActive",true);break;
        case 96:
            check(shell.dashboard()->companion()->active()&&itemNamed("home-companion"),"Home return creates one selected companion");
            check(!shell.dashboard()->allowsStartWidgets("home-companion"),"Home contribution cannot be registered in Start");
            window->hide();break;
        case 97:
            check(!shell.dashboard()->companion()->active(),"Hidden window stops companion even with a renderable fixture shutter");
            window->show();window->requestActivate();break;
        case 98:
            check(shell.dashboard()->companion()->active(),"Showing window resumes the selected companion");
            if(auto* probe=itemNamed("companion-integration-probe"))probe->deleteLater();
            shell.dashboard()->setInstalledWidgets({},{});shell.goToPage(0);break;
        default:
            check(warnings == 0, "QML warnings"); completed = true; timer->stop();
            if (!screenshotDir.isEmpty()) {
                QFile report(screenshotDir + "/home-check.txt");
                if (report.open(QIODevice::WriteOnly))
                    report.write((diagnostics.join('\n')+QString("\nqmlWarnings=%1\n").arg(warnings)).toUtf8());
            }
            if (*failed) { qCritical().noquote() << diagnostics.join('\n'); QCoreApplication::exit(1); }
            else window->close();
        }
    });
    timer->start();
}
