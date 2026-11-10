import QtQuick
import QtQuick.Shapes

Item {
    id: root
    clip: true
    required property var flow
    property bool active: false
    property bool mediaAllowed: active
    property bool foreground: active
    property bool takesFocus: false
    property bool typing: false
    property bool fullScreen: false
    property bool chrome: true
    property var page: null
    property string popup: ""
    readonly property bool listPopover: popup === "bookmarks" || popup === "history"
    readonly property bool currentBookmarked: page && flow.bookmarks.some(row => row.url === page.url.toString())
    property var popupRows: []
    property int popupIndex: 0
    property string error: ""
    property string question: ""
    property string questionTitle: ""
    property var answer: null
    property int siteFocus: 0
    property int siteId: 0
    readonly property bool siteDialog: !!flow.dialog.id
    readonly property bool sitePrompt: flow.dialog.kind==="prompt"
    function activateSite(index) {
        if(sitePrompt&&index===0)flow.editDialogText()
        else flow.answerDialog(flow.dialog.kind==="alert" || index===(sitePrompt?2:1))
    }
    property bool toolsFocused: false
    property int toolIndex: 0
    property bool pointerVisible: false
    property real pointerX: width/2
    property real pointerY: height/2
    property int dashboardFocus: -1
    readonly property bool startPage: !page || page.url.toString()==="about:blank"
    readonly property bool expanded: active && fullScreen
    readonly property var shortcuts: flow.bookmarks.length ? flow.bookmarks : [
        {title:"Wikipedia",url:"https://www.wikipedia.org/",symbol:"W",color:Theme.surfaceColor("#d9e4db")},
        {title:"itch.io",url:"https://itch.io/",symbol:"i",color:Theme.surfaceColor("#f1c4bd")},
        {title:"Internet Archive",url:"https://archive.org/",symbol:"A",color:Theme.surfaceColor("#cedce8")}]
    function reveal() {chrome=true}
    function scrolled(dy) {if(popup||toolsFocused||typing)return;chrome=dy<0}
    function navigate(url) {error="";popup="";toolsFocused=false;flow.openUrl(url);reveal()}
    function openPopup(kind,rows) {
        if(kind==="tabs"&&page)captureTab(flow.selected,page)
        popupRows=rows||[];popupIndex=0;popup=kind;reveal()
    }
    function ask(title,message,callback,labels) {dismiss();questionTitle=title;question=message;answer=callback;openPopup("permission",[{title:labels?labels[0]:"Deny"},{title:labels?labels[1]:"Allow"}])}
    function dismiss() {if(answer){const callback=answer;answer=null;callback(false)}popup=""}
    function captureTab(id,view){
        if(!view || view.width<=0 || view.height<=0)return
        // A tab tile needs a thumbnail, not a retained full-resolution GPU readback.
        view.grabToImage(function(result){
            if(!flow.tabs.some(tab => tab.id===id))return
            thumbs[id]=result;thumbs=Object.assign({},thumbs)
        },Qt.size(320,Math.max(1,Math.round(320*view.height/view.width))))
    }
    function forgetTab(id){delete thumbs[id];thumbs=Object.assign({},thumbs)}
    function queueFieldCheck(){fieldCheck.restart();recentInput.restart()}
    property var thumbs: ({})
    Timer {id:fieldCheck;interval:140;onTriggered:if((root.takesFocus||root.typing)&&!root.popup&&!root.siteDialog)root.flow.editPageField(root.page)}
    // Chromium's editable focus can change after a tap (scripts/iframes), while
    // QQuickItem activeFocus remains on the same render widget.
    Timer {id:recentInput;interval:2000}
    Timer { interval: root.typing || recentInput.running ? 120 : 750; repeat: true
        running: root.foreground && !!root.page && !root.popup && !root.siteDialog && (root.takesFocus || root.typing)
        onTriggered: {
            if(root.page && !root.popup && !root.siteDialog && (root.takesFocus || root.typing))
                root.flow.editPageField(root.page,false)
            else root.flow.stopPageInput()
        }
    }
    Timer {id:popupScrollGate;interval:110}
    function activateRow(index) {
        const rows=popup==="tabs"?flow.tabs:popup==="bookmarks"?flow.bookmarks:popup==="history"?flow.history:popupRows
        const row=rows[index];if(!row)return
        if(popup==="tabs")flow.select(row.id)
        else if(popup==="bookmarks"||popup==="history")navigate(row.url)
        else if(popup==="permission"){const callback=answer;answer=null;if(callback)callback(index===1)}
        else if(row.keyboard)flow.editPageField(root.page)
        else if(row.search)navigate("https://duckduckgo.com/?q="+encodeURIComponent(row.search))
        else if(page)page.triggerWebAction(row.action)
        popup=""
    }
    function command(id) {
        if(siteDialog)return
        if(id==="back"){if(popup){dismiss();return}if(page&&page.canGoBack)page.goBack();reveal()}
        else if(id==="forward"){if(page)page.goForward();reveal()}
        else if(id==="reload"){if(page){error="";page.loading?page.stop():page.reload()}reveal()}
        else if(id==="bookmarks")openPopup("bookmarks")
        else if(id==="history")openPopup("history")
        else if(id==="fullscreen"){fullScreen=!fullScreen;if(!fullScreen&&page&&page.isFullScreen)page.fullScreenCancelled();reveal()}
    }
    function movePointer(dx,dy) {
        toolsFocused=false;pointerVisible=true
        pointerX=Math.max(2,Math.min(width-4,pointerX+dx))
        pointerY=Math.max(2,Math.min(height-4,pointerY+dy))
        flow.pointerEvent(root,pointerX,pointerY,0)
    }
    function handle(action) {
        if(siteDialog) {
            if(action==="back"){flow.cancelDialog();return}
            const last=sitePrompt?2:flow.dialog.kind==="alert"?0:1
            if(action==="up"||action==="left")siteFocus=Math.max(0,siteFocus-1)
            if(action==="down"||action==="right")siteFocus=Math.min(last,siteFocus+1)
            if(action==="click")activateSite(siteFocus)
            return
        }
        if(action==="chrome"){chrome=!chrome;toolsFocused=chrome;toolIndex=0;return}
        if(popup) {
            if(action==="back"){dismiss();return}
            const count=popup==="tabs"?flow.tabs.length:popup==="bookmarks"?flow.bookmarks.length:popup==="history"?flow.history.length:popupRows.length
            if(action==="up"||action==="left")popupIndex=Math.max(-1,popupIndex-1)
            if(action==="down"||action==="right")popupIndex=Math.min(count-1,popupIndex+1)
            if(action==="click"){if(popupIndex===-1){if(popup==="tabs"){flow.newTab();dismiss()}else if(popup==="bookmarks"&&page)flow.toggleBookmark(page.url.toString(),page.title);else dismiss()}else activateRow(popupIndex)}
            if(action==="context"&&popup==="tabs"&&popupIndex>=0)flow.closeTab(flow.tabs[popupIndex].id)
            return
        }
        if(action==="back"){command("back");return}
        if(action==="scroll-up"||action==="scroll-down"){if(page)flow.wheel(root,pointerX,pointerY,0,action==="scroll-up"?90:-90);return}
        if(toolsFocused) {
            if(action==="left")toolIndex=Math.max(-2,toolIndex-1)
            if(action==="right")toolIndex=Math.min(5,toolIndex+1)
            if(action==="up"){if(toolIndex>=0)toolIndex=-2;else {toolsFocused=false;movePointer(0,0)}}
            if(action==="down"){if(toolIndex<0)toolIndex=0;else {toolsFocused=false;movePointer(0,0)}}
            if(action==="click"){if(toolIndex===-2)flow.requestAddress(page?page.url.toString():"");else if(toolIndex===-1)openPopup("tabs");else command(toolFlow.controls[toolIndex].id)}
            return
        }
        // Pointer clicks must hit the actual item under the cursor, including
        // the local start page and address bar, rather than a stale focus tile.
        if(pointerVisible && (action==="click"||action==="context")) {
            flow.pointerEvent(root,pointerX,pointerY,action==="context"?2:1)
            if(action==="click")queueFieldCheck()
            return
        }
        if(startPage) {
            if(action==="left")dashboardFocus=Math.max(-1,dashboardFocus-1)
            else if(action==="right")dashboardFocus=Math.min(root.shortcuts.length-1,dashboardFocus+1)
            else if(action==="down")dashboardFocus=Math.min(root.shortcuts.length-1,dashboardFocus<0?0:dashboardFocus+4)
            else if(action==="up")dashboardFocus=dashboardFocus<4?-1:dashboardFocus-4
            else if(action==="click"){if(dashboardFocus<0)flow.requestAddress("");else navigate(root.shortcuts[dashboardFocus].url)}
            if(dashboardFocus>=0)dashboardTiles.positionViewAtIndex(dashboardFocus,GridView.Contain)
            return
        }
        if(action==="click"||action==="context") {
            flow.pointerEvent(root,pointerX,pointerY,action==="context"?2:1);if(action==="click")queueFieldCheck();return
        }
        movePointer(action==="left"?-12:action==="right"?12:0,action==="up"?-12:action==="down"?12:0)
    }
    QtObject {
        id: toolFlow
        property var view: ({controls:root.chrome,area:root.toolsFocused?"controls":"",controlIndex:root.toolIndex})
        property var controls: [
            {id:"back",label:"Back",icon:"arrow-left"},{id:"forward",label:"Forward",icon:"arrow-right"},
            {id:"reload",label:root.page&&root.page.loading?"Stop":"Reload",source:"qrc:/browser-controls/"+(root.page&&root.page.loading?"x":"arrow-clockwise")+".svg"},
            {id:"bookmarks",label:"Bookmarks",source:"qrc:/browser-controls/bookmark-simple.svg"},
            {id:"history",label:"History",source:"qrc:/browser-controls/clock-counter-clockwise.svg"},
            {id:"fullscreen",label:root.fullScreen?"Restore size":"Full screen",source:"qrc:/browser-controls/"+(root.fullScreen?"arrows-in":"arrows-out")+".svg"}]
        function focus(area,index){root.toolsFocused=true;root.toolIndex=index}
        function command(id){root.command(id)}
    }
    property alias toolFlow: toolFlow
    onForegroundChanged: if(!foreground){flow.stopPageInput();pointerVisible=false}
    onPopupChanged: if(popup)flow.stopPageInput()
    onActiveChanged: if(!active){flow.cancelDialog();flow.stopPageInput();dismiss();pointerVisible=false}
    onTakesFocusChanged: if(!takesFocus){pointerVisible=false;if(!shellController.keyboard.open&&popup!=="permission")dismiss()}
    Connections {target:flow
        function onDialogChanged(){if(root.siteId!==flow.dialog.id){root.siteId=flow.dialog.id||0;root.siteFocus=0;if(root.siteId)root.dismiss()}}
        function onCommandRequested(command){if(root.active)root.handle(command)}
        function onNavigateRequested(url){if(root.page)root.page.url=url;else if(webLoader.item)webLoader.item.reconcile();root.reveal()}
        function onProfileChanging(){webLoader.active=false;root.page=null;root.thumbs=({});root.dismiss()}
        function onProfileChanged(){webLoader.active=!!flow.profile&&flow.available}
    }
    Connections {target:controllerInput
        function onPageScrolled(dx,dy){
            if(!root.takesFocus)return
            if(root.siteDialog){if(flow.picker.open)flow.picker.scroll(dy<0?1:-1);else siteBody.contentY=Math.max(0,Math.min(Math.max(0,siteBody.contentHeight-siteBody.height),siteBody.contentY-dy));return}
            if(root.popup){if(!popupScrollGate.running&&Math.abs(dy)>1){root.handle(dy<0?"down":"up");popupScrollGate.start()};return}
            if(root.page)root.flow.wheel(root,root.pointerX,root.pointerY,dx,dy)
        }
        function onPointerMoved(dx,dy){if(!root.takesFocus||root.popup||root.siteDialog)return;root.movePointer(dx,dy)}
    }
    Rectangle {anchors.fill:parent;color:Theme.paper}
    Item {
        anchors.fill:parent;z:7;visible:root.siteDialog&&!flow.picker.open
        Rectangle {anchors.fill:parent;color:Theme.surfaceColor("#65162723");MouseArea {anchors.fill:parent}}
        Panel {
            enabled: root.takesFocus
            anchors.centerIn:parent;width:Math.min(540,parent.width-36);height:Math.min(root.sitePrompt?310:250,parent.height-24);radius:14
            Text {x:20;y:17;width:parent.width-40;text:flow.dialog.kind==="leave"?"Leave this page?":"Website message";font.family:Theme.displayFamily;font.pixelSize:22;color:Theme.ink}
            Text {x:20;y:47;width:parent.width-40;text:flow.dialog.origin||"";textFormat:Text.PlainText;elide:Text.ElideMiddle;font.pixelSize:12;color:Theme.muted}
            Flickable {id:siteBody;x:20;y:72;width:parent.width-40;height:parent.height-(root.sitePrompt?186:130);contentHeight:siteMessage.height;clip:true;boundsBehavior:Flickable.StopAtBounds
                Text {id:siteMessage;width:parent.width;text:flow.dialog.message||"";textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.pixelSize:15;color:Theme.ink}
            }
            Rectangle {x:20;y:parent.height-105;width:parent.width-40;height:40;radius:6;visible:root.sitePrompt;color:Qt.alpha(Theme.chassis,.06);border.color:root.siteFocus===0?Theme.focusGlow:Theme.rim
                Text {x:10;anchors.verticalCenter:parent.verticalCenter;width:parent.width-65;text:flow.dialog.text||"Enter a response";textFormat:Text.PlainText;elide:Text.ElideRight;color:Theme.ink;font.pixelSize:14}
                Text {anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;text:"Edit";font.pixelSize:13;color:Theme.muted}
                MouseArea {anchors.fill:parent;onClicked:flow.editDialogText()}
            }
            Row {anchors.right:parent.right;anchors.rightMargin:20;anchors.bottom:parent.bottom;anchors.bottomMargin:17;spacing:12
                CapButton {width:110;height:35;label:"Cancel";tint:Theme.paper;visible:flow.dialog.kind!=="alert";selected:root.siteFocus===(root.sitePrompt?1:0);onActivated:flow.cancelDialog()}
                CapButton {width:110;height:35;label:flow.dialog.kind==="leave"?"Leave":"OK";tint:Theme.green;selected:root.siteFocus===(root.sitePrompt?2:flow.dialog.kind==="alert"?0:1);onActivated:flow.answerDialog(true)}
            }
        }
    }
    ChatFilePicker {anchors.fill:parent;z:8;picker:flow.picker;title:flow.dialog.kind==="folder"?"Upload a folder and its contents":"Choose files to upload";subtitle:(flow.dialog.origin||"")+(flow.dialog.types?" · "+flow.dialog.types:"")}
    Loader {
        id:webLoader;anchors.fill:parent
        anchors.topMargin: root.chrome&&!root.typing ? 50 : 0
        anchors.bottomMargin: root.chrome&&!root.typing ? 24 : 0
        active:!!flow.profile&&flow.available;source:"BrowserEngine.qml"
        onLoaded:{item.flow=root.flow;item.surface=root;item.reconcile()}
    }
    Rectangle {
        anchors.fill:parent;visible:root.startPage;color:Theme.paper
        // A quiet, themed start page; no network requests for suggested tiles.
        Repeater {model:3
            Rectangle {required property int index;width:parent.width*(.75+index*.24);height:width;radius:width/2;x:parent.width*.65-width/2;y:parent.height*.55-height/2;color:"transparent";border.width:1;border.color:Qt.alpha(Theme.chassis,.08)}
        }
        Column {anchors.centerIn:parent;spacing:16;width:Math.min(580,parent.width-40)
            Text {anchors.horizontalCenter:parent.horizontalCenter;text:"Your corner of the web";font.family:Theme.displayFamily;font.pixelSize:28;color:Theme.ink}
            Text {anchors.horizontalCenter:parent.horizontalCenter;text:"A quiet start. Choose where to go.";font.pixelSize:14;color:Theme.muted}
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;width:Math.min(440,parent.width);height:42;radius:21;color:Qt.alpha(Theme.chassis,.07);border.width:root.dashboardFocus<0?2:1;border.color:Qt.alpha(Theme.chassis,root.dashboardFocus<0?.5:.18)
                Text {anchors.centerIn:parent;text:"Search or enter an address";font.pixelSize:14;color:Theme.muted}
                MouseArea {anchors.fill:parent;onClicked:flow.requestAddress("")}
            }
            GridView {id:dashboardTiles;width:Math.min(4,root.shortcuts.length)*130;anchors.horizontalCenter:parent.horizontalCenter;height:Math.min(2,Math.ceil(root.shortcuts.length/4))*98;cellWidth:130;cellHeight:98;clip:true;model:root.shortcuts
                    delegate: Item {required property int index;required property var modelData;width:130;height:98
                        Rectangle {x:(parent.width-width)/2;y:4;width:62;height:62;radius:20;color:Qt.darker(modelData.color||[Theme.blue,Theme.green,Theme.pink,Theme.yellow][index%4],1.35)}
                        Rectangle {anchors.horizontalCenter:parent.horizontalCenter;width:62;height:62;radius:20;color:modelData.color||[Theme.blue,Theme.green,Theme.pink,Theme.yellow][index%4];border.width:root.dashboardFocus===index?2:1;border.color:root.dashboardFocus===index?Theme.chassis:Qt.alpha(Theme.ink,.15)
                            Rectangle {anchors.fill:parent;anchors.margins:2;radius:18;color:"transparent";border.color:Qt.alpha("white",.6)}
                            Text {anchors.centerIn:parent;text:modelData.symbol||modelData.title.slice(0,1).toUpperCase();font.family:Theme.displayFamily;font.pixelSize:29;color:Theme.ink}
                        }
                        Text {y:72;width:parent.width-8;x:4;text:modelData.title;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;color:Theme.ink;font.pixelSize:13;textFormat:Text.PlainText}
                        MouseArea {anchors.fill:parent;onClicked:root.navigate(modelData.url)}
                    }
            }
        }
        Text {anchors.centerIn:parent;visible:!flow.available;text:"This build has no embedded web engine.";color:Theme.ink}
    }
    Rectangle {
        id:addressBar;objectName:"browser-address";visible:!root.typing;x:8;y:root.chrome?8:-height-4;width:parent.width-16;height:34;radius:10;color:Qt.alpha(Theme.paper,.95);border.color:Qt.alpha(Theme.chassis,.24);z:2
        Behavior on y {NumberAnimation {duration:Theme.motion(150);easing.type:Easing.OutCubic}}
        Text {x:12;width:parent.width-67;anchors.verticalCenter:parent.verticalCenter;text:root.startPage?"Search or enter an address":root.page.url.toString();font.pixelSize:13;color:Theme.ink;elide:Text.ElideMiddle;textFormat:Text.PlainText}
        MouseArea {anchors.fill:parent;anchors.rightMargin:48;onClicked:flow.requestAddress(root.page?root.page.url.toString():"")}
        Rectangle {anchors.right:parent.right;anchors.rightMargin:6;anchors.verticalCenter:parent.verticalCenter;width:34;height:24;radius:6;color:Qt.alpha(Theme.chassis,.1);border.color:root.toolsFocused&&root.toolIndex===-1?Theme.yellow:Qt.alpha(Theme.chassis,.3)
            Text {anchors.centerIn:parent;text:flow.tabs.length;color:Theme.ink;font.pixelSize:12;font.bold:true}
            MouseArea {anchors.fill:parent;onClicked:root.openPopup("tabs")}
        }
        Rectangle {visible:root.page&&root.page.loading;x:8;y:parent.height-2;width:(parent.width-16)*(root.page?root.page.loadProgress:0)/100;height:2;color:Theme.chassisTop}
    }
    Rectangle {visible:root.error.length>0;x:10;y:50;width:parent.width-20;height:42;radius:8;color:Theme.paper;z:3
        Text {x:10;anchors.verticalCenter:parent.verticalCenter;width:parent.width-40;text:root.error;color:Theme.ink;font.pixelSize:12;maximumLineCount:2;elide:Text.ElideRight;wrapMode:Text.Wrap;textFormat:Text.PlainText}
        MouseArea {anchors.fill:parent;onClicked:root.error=""}
    }
    MouseArea {z:3;anchors.top:parent.top;width:parent.width;height:7;onPressed:root.reveal()}
    MouseArea {z:3;anchors.bottom:parent.bottom;width:parent.width;height:7;onPressed:root.reveal()}
    Item {z:4;x:root.pointerX;y:root.pointerY;width:14;height:18;visible:root.pointerVisible&&root.takesFocus&&!root.popup
        Shape {anchors.fill:parent;ShapePath {strokeColor:Theme.paper;strokeWidth:1;fillColor:Theme.ink;PathSvg {path:"M 1 1 L 1 16 L 5 12 L 8 18 L 11 16 L 8 10 L 14 10 Z"}}}
    }
    // Keep native field focus for IME commit, but block page touches outside a
    // global modal's geometry (including the physical bottom in fullscreen).
    MouseArea {anchors.fill:parent;z:4;visible:!root.takesFocus&&!root.typing;acceptedButtons:Qt.AllButtons;onWheel:wheel=>wheel.accepted=true}
    Item {
        anchors.fill:parent;visible:root.popup!=="";z:5
        Rectangle {anchors.fill:parent;color:root.listPopover?"transparent":Theme.surfaceColor("#65162723");MouseArea {anchors.fill:parent;onClicked:if(root.popup!=="permission")root.dismiss()}}
        Rectangle {
            width:Math.min(root.listPopover?370:540,parent.width-36)
            height:Math.min(root.listPopover?Math.max(116,Math.min(285,63+rows.count*46)):330,parent.height-24)
            x:root.listPopover?parent.width-width-16:(parent.width-width)/2
            y:root.listPopover?parent.height-height-38:(parent.height-height)/2
            radius:14;color:Theme.paper;border.width:2;border.color:Theme.rim
            Text {x:18;y:14;text:root.popup==="tabs"?"Your tabs":root.popup==="bookmarks"?"Bookmarks":root.popup==="history"?"History":root.popup==="permission"?root.questionTitle:"Page actions";color:Theme.ink;font.family:Theme.displayFamily;font.pixelSize:21}
            Text {anchors.right:close.left;anchors.rightMargin:18;y:16;text:root.popup==="tabs"?"+ New tab":root.popup==="bookmarks"?(root.currentBookmarked?"★ Saved":"☆ Save page"):"";font.pixelSize:13;color:Theme.ink
                MouseArea {anchors.fill:parent;anchors.margins:-5;onClicked:{if(root.popup==="tabs"){flow.newTab();root.dismiss()}else if(root.popup==="bookmarks"&&root.page)flow.toggleBookmark(root.page.url.toString(),root.page.title)}}
            }
            Text {id:close;anchors.right:parent.right;anchors.rightMargin:16;y:12;text:"×";font.pixelSize:24;color:Theme.ink;MouseArea {anchors.fill:parent;anchors.margins:-7;onClicked:root.dismiss()}}
            Text {id:questionText;x:18;y:49;width:parent.width-36;visible:root.popup==="permission";text:root.question;wrapMode:Text.WrapAnywhere;maximumLineCount:4;elide:Text.ElideRight;color:Theme.ink;font.pixelSize:13;textFormat:Text.PlainText}
            ListView {
                id:rows;x:14;y:root.popup==="permission"?questionText.y+questionText.height+10:51;width:parent.width-28;height:parent.height-y-12;clip:true;spacing:3
                model:root.popup==="tabs"?flow.tabs:root.popup==="bookmarks"?flow.bookmarks:root.popup==="history"?flow.history:root.popupRows
                currentIndex:root.popupIndex
                onCurrentIndexChanged:positionViewAtIndex(currentIndex,ListView.Contain)
                boundsBehavior:Flickable.StopAtBounds
                delegate:Rectangle {
                    required property var modelData;required property int index;width:rows.width;height:root.popup==="tabs"?70:43;radius:8;color:root.popupIndex===index?Qt.alpha(Theme.chassis,.1):"transparent";border.color:root.popupIndex===index?Qt.alpha(Theme.chassis,.4):"transparent"
                    Image {id:thumb;visible:root.popup==="tabs";x:5;y:5;width:94;height:60;fillMode:Image.PreserveAspectFit;source:visible&&root.thumbs[modelData.id]?root.thumbs[modelData.id].url:""}
                    Text {x:root.popup==="tabs"?110:10;anchors.verticalCenter:parent.verticalCenter;width:parent.width-x-(root.popup==="tabs"?42:14);text:modelData.title||modelData.url||"New tab";font.pixelSize:14;color:Theme.ink;elide:Text.ElideRight;textFormat:Text.PlainText}
                    Rectangle {x:10;anchors.bottom:parent.bottom;width:parent.width-20;height:1;color:Qt.alpha(Theme.chassis,.12)}
                    MouseArea {anchors.fill:parent;anchors.rightMargin:root.popup==="tabs"?40:0;onClicked:root.activateRow(index)}
                    Text {visible:root.popup==="tabs";anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter;text:"×";font.pixelSize:22;color:Theme.muted;MouseArea {anchors.fill:parent;anchors.margins:-8;onClicked:flow.closeTab(modelData.id)}}
                }
                Text {anchors.centerIn:parent;visible:rows.count===0;text:root.popup==="bookmarks"?"Save a page to find it here":"Your visited pages will appear here";font.pixelSize:13;color:Theme.muted}
            }
            Rectangle {visible:root.listPopover&&rows.contentHeight>rows.height;x:parent.width-8;y:rows.y+rows.visibleArea.yPosition*rows.height;width:3;height:Math.max(16,rows.visibleArea.heightRatio*rows.height);radius:1.5;color:Qt.alpha(Theme.chassis,.35)}
        }
    }
}
