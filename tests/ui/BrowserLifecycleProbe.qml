import QtQuick
import QtWebEngine

Window {
    id: window
    width:960;height:540;visible:true
    property string original:""
    property string download:""
    property int stage:0
    property bool busy:false
    function check(ok,message){if(!ok){console.error("LIFECYCLE_FAILED",message);step.stop();Qt.exit(2)}return ok}
    Item {
        id:surface
        property bool active:true
        property bool foreground:active
        property bool mediaAllowed:false
        property var page:null
        property string error:""
        property bool fullScreen:false
        property int forgotten:0
        function captureTab(id,view){}
        function forgetTab(id){forgotten++}
        function reveal(){}
        function queueFieldCheck(){}
        function scrolled(delta){}
        function openPopup(kind,rows){}
        function ask(title,question,callback){callback(false)}
    }
    Loader {id:loader;anchors.fill:parent;onLoaded:{item.flow=browser;item.surface=surface;item.reconcile();step.start()}}
    Component.onCompleted:{browser.openUrl(probeUrl);original=browser.selected;browser.newTab();browser.newTab();browser.select(original);loader.source=engineSource}
    Timer {id:step;interval:400;repeat:true
        onTriggered:{
            const engine=loader.item
            if(busy||!engine.current||engine.current.loading)return
            if(stage===0){
                if(!check(Object.keys(engine.views).length===1,"restored tabs eagerly loaded"))return
                engine.current.runJavaScript("window.perfMarker='kept';const a=document.createElement('a');a.href='/range';a.download='lifecycle.bin';a.click()")
                stage++
            } else if(stage===1){
                if(!browser.downloads.length)return
                download=browser.downloads[0].id;browser.controlDownload(download,"pause");browser.newTab(probeUrl+"?second");stage++
            } else if(stage===2){
                if(!check(Object.keys(engine.views).length===2,"visited tab did not load"))return
                if(!check(browser.downloads[0].state==="paused","download did not pause"))return
                busy=true;engine.current.runJavaScript("window.frozenMarker=42",function(){surface.foreground=false;interval=18000;busy=false;stage++})
            } else if(stage===3){
                if(!check(engine.current.lifecycleState===WebEngineView.LifecycleState.Frozen,"paused download kept unrelated page awake"))return
                surface.foreground=true;interval=400;busy=true
                engine.current.runJavaScript("window.frozenMarker",function(value){
                    if(!check(value===42,"frozen DOM was lost"))return
                    browser.select(original);busy=false;stage++
                })
            } else if(stage===4){
                if(!check(engine.current.lifecycleState===WebEngineView.LifecycleState.Active,"page did not resume"))return
                busy=true;engine.current.runJavaScript("window.perfMarker",function(value){
                    if(!check(value==="kept","DOM was lost"))return
                    browser.controlDownload(download,"resume");surface.foreground=false;busy=false;stage++
                })
            } else if(stage===5){
                const task=browser.downloads[0]
                if(!check(task.state!=="error"&&task.state!=="cancelled","background download failed"))return
                if(task.state!=="done")return
                if(!check(task.received===12582912,"download size mismatch"))return
                browser.closeTab(original)
                if(!check(surface.forgotten===1&&!engine.views[original],"closed tab retained"))return
                console.log("LIFECYCLE_PASSED lazy load, pause, freeze, DOM resume, background download, close");Qt.exit(0)
            }
        }
    }
}
