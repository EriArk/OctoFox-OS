import QtQuick
import QtQuick.Window

Window {
    id: panel
    required property var account
    property string labName: ""
    readonly property var review: account.marketReview
    readonly property var items: review.items || []
    readonly property bool picker: !!review.picker && !review.loading
    readonly property bool festival: review.action === "festival"
    readonly property bool rental: review.action === "rent"
    readonly property bool structured: !!review.subject || (rental && !!review.keeper)
    readonly property int lastChoice: picker ? items.length + (review.next ? 1 : 0) : review.ready ? 1 : 0
    readonly property string viewKey: [review.text, review.loading, review.next, picker].join("/")
    property int selected: 0
    readonly property bool pricing: review.action === "list" && !!review.ready && !review.retry
    function stepPrice(delta) {
        priceField.text = String(Math.min(2147483647, Math.max(1,(Number(priceField.text) || 1)+delta)))
    }
    readonly property color gold: "#ffcf80"
    readonly property color ink: "#182a30"
    readonly property color paper: "#fff1d9"
    readonly property color secondary: "#bbd0ca"
    title: "TrainerOS · Festival market"
    width: Math.min(680, Screen.width)
    height: Math.min(392, Screen.height)
    x: (Screen.width-width)/2
    y: (Screen.height-height)/2
    flags: Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    modality: Qt.ApplicationModal
    color: "#122228"
    visible: Object.keys(review).length > 0
    onViewKeyChanged: Qt.callLater(resetSelection)
    function resetSelection() {
        selected = review.ready || (picker && items.length) ? 1 : 0
        if (review.action === "list" && review.ready && !review.retry) priceField.text=String(review.price)
    }
    onVisibleChanged: if (visible) { raise(); requestActivate() }
    onClosing: function(event) { event.accepted=false; account.answerMarketReview(false) }
    function activate(i) {
        if (i === 0) account.answerMarketReview(false)
        else if (pricing) {
            if (priceField.acceptableInput) account.confirmMarketListing(Number(priceField.text))
        } else if (review.ready) account.answerMarketReview(true)
        else if (picker && i <= items.length) account.chooseMarketItem(i-1)
        else if (picker && review.next) account.moreMarketItems()
    }
    Connections {
        target: panel.account
        function onMarketControl(action) {
            if (!panel.visible || !panel.active) return
            if (action === "back") panel.activate(0)
            else if (action === "confirm") panel.activate(panel.selected)
            else if (panel.pricing && (action === "left" || action === "right")) panel.stepPrice(action === "left" ? -1 : 1)
            else panel.selected = Math.max(0,Math.min(panel.lastChoice,panel.selected+(action === "up" || action === "left" ? -1 : 1)))
        }
    }

    component Caption: Text {
        color: panel.secondary
        font.pixelSize: 14
        font.letterSpacing: 1
        font.bold: true
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
    component PriceStep: Rectangle {
        required property string label
        required property int delta
        width: 40; height: 44
        color: "#345751"; border.color: "#68807b"
        Text { anchors.centerIn: parent; text: parent.label; color: panel.gold; font.pixelSize: 22 }
        MouseArea { anchors.fill: parent; onClicked: panel.stepPrice(parent.delta) }
    }
    component ActionTile: Rectangle {
        required property int choice
        required property string label
        width: Math.max(136, actionLabel.implicitWidth+32)
        height: 44
        color: panel.selected === choice ? "#345751" : "#22383c"
        border.color: panel.selected === choice ? panel.gold : "#44605f"
        border.width: panel.selected === choice ? 2 : 1
        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: parent.label
            textFormat: Text.PlainText
            color: panel.paper
            font.pixelSize: 17
            font.bold: true
        }
        MouseArea { anchors.fill: parent; onClicked: panel.activate(parent.choice) }
    }
    Item {
        width: 640
        height: 360
        anchors.centerIn: parent
        scale: Math.min((panel.width-16)/width,(panel.height-16)/height)
        Rectangle { width: parent.width; height: 4; color: "#e6ad66" }
        Caption {
            x: 18; y: 16; width: 440
            text: panel.festival ? "FESTIVAL PARK    /    TICKETS" : panel.review.slot ? "FESTIVAL PARK    /    COUNTER " + String(panel.review.slot).padStart(2,"0") : "FESTIVAL PARK    /    INVENTORY"
        }
        Caption {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 16
            color: panel.gold
            text: panel.labName ? panel.labName.toUpperCase()+"   ·   TEST SPARKS" : "TRAINEROS"
        }
        Text {
            x: 18; y: 46; width: 604; color: panel.paper; font.pixelSize: 32; font.bold: true
            text: panel.review.retry ? "Recover trade" : panel.review.inventory ? "Profile inventory" :
                  panel.festival ? "Festival ticket" : panel.rental ? "Rent a counter" : panel.review.action === "list" ?
                  (panel.review.picker ? "Choose your stock" : "List an item") : "Buy from counter"
        }
        Rectangle {
            x: 16; y: 100; width: 608; height: 186
            color: panel.ink
            border.color: "#3c5558"
            visible: !panel.picker
            Image {
                id: illustration
                x: 12; y: 48; width: 90; height: 92
                source: panel.review.art || ""
                visible: !!source.toString()
                fillMode: Image.PreserveAspectFit
            }
            Column {
                x: illustration.visible ? 110 : 18
                y: 20
                width: (panel.review.ready && panel.structured ? 324 : 584)-x
                spacing: 8
                Caption { width: parent.width; text: panel.review.inventory ? "ITEM" : panel.rental ? "RENTAL" : panel.review.action === "list" ? "ON THE COUNTER" : "YOU RECEIVE" }
                Text {
                    width: parent.width; height: 72; verticalAlignment: Text.AlignVCenter
                    color: panel.paper; font.bold: true; font.pixelSize: panel.structured ? 26 : 19
                    textFormat: Text.PlainText; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                    text: panel.review.loading || (!panel.review.ready && !panel.review.inventory) ? panel.review.text || "" :
                          panel.structured ? (panel.rental ? panel.review.keeper + " · 7 days" : panel.review.subject) : panel.review.text || ""
                }
                Text {
                    width: parent.width; color: panel.secondary; font.pixelSize: 16; textFormat: Text.PlainText
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    text: panel.review.origin || (panel.rental && panel.review.keeper ? "Staffed festival counter" : "")
                }
                Caption { visible: !!panel.review.state; text: String(panel.review.state || "").toUpperCase() }
            }
            Rectangle {
                x: 336; y: 16; width: 1; height: 154; color: "#4f6865"
                visible: !!panel.review.ready && panel.structured
            }
            Column {
                x: 352; y: 20; width: 248; spacing: 7
                visible: !!panel.review.ready && panel.structured
                Caption { text: panel.review.action === "list" ? "ASKING PRICE" : "YOU PAY" }
                Row {
                    visible: panel.pricing
                    spacing: 4
                    PriceStep { label: "−"; delta: -1 }
                    Rectangle {
                        width: 130; height: 44; color: "#102125"; border.color: "#68807b"
                        TextInput {
                            id: priceField
                            anchors.fill: parent
                            horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true; inputMethodHints: Qt.ImhDigitsOnly
                            text: "25"; color: panel.gold; font.bold: true; font.pixelSize: 18
                            validator: IntValidator { bottom: 1; top: 2147483647 }
                        }
                    }
                    PriceStep { label: "+"; delta: 1 }
                }
                Text {
                    visible: !panel.pricing; width: parent.width; color: panel.gold; font.bold: true; font.pixelSize: 26; wrapMode: Text.Wrap
                    text: "✦ " + Number((panel.review.price || 0) + (panel.rental ? panel.review.seller_price || 0 : 0)).toLocaleString(Qt.locale(), "f", 0)
                }
                Caption { text: "SPARKS" }
                Text { visible: panel.rental; color: panel.secondary; font.pixelSize: 15
                    text: "Week  " + (panel.review.price || 0) + "    ·    Keeper  " + (panel.review.seller_price || 0) }
            }
        }
        ListView {
            id: stock
            x: 16; y: 100; width: 608; height: 186; clip: true; spacing: 4
            visible: panel.picker; model: panel.picker ? panel.items : []
            currentIndex: panel.selected > 0 && panel.selected <= count ? panel.selected-1 : -1
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: stock.width; height: 52
                color: ListView.isCurrentItem ? "#345751" : "#20353b"
                border.color: ListView.isCurrentItem ? panel.gold : "#415b5d"
                border.width: ListView.isCurrentItem ? 2 : 1
                Image { id: rowArt; x: 8; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40
                    source: parent.modelData.art || ""; fillMode: Image.PreserveAspectFit }
                Text { x: rowArt.source.toString() ? 58 : 14; anchors.verticalCenter: parent.verticalCenter; width: 335; text: parent.modelData.title || ""
                    textFormat: Text.PlainText; elide: Text.ElideRight; color: panel.paper; font.pixelSize: 18; font.bold: true }
                Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 220; horizontalAlignment: Text.AlignRight; text: parent.modelData.game || ""
                    textFormat: Text.PlainText; elide: Text.ElideRight; color: panel.secondary; font.pixelSize: 15 }
                MouseArea { anchors.fill: parent; onClicked: panel.activate(parent.index+1) }
            }
        }
        Text {
            x: 30; y: 150; visible: panel.picker && !panel.items.length
            text: "No available items on this page."; color: panel.secondary; font.pixelSize: 18
        }
        ActionTile { x: 16; y: 302; choice: 0; label: panel.review.ready ? "B   Cancel" : "B   Back to counter" }
        ActionTile {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 302
            enabled: !panel.pricing || priceField.acceptableInput
            opacity: enabled ? 1 : 0.5
            visible: !!panel.review.ready || (panel.picker && !!panel.review.next)
            choice: panel.review.ready ? 1 : panel.items.length+1
            label: !panel.review.ready ? "More items" : panel.review.retry ? "Recover trade" :
                   panel.festival ? "Buy ticket" : panel.rental ? "Confirm rental" : panel.review.action === "list" ? "List item" : "Confirm purchase"
        }
    }
}
