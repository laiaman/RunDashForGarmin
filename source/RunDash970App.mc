using Toybox.Application;
using Toybox.WatchUi;

class RunDash970App extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new RunDash970View() ];
    }

    // Garmin Connect / Connect IQ settings may change while the field is installed.
    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
