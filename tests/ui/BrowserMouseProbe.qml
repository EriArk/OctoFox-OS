import QtQuick

Window {
    id: window
    width:960;height:540;visible:true
    property int stage:0
    onStageChanged: console.log("MOUSE_STAGE",stage)
    property bool passed:false
    property bool busy:false
    property real oldX:0
    QtObject { id:shell;property var keyboard:null;property bool menuOpen:false;property string notice:"";function pressButton(button){keyboard.cancel()} }
    Loader {id:pane;anchors.fill:parent}
    Loader {id:keys;anchors.fill:parent}
    Binding {target:pane.item;property:"takesFocus";value:!keyboard.open;when:!!pane.item}
    Binding {target:pane.item;property:"typing";value:keyboard.live;when:!!pane.item}
    function fail(message){console.error("MOUSE_FAILED",stage,message);step.stop();gamepad.axes(0,0);Qt.exit(2)}
    function check(ok,message){if(!ok)fail(message);return ok}
    function target(id,callback){
        busy=true
        pane.item.page.runJavaScript("(()=>{const r=document.getElementById('"+id+"').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2]})()",function(p){
            const point=pane.item.page.mapToItem(pane.item,p[0],p[1]);pane.item.movePointer(point.x-pane.item.pointerX,point.y-pane.item.pointerY)
            busy=false;callback()
        })
    }
    function verify(js,expected){busy=true;pane.item.page.runJavaScript(js,function(value){if(!check(value===expected,js+" => "+JSON.stringify(value)))return;busy=false;stage++})}
    Component.onCompleted:{shell.keyboard=keyboard;browser.openUrl(probeUrl);pane.setSource(paneSource,{flow:browser,active:true,takesFocus:true});keys.setSource(keyboardSource,{shell:shell})}
    Timer {id:step;interval:350;repeat:true;running:true
        onTriggered:{
            if(busy||!pane.item)return
            if(stage<9&&(!pane.item.page||pane.item.page.loading))return
            if(stage===0){
                if(!window.active){window.requestActivate();return}
                busy=true
                pane.item.page.runJavaScript("document.body.innerHTML='<button id=click style=\"position:absolute;top:140px;left:200px;width:180px;height:70px\">Click</button><a id=link href=\"/next\" style=\"position:absolute;top:230px;left:240px\">Link</a><input id=field style=\"position:absolute;top:300px;left:200px\"><div style=\"height:2400px\"></div>';window.clicks=0;window.hovered=false;document.getElementById('click').onclick=()=>window.clicks++;document.getElementById('click').onmouseover=()=>window.hovered=true;true",function(){busy=false;oldX=pane.item.pointerX;gamepad.axes(.7,0);stage++})
            } else if(stage===1){gamepad.axes(0,0);if(!check(pane.item.pointerVisible&&pane.item.pointerX>oldX+10,"left stick did not move cursor"))return;target("click",function(){gamepad.press("click");stage++})}
            else if(stage===2)verify("window.clicks===1&&window.hovered",true)
            else if(stage===3)target("link",function(){gamepad.press("context");stage++})
            else if(stage===4){if(!check(pane.item.popup==="context","R3 did not open context menu"))return;gamepad.press("back");if(!check(!pane.item.popup,"B did not close menu"))return;gamepad.axes(0,0,0,.8);stage++}
            else if(stage===5){gamepad.axes(0,0);verify("window.scrollY>0",true)}
            else if(stage===6){busy=true;pane.item.page.runJavaScript("window.scrollTo(0,0)",function(){busy=false;stage++})}
            else if(stage===7)target("field",function(){gamepad.press("click");stage++})
            else if(stage===8){if(!keyboard.live){busy=true;pane.item.page.runJavaScript("JSON.stringify({active:document.activeElement.id,focus:document.hasFocus(),scroll:scrollY})",function(value){console.error("MOUSE_INPUT_STATE",value,"page focus",pane.item.page.activeFocus,"window",window.active,"cursor",pane.item.pointerX,pane.item.pointerY);fail("click did not open field keyboard")});return;}keyboard.insertText("controller mouse");verify("document.getElementById('field').value","controller mouse")}
            else if(stage===9){keyboard.cancel();browser.newTab();stage++}
            else if(stage===10){pane.item.movePointer(200-pane.item.pointerX,20-pane.item.pointerY);gamepad.press("click");stage++}
            else if(stage===11){if(!check(keyboard.open&&!keyboard.live,"cursor click on local dashboard missed address field"))return;keyboard.cancel();window.contentItem.grabToImage(function(image){image.saveToFile(probeData+"/mouse.png");passed=true;console.log("MOUSE_PASSED stick, hover, A, R3, scroll, keyboard, dashboard");Qt.exit(0)});step.stop()}
        }
    }
}
