import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

class SportFaceApp extends Application.AppBase {

    var mView as SportFaceView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {}

    function onStop(state as Dictionary?) as Void {}

    function getInitialView() {
        mView = new SportFaceView();
        return [ mView as SportFaceView ];
    }

    // Called when settings change — either from the Connect IQ phone app
    // or from the on-watch settings menu (CIQ 4.x+).
    function onSettingsChanged() as Void {
        if (mView != null) {
            (mView as SportFaceView).loadSettings();
        }
        WatchUi.requestUpdate();
    }
}

function getApp() as SportFaceApp {
    return Application.getApp() as SportFaceApp;
}
