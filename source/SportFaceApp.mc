import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

class FluxApp extends Application.AppBase {

    var mView as FluxView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {}

    function onStop(state as Dictionary?) as Void {}

    function getInitialView() {
        mView = new FluxView();
        return [ mView as FluxView ];
    }

    // Called when settings change via Connect IQ app or on-watch menu.
    function onSettingsChanged() as Void {
        if (mView != null) {
            (mView as FluxView).loadSettings();
        }
        WatchUi.requestUpdate();
    }
}

function getApp() as FluxApp {
    return Application.getApp() as FluxApp;
}
