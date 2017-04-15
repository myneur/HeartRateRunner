using Toybox.WatchUi as Ui;

var laps = 0;
var currentView = 0;

class KeyboardDelegate extends Ui.InputDelegate {

    function initialize() {
        Ui.InputDelegate.initialize();
    }

    function onKey(key) { // switches between showing total and lap numbers
        if(laps>0){
            var k = key.getKey();
            if (k == Ui.KEY_UP && currentView==0) {
                return currentView++;  
            } else if (k == Ui.KEY_DOWN && currentView == 1){
                return currentView--;
            }
        }
        Ui.InputDelegate.onKey(key);
    }
}

