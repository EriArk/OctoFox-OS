import QtQuick
import QtQuick.Window

Window {
    id: panel
    required property var account
    property string labName: ""
    readonly property var review: account.marketReview
    readonly property var items: review.items || []
    readonly property var choices: {
        let rows = [review.inventory ? "Back to counter" : "Cancel"]
        if (review.picker && !review.loading) {
            for (let item of items) rows.push(item.title)
            if (review.next) rows.push("More items")
        } else if (review.ready) rows.push(review.retry ? "Resolve purchase" : "Confirm")
        return rows
    }
    property int selected: 0
    title: "TrainerOS · Bazaar checkout"
    width: Math.min(560,Screen.width); height: Math.min(370,Screen.height)
    x: (Screen.width-width)/2; y: (Screen.height-height)/2
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint
    modality: Qt.ApplicationModal
    color: "#14282a"
    visible: Object.keys(review).length > 0
    onVisibleChanged: if(visible){ selected=0;raise();requestActivate() }
    onChoicesChanged: selected=0
    onClosing: function(event){event.accepted=false;account.answerMarketReview(false)}
    function activate(i) {
        if(i===0)account.answerMarketReview(false)
        else if(review.ready)account.answerMarketReview(true)
        else if(i<=items.length)account.chooseMarketItem(i-1)
        else account.moreMarketItems()
    }
    Connections {
        target: panel.account
        function onMarketControl(action) {
            if(!panel.visible || !panel.active)return
            if(action==="back")panel.activate(0)
            else if(action==="confirm")panel.activate(panel.selected)
            else panel.selected=Math.max(0,Math.min(panel.choices.length-1,panel.selected+(action==="up"?-1:1)))
        }
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 536
        height: Math.min(352, layout.implicitHeight+40)
        scale: Math.min(2.55, (panel.width-20)/width, (panel.height-20)/height)
        radius: 14; color: "#f7ead1"; border.color: "#c4a16c"; border.width: 2
        Column {
            id: layout
            x: 22; y: 20; width: parent.width-44; spacing: 10
            Text { text: panel.labName ? "TRAINEROS   /   "+panel.labName.toUpperCase()+"   /   TEST SPARKS" : "TRAINEROS   /   BAZAAR"
                color:"#645039";font.bold:true;font.pixelSize:14 }
            Text { width:parent.width;text:panel.review.text || "";color:"#2c3530";textFormat:Text.PlainText;wrapMode:Text.Wrap;font.pixelSize:21 }
            Text { visible:!!panel.review.picker && !panel.review.loading && !panel.items.length;text:"No available items on this page.";color:"#4a5952" }
            ListView {
                width:parent.width;height:Math.min(185,panel.choices.length*43)
                clip:true;spacing:4;model:panel.choices;currentIndex:panel.selected
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width:ListView.view.width;height:39;radius:6;color:index===panel.selected?"#315a50":"#e5d4b4"
                    Text {anchors.centerIn:parent;width:parent.width-22;text:parent.modelData;textFormat:Text.PlainText;elide:Text.ElideRight
                        color:parent.index===panel.selected?"#fff4d9":"#343c35";font.pixelSize:18}
                    MouseArea {anchors.fill:parent;onClicked:panel.activate(parent.index)}
                }
            }
        }
    }
}
