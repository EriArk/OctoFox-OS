import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var shell
    required property var flow
    required property var session
    readonly property bool achievements: flow.service === "achievements"
    readonly property bool social: flow.service === "social"
    readonly property bool scraper: flow.service === "scraper"
    readonly property bool takesFocus: visible && !shell.keyboard.open
    readonly property var account: shell.hall.account
    readonly property string serviceName: social ? "TrainerOS · Fluxer" : achievements ? "RetroAchievements" : "ScreenScraper"
    readonly property string registrationUrl: social ? "https://fluxer.com/login" : achievements ? "https://retroachievements.org/createaccount.php" : "https://www.screenscraper.fr/membreinscription.php"
    readonly property string explanation: social
        ? "Fluxer connects friends, chats and invitations. Sign in to TrainerOS with the same Fluxer account for your online profile, level and Sparks. Both can wait until later."
        : achievements ? "Sign in to earn and sync achievements in supported games. Without an account, you can still play your local games."
        : "Sign in to download covers and game information. Without an account, imported games and any artwork you already have stay available."
    Rectangle { anchors.fill: parent; radius: 12; color: Theme.paper }
    Item {
        anchors.fill: parent; anchors.margins: 20; visible: !root.flow.registration
        Text { id: title; width: parent.width-registerButton.width-16; text: root.serviceName; wrapMode: Text.WordWrap; font.family: Theme.displayFamily; font.pixelSize: 26; color: Theme.ink }
        SettingsRow {
            id: registerButton; objectName: "setup-registration"; anchors.right: parent.right; width: Math.min(260,parent.width*0.40); height: 52
            title: "Register on your phone"; detail: "Show QR code"; selected: root.takesFocus && root.session.registrationFocused
            onActivated: root.flow.showRegistration()
        }
        Text { id: explanation; y: Math.max(title.height,registerButton.height)+10; width: parent.width; text: root.explanation; color: Theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
        ListView {
            id: list; y: explanation.y+explanation.height+12; width: parent.width; height: parent.height-y-42; clip: true; spacing: 2; keyNavigationEnabled: false
            model: root.social ? root.session.setupAccountRows : root.scraper ? root.shell.scraper.settingsRows : root.achievements && root.account.available ? root.account.rows : []
            currentIndex: root.social ? root.session.setupAccountFocus : root.scraper ? root.shell.scraper.settingsFocus : root.account.focusIndex
            function reveal() { if(count)positionViewAtIndex(currentIndex,ListView.Contain) }
            onCurrentIndexChanged: Qt.callLater(reveal)
            onCountChanged: Qt.callLater(reveal)
            onHeightChanged: Qt.callLater(reveal)
            ScrollBar.vertical: SettingsScrollBar {}
            delegate: SettingsRow {
                required property int index
                required property var modelData
                objectName: "setup-service-row-"+index
                width: list.width-8; height: Math.max(54,implicitHeight); title: modelData.label; detail: modelData.detail
                kind: modelData.enabled?"action":"status"
                selected: root.takesFocus && !root.session.registrationFocused && index===list.currentIndex
                onActivated: root.session.activateSetupService(index)
            }
        }
        Text {
            anchors.bottom: parent.bottom; width: parent.width; height: 32; font.pixelSize: 12; color: Theme.muted; wrapMode: Text.WordWrap; textFormat: Text.PlainText
            text: root.social ? "Use ↑ above the first row for phone registration. Back returns to accounts."
                : root.scraper ? root.shell.scraper.status || "Account settings can be changed later in Settings."
                : root.account.available ? root.account.status : "Account access is unavailable in this build. You can continue setup offline."
        }
    }
    Item {
        anchors.fill: parent; anchors.margins: 22; visible: root.flow.registration
        Text { id: qrTitle; width: parent.width; text: "Register on your phone"; font.family: Theme.displayFamily; font.pixelSize: 26; color: Theme.ink }
        Image {
            id: qr; objectName: "setup-registration-qr"; x: 0; y: qrTitle.height+18
            width: Math.min(248,parent.width*0.40,parent.height-y); height: width
            source: root.flow.registration ? "qrc:/setup-qr/"+root.flow.service+".png" : ""
            fillMode: Image.PreserveAspectFit; smooth: false; mipmap: false
            Accessible.name: "QR code for "+root.registrationUrl
        }
        Column {
            x: qr.width+26; y: qr.y; width: parent.width-x; spacing: 16
            Text { width: parent.width; text: root.serviceName; font.pixelSize: 22; color: Theme.ink; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: "Scan with your phone camera and create your account on the official website. Then return here and sign in."; font.pixelSize: 15; color: Theme.muted; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: root.registrationUrl; textFormat: Text.PlainText; font.pixelSize: 13; color: Theme.ink; wrapMode: Text.WrapAnywhere }
            SettingsRow { objectName: "setup-registration-done"; width: parent.width; title: "Back to sign-in"; selected: root.takesFocus; onActivated: root.session.backInSetup() }
        }
    }
}
