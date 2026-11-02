import QtQuick

Window {
    id: window
    width:960;height:640;visible:true
    property int stage:0
    property bool passed:false
    property bool busy:false
    QtObject { id:shell;property var keyboard:null;property bool menuOpen:false;property string notice:"";function pressButton(button){keyboard.cancel()} }
    Loader {id:pane;anchors.fill:parent}
    Loader {id:keys;anchors.fill:parent}
    Binding {target:pane.item;property:"takesFocus";value:!keyboard.open;when:!!pane.item}
    function fail(message){console.error("INPUT_FAILED",stage,message);step.stop();Qt.exit(2)}
    function check(ok,message){if(!ok)fail(message);return ok}
    function click(id){
        busy=true
        pane.item.page.runJavaScript("(()=>{const r=document.getElementById('"+id+"').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2]})()",function(p){browser.pointerEvent(pane.item.page,p[0],p[1],1);busy=false;stage++})
    }
    function result(expected){busy=true;pane.item.page.runJavaScript("JSON.stringify(result)",function(value){if(!check(value===JSON.stringify(expected),value+" != "+JSON.stringify(expected)))return;busy=false;stage++})}
    function choose(name){const rows=browser.picker.rows;for(let i=0;i<rows.length;i++)if(rows[i].title===name){browser.picker.activate(i,"list");return}fail("missing "+name)}
    function shot(name){window.contentItem.grabToImage(r=>r.saveToFile(probeData+"/"+name+".png"))}
    Component.onCompleted:{shell.keyboard=keyboard;browser.openUrl(probeUrl);pane.setSource(paneSource,{flow:browser,active:true,takesFocus:true});keys.setSource(keyboardSource,{shell:shell})}
    Timer {
        id:step;interval:500;repeat:true;running:true
        onTriggered:{
            if(stage===44){passed=true;console.log("INPUT_PASSED website dialogs and uploads");Qt.exit(0);return}
            if(stage===32){browser.select(browser.tabs[0].id);stage++;return}
            if(busy||!pane.item||!pane.item.page||pane.item.page.loading||browser.picker.busy)return
            if(stage===0)click("single")
            else if(stage===1){if(!check(browser.dialog.kind==="file"&&browser.picker.open,"single file picker"))return;browser.picker.navigate(probeData+"/uploads");stage++}
            else if(stage===2){choose("one.txt");shot("upload");browser.picker.choose();stage++}
            else if(stage===3)result("one.txt:fixture")
            else if(stage===4)click("multi")
            else if(stage===5){browser.picker.navigate(probeData+"/uploads");stage++}
            else if(stage===6){choose("one.txt");choose("two.txt");shot("multiple");stage++}
            else if(stage===7){browser.picker.choose();stage++}
            else if(stage===8)result("one.txt,two.txt")
            else if(stage===9)click("prompt")
            else if(stage===10){if(!check(browser.dialog.kind==="prompt"&&browser.dialog.text==="initial","prompt/default"))return;shot("prompt");browser.editDialogText();stage++}
            else if(stage===11){if(!check(keyboard.open,"shared keyboard"))return;keyboard.insertText("Привет");shot("prompt-keyboard");stage++}
            else if(stage===12){keyboard.pressKey(16777220,0,"");stage++}
            else if(stage===13){if(!check(browser.dialog.text==="Привет","edited response"))return;pane.item.handle("down");pane.item.handle("down");pane.item.handle("click");stage++}
            else if(stage===14)result("Привет")
            else if(stage===15)click("prompt")
            else if(stage===16){pane.item.handle("back");stage++}
            else if(stage===17)result(null)
            else if(stage===18)click("confirm")
            else if(stage===19){pane.item.handle("back");stage++}
            else if(stage===20)result(false)
            else if(stage===21)click("alert")
            else if(stage===22){pane.item.handle("click");stage++}
            else if(stage===23)result("alert closed")
            else if(stage===24)click("folder")
            else if(stage===25){if(!check(browser.dialog.kind==="folder","folder request"))return;browser.picker.navigate(probeData+"/uploads/nested");stage++}
            else if(stage===26){shot("folder");browser.picker.choose();stage++}
            else if(stage===27)result("nested/three.txt")
            else if(stage===28)click("multi")
            else if(stage===29){pane.item.active=false;if(!check(!browser.picker.open&&!browser.dialog.id,"leave cancels upload"))return;pane.item.active=true;stage++}
            else if(stage===30)click("prompt")
            else if(stage===31){browser.newTab();if(!check(!browser.dialog.id,"tab switch cancels"))return;stage++}
            else if(stage===33)click("prompt")
            else if(stage===34){browser.editDialogText();keyboard.backspace();keyboard.pressKey(16777220,0,"");browser.answerDialog(true);stage++}
            else if(stage===35)result("")
            else if(stage===36)click("leave")
            else if(stage===37)result("guarded")
            else if(stage===38){pane.item.page.reload();stage++}
            else if(stage===39){if(!check(browser.dialog.kind==="leave","navigation confirmation"))return;browser.cancelDialog();stage++}
            else if(stage===40)result("guarded")
            else if(stage===41){pane.item.page.reload();stage++}
            else if(stage===42){if(!check(browser.dialog.kind==="leave","navigation confirmation retry"))return;browser.answerDialog(true);stage++}
            else if(stage===43)result("")
            else {passed=true;console.log("INPUT_PASSED website uploads, multi/folder, prompt/default/unicode, cancel, alert, confirmation, lifecycle");Qt.exit(0)}
        }
    }
}
