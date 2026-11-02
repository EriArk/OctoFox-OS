import QtQuick
import QtWebEngine

Item {
    id: engine
    property var flow
    property var surface
    property var views: ({})
    property var current: null
    property bool reconciling: false
    function reconcile() {
        if(!flow||!surface||reconciling)return
        reconciling=true
        const ids = flow.tabs.map(t => t.id)
        for (const id in views) if (ids.indexOf(id)<0) { const old=views[id];if(current===old)current=null;delete views[id];surface.forgetTab(id);old.destroy() }
        // Restored tabs keep their identity/title/URL, but only start a renderer
        // when visited. Already opened tabs retain DOM, history and downloads.
        for (const tab of flow.tabs) if (tab.id===flow.selected && tab.url!=="about:blank" && !views[tab.id]) views[tab.id]=page.createObject(engine,{tabId:tab.id,url:tab.url})
        if(current&&current.tabId!==flow.selected)surface.captureTab(current.tabId,current)
        current=views[flow.selected] || null
        for (const id in views) views[id].selected=(id===flow.selected)
        surface.page=current
        reconciling=false
    }
    Component.onCompleted: reconcile()
    Connections { target: flow || null; function onChanged() { engine.reconcile() } }
    Component {
        id: page
        WebEngineView {
            id: web
            required property string tabId
            property bool selected: false
            property var siteRequest: null
            property int siteRequestId: 0
            property string siteRequestKind: ""
            function cancelSiteRequest() { if(siteRequestId)engine.flow.cancelDialog(siteRequestId) }
            function requestSiteDialog(request,kind,origin,message,initial,types) {
                request.accepted=true
                if(!selected||!engine.surface.active){request.dialogReject();return}
                cancelSiteRequest()
                siteRequest=request;siteRequestKind=kind
                siteRequestId=engine.flow.requestDialog(tabId,kind,origin,message,initial||"",types||[])
                if(!siteRequestId){siteRequest=null;request.dialogReject()}
            }
            Connections {
                target: engine.flow
                function onDialogFinished(id,accepted,values) {
                    if(id!==web.siteRequestId||!web.siteRequest)return
                    const request=web.siteRequest, kind=web.siteRequestKind
                    web.siteRequest=null;web.siteRequestId=0
                    if(!accepted)request.dialogReject()
                    else if(kind==="file"||kind==="files"||kind==="folder")request.dialogAccept(values)
                    else if(kind==="prompt")request.dialogAccept(values[0]||"")
                    else request.dialogAccept()
                    if(web.foreground)web.forceActiveFocus()
                }
            }
            Component.onDestruction: cancelSiteRequest()
            property real lastScroll: 0
            // Chromium rasterizes at the item's own size. Compensate the shell
            // transform so pages stay crisp at native pixels, with readable CSS.
            width: engine.width*Theme.uiScale; height: engine.height*Theme.uiScale
            scale: 1/Theme.uiScale; transformOrigin: Item.TopLeft
            zoomFactor: Theme.uiScale
            visible: selected
            profile: engine.flow.profile
            backgroundColor: Theme.paper
            audioMuted: !engine.surface.mediaAllowed || !selected
            readonly property bool foreground: selected && engine.surface.active
            readonly property bool canFreeze: !foreground && recommendedState!==WebEngineView.LifecycleState.Active
                && !engine.flow.downloads.some(job => job.state==="running" || job.state==="paused")
            onCanFreezeChanged: {
                if(canFreeze)freezeDelay.restart()
                else {freezeDelay.stop();lifecycleState=WebEngineView.LifecycleState.Active}
            }
            Timer {
                id: freezeDelay; interval: 15000
                onTriggered: if(web.canFreeze)web.lifecycleState=WebEngineView.LifecycleState.Frozen
            }
            settings.fullScreenSupportEnabled: true
            settings.touchIconsEnabled: true
            settings.scrollAnimatorEnabled: true
            settings.playbackRequiresUserGesture: true
            settings.focusOnNavigationEnabled: false
            settings.localContentCanAccessRemoteUrls: false
            settings.localContentCanAccessFileUrls: false
            settings.javascriptCanAccessClipboard: false
            // Keep live DOM/downloads across shell navigation. Chromium throttles
            // invisible views; never discard them as a side effect of tab switching.
            function publish(visited) { engine.flow.updateTab(tabId,url.toString(),title,icon.toString(),visited) }
            onUrlChanged: { cancelSiteRequest();if(selected)engine.flow.stopPageInput();publish(false);if(selected)engine.surface.reveal() }
            onTitleChanged: publish(false)
            onIconChanged: publish(false)
            onActiveFocusChanged: if(activeFocus&&selected)engine.surface.queueFieldCheck()
            onLoadingChanged: function(info) { if(info.status===WebEngineView.LoadStartedStatus)cancelSiteRequest();if(info.status===WebEngineView.LoadSucceededStatus)publish(true);if(selected&&info.status===WebEngineView.LoadFailedStatus)engine.surface.error=info.errorString }
            onScrollPositionChanged: {const dy=scrollPosition.y-lastScroll;lastScroll=scrollPosition.y;if(selected&&Math.abs(dy)>3)engine.surface.scrolled(dy)}
            onContextMenuRequested: function(request) {
                request.accepted=true
                const rows=[]
                function add(label,code) {const a=web.action(code);if(a&&a.enabled)rows.push({title:label,action:code})}
                if(request.linkUrl.toString()) {add("Open link in new tab",WebEngineView.OpenLinkInNewTab);add("Copy link",WebEngineView.CopyLinkToClipboard);add("Download link",WebEngineView.DownloadLinkToDisk)}
                if(request.mediaType===ContextMenuRequest.MediaTypeImage) {add("Open image",WebEngineView.OpenImageInNewTab);add("Save image",WebEngineView.DownloadImageToDisk);add("Copy image",WebEngineView.CopyImageToClipboard)}
                if(request.selectedText) {add("Copy",WebEngineView.Copy);rows.push({title:"Search selected text",search:request.selectedText})}
                if(request.isContentEditable) {add("Paste",WebEngineView.Paste);add("Select all",WebEngineView.SelectAll);rows.push({title:"Keyboard",keyboard:true})}
                if(rows.length)engine.surface.openPopup("context",rows)
            }
            onNewWindowRequested: function(request) {
                if(!request.userInitiated)return
                const id=engine.flow.newTab();engine.views[id]=page.createObject(engine,{tabId:id,url:"about:blank"});engine.reconcile();engine.views[id].acceptAsNewWindow(request)
            }
            onFullScreenRequested: function(request) {request.accept();engine.surface.fullScreen=request.toggleOn;engine.surface.reveal()}
            onPermissionRequested: function(permission) {
                if(!selected||!engine.surface.active){permission.deny();return}
                // Qt 6.11 QWebEnginePermission::PermissionType, in enum order.
                const names=["","the microphone","the camera","the camera and microphone","screen sharing","screen and audio sharing","pointer lock","notifications","your location","the clipboard","local fonts"]
                const name=names[permission.permissionType]
                if(!name){permission.deny();return}
                engine.surface.ask("Site permission",permission.origin.toString()+" requests access to "+name+".",function(allowed){if(allowed)permission.grant();else permission.deny()})
            }
            onJavaScriptDialogRequested: function(request) {
                const kinds=["alert","confirm","prompt","leave"]
                requestSiteDialog(request,kinds[request.type]||"confirm",request.securityOrigin.toString(),request.message,request.defaultText,[])
            }
            onFileDialogRequested: function(request) {
                const kind=request.mode===FileDialogRequest.FileModeOpen?"file":request.mode===FileDialogRequest.FileModeOpenMultiple?"files":request.mode===FileDialogRequest.FileModeUploadFolder?"folder":""
                if(!kind){request.accepted=true;request.dialogReject();engine.surface.error="This file dialog is not supported. Use the site's download action.";return}
                requestSiteDialog(request,kind,web.url.toString(),"","",request.acceptedMimeTypes)
            }
            onCertificateError: function(error) {error.rejectCertificate();engine.surface.error="The site's certificate could not be verified.";engine.surface.reveal()}
            onNavigationRequested: function(request) {
                const scheme=request.url.toString().split(":")[0]
                if(["https","http","about","blob","data"].indexOf(scheme)<0)request.reject()
            }
            onRenderProcessTerminated: function(status,code) {cancelSiteRequest();if(selected){engine.surface.error="This page stopped. Reload to try again.";engine.surface.reveal()}}
            TapHandler {
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.DragThreshold
                onLongPressed: {engine.flow.pointerEvent(web,point.position.x,point.position.y,2)}
                onTapped: engine.surface.queueFieldCheck()
            }
        }
    }
}
