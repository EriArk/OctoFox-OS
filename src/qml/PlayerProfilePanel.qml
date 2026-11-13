import QtQuick
import QtQuick.Controls

Panel {
    id: root
    objectName: "player-profile"
    required property var shell
    readonly property var profile: shell.trainer
    readonly property var record: shell.playerProfile || ({})
    readonly property var account: shell.profileAccount
    readonly property var badges: record.badges || []
    readonly property var latest: record.latestSession || ({})
    readonly property bool browsing: !profile.editing && shell.profileRoute === "summary"
    readonly property bool compact: height < 560
    readonly property color accent: Theme.dark ? "#b9cfa5" : "#527b59"
    patterned: false
    radius: 28
    MouseArea { anchors.fill: parent }

    component ProfileAction: Item {
        id: action
        required property int actionIndex
        required property string label
        property string glyph: ""
        property color background: "transparent"
        property bool available: true
        property int textSize: 12
        property color ink: root.accent
        readonly property bool focused: root.shell.profileContentActive && root.shell.profileFocus === actionIndex
        height: 30
        opacity: available ? 1 : .5
        Rectangle { anchors.fill: parent; radius: action.glyph ? width/2 : 5; color: action.focused ? Theme.selection : pointer.containsMouse ? Theme.surface : action.background; border.width: action.focused ? 2 : 0; border.color: Theme.focus }
        Text { visible: !action.glyph; anchors.fill: parent; anchors.margins: 5; text: action.label; textFormat: Text.PlainText; color: action.focused || pointer.containsMouse ? root.accent : action.ink; font.pixelSize: action.textSize; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
        MenuGlyph { visible: !!action.glyph; anchors.centerIn: parent; width: 28; height: 28; glyph: action.glyph; ink: action.focused || pointer.containsMouse ? root.accent : action.ink }
        ToolTip.visible: !!glyph && available && root.shell.profileContentActive && (focused || pointer.containsMouse)
        ToolTip.text: label
        ToolTip.delay: 650
        MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; enabled: action.available && root.shell.profileContentActive; onClicked: root.shell.activate(action.actionIndex,"profile") }
        Accessible.role: Accessible.Button; Accessible.name: label; Accessible.onPressAction: if(available)root.shell.activate(actionIndex,"profile")
    }
    Item {
        anchors.fill: parent; anchors.margins: 18; visible: !root.profile.editing
        Item {
            id: heading; width: parent.width; height: 34; visible: !root.browsing
            Text { text: "\u2039  Back"; font.family: Theme.brandFamily; font.pixelSize: 17; color: Theme.ink
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.shell.pressButton("B") }
            }
            SocialIconButton { id: close; anchors.right: parent.right; y: -6; icon: "x"; label: "Back"; onClicked: root.shell.pressButton("B") }
            Rectangle { y: 30; width: parent.width; height: 1; color: Theme.divider }
        }
        Item {
            id: showcase; y: 0; width: parent.width; height: parent.height; visible: root.browsing
            ProfileScene {
                id:portrait;width:parent.width*.35;height:parent.height
                profile:root.profile;appearance:root.shell.backendAccount.profileAppearance;showAvatar:root.browsing
                Rectangle { x:10;y:10;width:116;height:30;radius:15;color:"#c5122229" }
                ProfileAction { x:16;y:10;width:108;actionIndex:9;label:"Change scenery  ›";textSize:11;ink:"#fff0cd" }
                ProfileAction {
                    objectName: "profile-wardrobe"
                    anchors.right: parent.right; anchors.rightMargin: 10; y: 10
                    width: 56; height: 56; actionIndex: 1; label: "Wardrobe"; glyph: "shirt"
                    ink: "#ffe2a1"; background: "#e6122229"
                    available: root.profile.exists && root.profile.avatarAvailable
                }
            }
            Item {
                id:identity;x:portrait.width+22;width:parent.width-x;height:root.compact?52:68
                Text { objectName:"profile-name";y:-4;width:parent.width-profileTools.width-10;text:root.account.name;textFormat:Text.PlainText;font.family:Theme.displayFamily;font.pixelSize:root.compact?35:44;minimumPixelSize:23;fontSizeMode:Text.HorizontalFit;elide:Text.ElideRight;color:Theme.ink }

                Text { anchors.bottom:parent.bottom;anchors.bottomMargin:3;width:parent.width;text:root.profile.profile.joined?"PLAYER SINCE "+root.profile.profile.joined.toUpperCase():"EVERY ADVENTURE LEAVES A MARK";font.family:Theme.brandFamily;font.pixelSize:9;font.letterSpacing:1.6;color:root.accent;elide:Text.ElideRight }
            }
            Row {
                id:profileTools;anchors.right:parent.right;spacing:4;z:2
                SocialIconButton { objectName:"profile-edit";glyph:"pencil";label:root.profile.exists?"Edit profile":"Create profile";highlighted:root.shell.profileContentActive&&root.shell.profileFocus===0;enabled:root.shell.profileContentActive;onClicked:root.shell.activate(0,"profile") }
                SocialIconButton { objectName:"profile-sharing";glyph:"privacy";label:"Profile privacy";highlighted:root.shell.profileContentActive&&root.shell.profileFocus===13;enabled:root.shell.profileContentActive;onClicked:root.shell.activate(13,"profile") }
                SocialIconButton { objectName:"profile-close";glyph:"close";label:"Close profile";onClicked:root.shell.pressButton("B") }
            }
            Flickable {
                id: factsScroll; x: identity.x; y:identity.height+8; width: parent.width-x; height: parent.height-y
                contentWidth: width; contentHeight: body.implicitHeight; clip: true
                boundsBehavior: Flickable.StopAtBounds
                function revealFocus() {
                    if (!root.browsing || !root.shell.profileContentActive) return
                    const focus = root.shell.profileFocus
                    const section = focus === 4 ? economy : focus === 10 ? supportEntry : focus === 11 ? trophyShelf : focus === 3 || (focus >= 7 && focus <= 8) ? awards : focus === 2 || focus === 5 || focus === 6 ? journey : null
                    if (!section) { contentY = 0; return }
                    const top = section.mapToItem(body, 0, 0).y
                    if (top < contentY) contentY = top
                    else if (top+section.height > contentY+height) contentY = Math.max(0, top+section.height-height)
                }
                property int observedFocus: -1
                property string observedRoute: ""
                Connections {
                    target: root.shell
                    function onChanged() {
                        if (factsScroll.observedFocus === root.shell.profileFocus && factsScroll.observedRoute === root.shell.profileRoute) return
                        factsScroll.observedFocus = root.shell.profileFocus
                        factsScroll.observedRoute = root.shell.profileRoute
                        factsScroll.revealFocus()
                    }
                }
                Column {
                    id: body; width: factsScroll.width; spacing: root.compact?8:12
                    Item {
                        id:economy;width:parent.width;height:root.compact?86:100
                        readonly property real split:width*.61
                        Item {
                            id:levelSeal;width:66;height:74
                            Canvas {
                                anchors.fill:parent
                                property color gold:Theme.dark?"#edcd83":"#9f7036"
                                property color fill:Theme.dark?"#172a30":"#eff0df"
                                onGoldChanged:requestPaint()
                                onFillChanged:requestPaint()
                                onPaint:{const c=getContext("2d");c.reset();const w=width,h=height;c.beginPath();c.moveTo(w*.5,2);c.lineTo(w-4,16);c.lineTo(w-7,h*.73);c.lineTo(w*.5,h-3);c.lineTo(7,h*.73);c.lineTo(4,16);c.closePath();c.fillStyle=fill;c.fill();c.strokeStyle=gold;c.lineWidth=1.5;c.stroke();c.beginPath();c.moveTo(12,22);c.lineTo(w*.5,12);c.lineTo(w-12,22);c.stroke();}
                            }
                            Text { anchors.horizontalCenter:parent.horizontalCenter;y:19;width:parent.width-16;text:root.account.levelText;font.family:Theme.gameFamily;font.pixelSize:29;minimumPixelSize:17;fontSizeMode:Text.HorizontalFit;horizontalAlignment:Text.AlignHCenter;color:Theme.ink }
                            Text { anchors.horizontalCenter:parent.horizontalCenter;y:54;text:"LEVEL";font.family:Theme.brandFamily;font.pixelSize:8;font.letterSpacing:1.6;color:root.accent }
                        }
                        Column {
                            x:78;y:5;width:economy.split-x-17;spacing:7
                            Text { text:"Trainer mastery";font.family:Theme.displayFamily;font.pixelSize:16;color:Theme.ink }
                            Text { width:parent.width;text:root.account.levelKnown?Math.max(0,root.account.nextLevelXp-root.account.levelXp)+" XP to next level":root.account.signedIn?"Progress unavailable":"Sign in to start";font.pixelSize:11;color:root.accent;elide:Text.ElideRight }
                            Rectangle {
                                objectName:"profile-xp-track";width:parent.width;height:7;radius:3.5;color:Theme.divider;visible:root.account.levelKnown
                                Rectangle { width:parent.width*Math.max(0,Math.min(1,(root.account.levelXp||0)/(root.account.nextLevelXp||1)));height:parent.height;radius:3.5;color:root.accent }
                                Repeater { model:4;Rectangle { required property int index;x:parent.width*(index+1)/5;width:2;height:parent.height;color:Theme.paper } }
                            }
                            Text { width:parent.width;text:root.account.levelKnown?root.account.levelXp+" / "+root.account.nextLevelXp+" XP"+(root.account.stale?" · offline":""):"Verified account progress";font.pixelSize:9;color:Theme.muted;elide:Text.ElideRight }
                        }
                        Rectangle { x:economy.split;y:7;height:parent.height-16;width:1;color:Theme.divider }
                        Item {
                            x:economy.split+15;width:parent.width-x;height:parent.height
                            SparkIcon { id:rewardSpark;width:29;height:29;y:4 }
                            Text { x:36;y:0;width:parent.width-x;text:root.account.sparksText;font.family:Theme.displayFamily;font.pixelSize:28;minimumPixelSize:18;fontSizeMode:Text.HorizontalFit;elide:Text.ElideRight;color:Theme.ink }
                            Text { x:36;y:30;text:"SPARKS";font.family:Theme.brandFamily;font.pixelSize:9;font.letterSpacing:1.4;color:root.accent }
                            Text { y:46;width:parent.width;text:rewardFade.running?rewardFlash.text:root.account.stale?"Saved balance · offline":root.account.balanceKnown?"For your next unlock":"Balance unavailable";font.pixelSize:9;color:rewardFade.running?root.accent:Theme.muted;elide:Text.ElideRight }
                            QtObject { id:rewardFlash;property string text:"" }
                            SequentialAnimation { id:rewardFade;NumberAnimation {target:rewardSpark;property:"scale";to:1.3;duration:180} NumberAnimation {target:rewardSpark;property:"scale";to:1;duration:250} PauseAnimation {duration:2500} }
                            Connections { target:root.shell.backendAccount;function onRewardsEarned(xp,sparks){rewardFlash.text=(xp>0?"+"+xp+" XP · ":"")+"+"+sparks+" Sparks";rewardFade.restart()} }
                            ProfileAction { objectName:"profile-account";y:60;width:parent.width;actionIndex:4;label:"Account & rewards  ›";textSize:10 }
                        }
                    }
                    Item {
                        id:trophyShelf;width:parent.width;height:root.compact?112:134
                        readonly property var trophies:root.shell.backendAccount.prizes.shelf||[]
                        Text { text:"Trophy shelf";font.family:Theme.displayFamily;font.pixelSize:18;color:Theme.ink }
                        ProfileAction { anchors.right:parent.right;y:-3;width:135;actionIndex:11;label:(root.shell.backendAccount.prizes.pending||0)>0?"Rewards ("+root.shell.backendAccount.prizes.pending+")  ›":"Hall of fame  ›";textSize:11 }
                        Row {
                            y:29;width:parent.width;spacing:8
                            Repeater { model:5;delegate:Item {
                                id:trophySlot;required property int index
                                readonly property var trophy:trophyShelf.trophies[index]||({})
                                width:(trophyShelf.width-32)/5;height:root.compact?62:78
                                Rectangle { anchors.fill:parent;radius:8;color:Qt.alpha(root.accent,.045);border.color:Qt.alpha(root.accent,.16);border.width:1 }
                                Rectangle { x:7;y:parent.height-5;width:parent.width-14;height:2;radius:1;color:Qt.alpha(root.accent,.32) }
                                PrizeEmblem { anchors.horizontalCenter:parent.horizontalCenter;y:0;width:root.compact?44:58;height:width;visible:!!trophySlot.trophy.game_id;kind:trophySlot.trophy.completed?"completed":"beaten" }
                                MenuGlyph { anchors.horizontalCenter:parent.horizontalCenter;y:8;width:25;height:25;glyph:"trophy";ink:Qt.alpha(root.accent,.32);visible:!trophySlot.trophy.game_id }
                                Text { y:parent.height-20;width:parent.width-8;x:4;text:trophySlot.trophy.title||("0"+(index+1));textFormat:Text.PlainText;color:trophySlot.trophy.game_id?Theme.ink:Theme.muted;font.pixelSize:9;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter }
                                MouseArea { anchors.fill:parent;enabled:root.shell.profileContentActive;onClicked:root.shell.activate(11,"profile") }
                                Accessible.role:Accessible.Button;Accessible.name:trophySlot.trophy.title||"Choose a trophy for slot "+(index+1);Accessible.onPressAction:root.shell.activate(11,"profile")
                            } }
                        }
                        Text { anchors.bottom:parent.bottom;width:parent.width;text:trophyShelf.trophies.length?"Your victories. Your collection.":"Finish games. Collect trophies. Tell your story.";font.pixelSize:9;color:Theme.muted;elide:Text.ElideRight }
                    }
                    Item {
                        id:journal;width:parent.width;height:root.compact?136:142
                        Rectangle { width:parent.width;height:1;color:Theme.divider }
                        Item {
                            id:awards;y:9;width:parent.width*.50-10;height:parent.height-y
                            Text { text:"Recent achievements";font.family:Theme.displayFamily;font.pixelSize:15;color:Theme.ink }
                            Column {
                                y:26;width:parent.width;spacing:4
                                Repeater { model:root.badges;delegate:Item {
                                    required property var modelData;required property int index
                                    width:awards.width;height:29
                                    Rectangle { anchors.fill:parent;radius:5;color:root.shell.profileFocus===index+7?Theme.selection:"transparent";border.width:root.shell.profileFocus===index+7?2:0;border.color:Theme.focus }
                                    Image { id:badge;x:0;y:0;width:28;height:28;source:modelData.icon||"";sourceSize:Qt.size(64,64);asynchronous:true;fillMode:Image.PreserveAspectFit }
                                    Text { x:3;visible:badge.status!==Image.Ready;text:"✦";font.pixelSize:23;color:root.accent }
                                    Text { x:36;y:0;width:parent.width-x;text:modelData.title;textFormat:Text.PlainText;font.pixelSize:10;color:Theme.ink;elide:Text.ElideRight }
                                    Text { x:36;y:15;width:parent.width-x;text:modelData.date;font.pixelSize:8;color:Theme.muted;elide:Text.ElideRight }
                                    MouseArea { anchors.fill:parent;enabled:root.shell.profileContentActive;onClicked:root.shell.activate(index+7,"profile") }
                                } }
                            }
                            Text { y:29;width:parent.width;visible:!root.badges.length;text:root.record.achievementNote||"Your next challenge is waiting.";font.pixelSize:11;color:Theme.muted;wrapMode:Text.WordWrap;maximumLineCount:3;elide:Text.ElideRight }
                            ProfileAction { objectName:"profile-achievements";anchors.bottom:parent.bottom;width:parent.width;actionIndex:3;label:"RetroAchievements  ›";textSize:10 }
                        }
                        Rectangle { x:parent.width*.5;y:15;width:1;height:parent.height-20;color:Theme.divider }
                        Item {
                            id:journey;x:parent.width*.5+14;y:9;width:parent.width-x;height:parent.height-y
                            Text { text:"Last adventure";font.family:Theme.displayFamily;font.pixelSize:15;color:Theme.ink }
                            Item {
                                y:26;width:parent.width;height:45
                                Rectangle { anchors.fill:parent;radius:5;color:root.shell.profileFocus===6?Theme.selection:"transparent";border.width:root.shell.profileFocus===6?2:0;border.color:Theme.focus }
                                Image { id:lastPhoto;visible:!!root.latest.image;width:54;height:42;source:root.latest.image||"";asynchronous:true;fillMode:Image.PreserveAspectFit }
                                Text { x:lastPhoto.visible?62:0;width:parent.width-x;text:root.latest.game||"A new story awaits";textFormat:Text.PlainText;color:Theme.ink;font.pixelSize:11;elide:Text.ElideRight }
                                Text { x:lastPhoto.visible?62:0;y:18;width:parent.width-x;text:root.latest.game?root.latest.duration:"Start a game to begin";color:Theme.muted;font.pixelSize:10;elide:Text.ElideRight }
                                MouseArea { anchors.fill:parent;enabled:!!root.latest.game&&root.shell.profileContentActive;onClicked:root.shell.activate(6,"profile") }
                            }
                            Text { y:70;width:parent.width;text:(root.record.gamesPlayed??0)+" games  ·  "+(root.record.recordedTime||"—");font.pixelSize:9;color:Theme.muted;elide:Text.ElideRight }
                            ProfileAction { objectName:"profile-story";anchors.bottom:parent.bottom;width:parent.width-70;actionIndex:2;label:"Player journey  ›";textSize:10 }
                            ProfileAction { objectName:"profile-screens";anchors.right:parent.right;anchors.bottom:parent.bottom;width:70;actionIndex:5;label:"Screens  ›";textSize:10 }
                        }
                    }
                    ProfileAction { id:supportEntry;objectName:"profile-support";width:parent.width;height:26;actionIndex:10;label:"✦  Support OctoFox OS  ·  Sparks ×2 / ×3  ›";textSize:10 }
                }

            }
        }
        ProfileShop { x:0;y:42;width:parent.width;height:parent.height-y;shell:root.shell;visible:root.shell.profileRoute==="shop" }
        ProfilePrizes { x:0;y:42;width:parent.width;height:parent.height-y;shell:root.shell;visible:root.shell.profileRoute==="prizes" }
        ProfileSupport { x:0;y:42;width:parent.width;height:parent.height-y;shell:root.shell;visible:root.shell.profileRoute==="support" }
        GameHubOverview { x:0;y:42;width:parent.width;height:parent.height-y; shell:root.shell; visible:root.shell.profileRoute==="story" }
        AchievementGallery { x:0;y:42;width:parent.width;height:parent.height-y;shell:root.shell;visible:root.shell.profileRoute==="ra" }
        Item {
            id:rewardAccountPage
            x:24;y:58;width:parent.width-48;height:parent.height-y-28;visible:root.shell.profileRoute==="account"
            readonly property var progress:root.shell.backendAccount.progression
            readonly property var challenge:progress.challenge||({})
            Flickable {
                id:accountScroll
                width:parent.width*.48;height:parent.height;clip:true;contentHeight:accountColumn.height;boundsBehavior:Flickable.StopAtBounds
                function revealAction() {
                    if(root.shell.profileRoute!=="account" || root.shell.profileFocus>=4)return
                    var item=accountActions.itemAt(root.shell.profileFocus)
                    if(!item)return
                    var top=item.mapToItem(accountColumn,0,0).y
                    if(top<contentY)contentY=top
                    else if(top+item.height>contentY+height)contentY=Math.min(Math.max(0,contentHeight-height),top+item.height-height)
                }
                Connections { target:root.shell;function onChanged(){Qt.callLater(accountScroll.revealAction)} }
                onHeightChanged:Qt.callLater(revealAction)
                Column { id:accountColumn;width:parent.width;spacing:10
                    Text { text:"Account & rewards";font.family:Theme.displayFamily;font.pixelSize:25;color:Theme.ink }
                    Text { width:parent.width;text:root.shell.backendAccount.detail;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.pixelSize:12;color:Theme.muted }
                    Text { width:parent.width;text:root.shell.backendAccount.rewardStatus;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.pixelSize:12;color:Theme.muted }
                    Text { width:parent.width;text:"RA rewards use your Web API key on the OctoFox OS server to verify achievements. The key is not stored there. New achievements after linking earn rewards; old imported history does not.";wrapMode:Text.WordWrap;font.pixelSize:11;color:Theme.muted }
                    Text { width:parent.width;visible:!!rewardAccountPage.challenge.challenge;text:"Add this code as a separate word to your RA profile motto, save, then verify. You may remove it afterwards.\n"+(rewardAccountPage.challenge.challenge||"");textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.pixelSize:12;color:root.accent }
                    Repeater { id:accountActions;model:[root.shell.backendAccount.actionLabel,root.shell.backendAccount.rewardActionLabel,"RetroAchievements settings","Copy profile code"]
                        delegate: Item {
                            required property int index;required property string modelData
                            width:accountColumn.width;height:visible?34:0;visible:index!==3||!!rewardAccountPage.challenge.challenge
                            Rectangle { anchors.fill:parent;radius:4;color:root.shell.profileFocus===index?Theme.selection:"transparent";border.width:root.shell.profileFocus===index?1:0;border.color:Theme.focus }
                            Text { anchors.left:parent.left;anchors.leftMargin:8;anchors.verticalCenter:parent.verticalCenter;width:parent.width-16;text:modelData;font.pixelSize:12;color:Theme.ink;elide:Text.ElideRight }
                            MouseArea { anchors.fill:parent;onClicked:root.shell.activate(index,"profile") }
                        }
                    }
                    Text { width:parent.width;text:"Profile appearances and Patreon support are available from your character card.";wrapMode:Text.WordWrap;font.pixelSize:10;color:Theme.muted }
                }
            }
            Rectangle { x:parent.width*.51;width:1;height:parent.height;color:Theme.divider }
            Column { x:parent.width*.54;width:parent.width-x;height:parent.height;spacing:10
                Text { text:"Recent activity";font.pixelSize:17;color:Theme.ink }
                Text { text:root.account.balanceKnown?root.account.sparksText+" Sparks  ·  "+root.account.xp+" XP":"Sign in to view account progress";font.pixelSize:12;color:root.accent }
                ListView { id:rewardHistory;width:parent.width;height:parent.height-65;clip:true;spacing:6;model:root.shell.backendAccount.progression.history||[]
                    Connections { target:root.shell;function onChanged(){if(root.shell.profileRoute==="account" && root.shell.profileFocus>=4)rewardHistory.positionViewAtIndex(root.shell.profileFocus-4,ListView.Contain)} }
                    delegate: Item { required property var modelData;required property int index;width:ListView.view.width;height:55
                        Rectangle { anchors.fill:parent;radius:4;color:Theme.selection;visible:root.shell.profileFocus===index+4 }
                        Text { width:parent.width;text:modelData.title;textFormat:Text.PlainText;font.pixelSize:12;color:Theme.ink;elide:Text.ElideRight }
                        Text { y:19;width:parent.width;text:modelData.source==="bazaar.rent"?modelData.sparks+" Sparks · Weekly rent":modelData.source==="bazaar.rent_income"?"+"+modelData.sparks+" Sparks · Rental income":modelData.source==="support.topup"?"+"+modelData.sparks+" Sparks \u00b7 Support \u00d7"+modelData.support_multiplier:modelData.source==="operator.test_grant"?"+"+modelData.sparks+" Sparks · Test funding":modelData.source==="shop.purchase"?modelData.sparks+" Sparks \u00b7 Purchase":(modelData.source==="ra.completion"?"Complete set · ":"")+"+"+modelData.xp+" XP · +"+modelData.sparks+" Sparks";font.pixelSize:11;color:root.accent;elide:Text.ElideRight }
                        Text { y:35;text:new Date(modelData.earned_at).toLocaleDateString();font.pixelSize:10;color:Theme.muted }
                    }
                    Text { visible:parent.count===0;width:parent.width;text:"No earned rewards yet";font.pixelSize:12;color:Theme.muted }
                }
            }
        }
    }
    Item {
        anchors.fill: parent; visible: root.profile.editing && !root.profile.avatarEditing
        PageHeader { x: 24; y: 18; width: parent.width-90; title: "Edit your profile" }
        SocialIconButton { anchors.right: parent.right; anchors.rightMargin: 18; y: 18; icon: "x"; label: "Cancel editing"; onClicked: root.shell.pressButton("B") }
        TrainerEmblem { x: 30; y: 110; width: 145; height: width; emblem: root.profile.draftEmblem }
        Column {
            x: 205; y: 72; width: parent.width-x-30; spacing: 8
            Repeater {
                model: root.profile.editRows
                delegate: CapButton {
                    required property var modelData; required property int index
                    width: parent.width; height: 48; label: modelData.title; detail: modelData.detail || ""
                    selected: root.profile.focusIndex===index && !root.shell.menuOpen && !root.shell.keyboard.open
                    onActivated: root.shell.activate(index,"profile")
                }
            }
        }
    }
    Loader { x:18;y:60;width:parent.width-36;height:parent.height-78;active:(root.shell.profileRoute==="visitor"||root.shell.profileRoute==="privacy")&&!root.profile.editing;sourceComponent:Component { ProfileVisitor { shell:root.shell } } }
    Loader { x:18;y:60;width:parent.width-36;height:parent.height-78;active:root.shell.profileRoute==="outfits"&&!root.profile.editing;sourceComponent:Component { ProfileOutfits { shell:root.shell } } }
    Text { x: 28; anchors.bottom: parent.bottom; anchors.bottomMargin: 17; width: parent.width-140; text: root.profile.error; visible: text.length>0 && !root.profile.avatarEditing && root.shell.profileRoute!=="visitor" && root.shell.profileRoute!=="privacy"; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.textColor("#853b24") }
    Loader { anchors.fill: parent; active: root.profile.avatarEditing; sourceComponent: Component { AvatarEditor { profile: root.profile; shell: root.shell } } }
}
