using Toybox.Application;
using Toybox.WatchUi;

class RunDash970App extends Application.AppBase {
    // 实际交给系统的 View：应用设置变化时需要刷新它持有的配置缓存，不能只请求重绘。
    hidden var mView = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        mView = createView();
        return [ mView ];
    }

    // 创建实际使用的 View。单独成函数，便于单元测试替换为带调用计数的子类。
    function createView() {
        return new RunDash970View();
    }

    // Garmin Connect / Connect IQ settings may change while the field is installed.
    // 立即让 View 的配置缓存（兜底最大心率、心率区间）生效，再请求重绘；不会动单圈基线。
    function onSettingsChanged() {
        if (mView != null) {
            mView.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}
