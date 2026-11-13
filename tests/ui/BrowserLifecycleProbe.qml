import QtQuick
import QtWebEngine

Window {
    id: window
    width:960;height:540;visible:true
    property string original:""
    property string disposable:""
    property string download:""
    property int stage:0
    onStageChanged:console.log("LIFECYCLE_STAGE",stage)
    property bool busy:false
    property string failure:""
    function check(ok,message){if(!ok){failure=message;console.error("LIFECYCLE_FAILED",message);step.stop();Qt.exit(2)}return ok}
    Item {
        id:surface
        property bool active:true
        property bool foreground:active
        property bool mediaAllowed:false
        property bool gameRunning:false
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
                disposable=browser.selected
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
                browser.select(disposable);surface.gameRunning=true;interval=8000;stage++
            } else if(stage===6){
                if(!check(engine.current.lifecycleState===WebEngineView.LifecycleState.Discarded,"safe game-background page was not discarded: state="+engine.current.lifecycleState+", recommended="+engine.current.recommendedState+", foreground="+engine.current.foreground+", visible="+engine.current.visible+", game="+engine.current.gameRunning))return
                surface.gameRunning=false;interval=1000;stage++
            } else if(stage===7){
                if(!check(engine.current.lifecycleState===WebEngineView.LifecycleState.Discarded,"return to shell woke an unvisited page"))return
                surface.foreground=true;interval=400;stage++
            } else if(stage===8){
                if(!check(engine.current.lifecycleState===WebEngineView.LifecycleState.Active,"discarded page did not resume"))return
                if(!window.active){window.requestActivate();return}
                busy=true;engine.current.runJavaScript("typeof window.frozenMarker",function(value){
                    if(!check(value==="undefined","discard did not release the old DOM"))return
                    engine.current.forceActiveFocus();window.requestActivate()
                    engine.current.runJavaScript("document.querySelector('input').focus()",function(){busy=false;stage++})
                })
            } else if(stage===9){
                browser.editPageField(engine.current,true);keyboard.insertText("unsaved draft");stage++
            } else if(stage===10){
                busy=true;engine.current.runJavaScript("document.querySelector('input').value",function(value){
                    if(!check(value==="unsaved draft","native form input failed: "+String(value)))return
                    surface.foreground=false;surface.gameRunning=true;interval=8000;busy=false;stage++
                })
            } else if(stage===11){
                if(!check(engine.current.inputTouched,"shared keyboard did not protect the edited field"))return
                if(!check(engine.current.lifecycleState!==WebEngineView.LifecycleState.Discarded,"edited form was discarded"))return
                surface.foreground=true;interval=400;stage++
            } else if(stage===12){
                busy=true;engine.current.runJavaScript("document.querySelector('input').value",function(value){
                    if(!check(value==="unsaved draft","game transition lost unsaved form"))return
                    engine.current.url=probeUrl+"?clean-document";busy=false;stage++
                })
            } else if(stage===13){
                if(!check(!engine.current.inputTouched,"new document retained the old input guard"))return
                surface.foreground=false;interval=8000;stage++
            } else if(stage===14){
                if(!check(engine.current.lifecycleState===WebEngineView.LifecycleState.Discarded,"clean new document did not discard"))return
                console.log("LIFECYCLE_PASSED lazy load, freeze, DOM resume, background download, close, safe game discard, reload, unsaved input protection, new document");Qt.exit(0)
            }
        }
    }
}
