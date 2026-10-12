// RunDash970 单元测试（Connect IQ Test 框架）。
//
// 在模拟器 VM 里运行“真实编译后的” RunDash970View / RunDash970App / Metrics 代码，
// 通过子类替换外部读取点（活动快照、Properties、UserProfile、计时器），注入各种快照并统计调用次数。
// 它能证明：无效快照、重复通知、连续 Lap、配置刷新等逻辑在 Monkey C 里确实按预期工作。
// 它不能证明：真机是否真的送达 onWorkoutStepComplete / onTimerLap2 以及先后顺序——这要靠
// 模拟器端到端（Timer Controls）与真机事件日志，见 MANUAL_VALIDATION.md。
//
// 只在 monkey-test.jungle / `monkeyc -t` 构建中编译，不进入正式 PRG。运行：scripts/run-unit-tests.sh
import Toybox.Lang;
import Toybox.Test;
using Toybox.Activity;
using Toybox.UserProfile;
using Toybox.Math;

// 假的活动快照：只提供被测代码会读取的字段，且允许放入“坏数据”（负数 / 字符串）。
class RdFakeInfo {
    var timerTime = null;
    var elapsedDistance = null;
    var elapsedTime = null;
    var currentHeartRate = null;
    var averageHeartRate = null;
    var currentCadence = null;
    var averageCadence = null;
    var currentSpeed = null;
    var averageSpeed = null;

    function initialize(timerMs, distanceM) {
        timerTime = timerMs;
        elapsedDistance = distanceM;
    }
}

// 子类覆盖 View 的“外部读取封装”，其余逻辑全部走真实代码。
class RdTestView extends RunDash970View {
    var snapshot = null;                  // readActivitySnapshot() 返回值（回调里读取的快照）
    var maxHrProperty = 180;              // readMaxHrProperty() 返回值
    var currentSport = 1;                 // readCurrentSport() 返回值（1 = 跑步）
    var sportZones = null;                // 当前运动的用户区间
    var genericZones = null;              // 通用区间
    var clockMs = 1000000;                // nowMs() 返回值（测试里手动推进）
    var propReads = 0;                    // Properties 读取次数
    var sportReads = 0;                   // UserProfile.getCurrentSport 次数
    var zoneReads = 0;                    // UserProfile.getHeartRateZones 次数
    var snapshotReads = 0;                // Activity.getActivityInfo 次数

    function initialize() {
        sportZones = [100, 120, 140, 160, 175, 190];
        RunDash970View.initialize();
    }

    // 喂入一份假快照，相当于系统调用一次 compute(info)。
    // 参数不带类型：compute(info as Activity.Info) 的静态检查会拒绝非 Activity.Info 的假对象。
    function feed(info) {
        return compute(info);
    }

    function readActivitySnapshot() {
        snapshotReads += 1;
        return snapshot;
    }

    function readMaxHrProperty() {
        propReads += 1;
        return maxHrProperty;
    }

    function readCurrentSport() {
        sportReads += 1;
        return currentSport;
    }

    function readHrZones(sport) {
        zoneReads += 1;
        if (sport == UserProfile.HR_ZONE_SPORT_GENERIC) {
            return genericZones;
        }
        return sportZones;
    }

    function nowMs() {
        return clockMs;
    }

    // 状态观察（hidden 成员对子类可见）。
    function baseTimer() { return mLapStartTimerMs; }
    function baseDistance() { return mLapStartDistanceM; }
    function isPending() { return mLapBaselinePending; }
    function zones() { return mHrZones; }
    function maxHr() { return mMaxHr; }
    function shownTimer() { return mTimerMs; }
    function shownHr() { return mHr; }

    function zoneAt(i) {
        if (mHrZones == null) {
            return null;
        }
        var z = mHrZones as Array<Number>;
        return z[i];
    }

    // 单圈显示值，公式与 drawFullScreen970() 一致。
    // 单圈时间 ms：时间与基线任一未知则为 null。
    function lapMs() {
        if (mTimerMs == null || mLapStartTimerMs == null) {
            return null;
        }
        var ms = mTimerMs.toNumber() - mLapStartTimerMs.toNumber();
        if (ms < 0) {
            ms = 0;
        }
        return ms;
    }

    // 单圈距离 m：距离与基线任一未知则为 null。
    function lapM() {
        if (mDistanceM == null || mLapStartDistanceM == null) {
            return null;
        }
        var m = mDistanceM.toFloat() - mLapStartDistanceM.toFloat();
        if (m < 0.0) {
            m = 0.0;
        }
        return m;
    }

    // 单圈配速 s/km：单圈距离不足 Metrics.MIN_LAP_DISTANCE_M（20 m）或任一未知则为 null。
    function lapPace() {
        return Metrics.lapPaceSeconds(mTimerMs, mDistanceM, mLapStartTimerMs, mLapStartDistanceM);
    }
}

class RdTestApp extends RunDash970App {
    var testView = null;

    function initialize() {
        RunDash970App.initialize();
    }

    function createView() {
        testView = new RdTestView();
        return testView;
    }
}

// Test.assertEqual(x, null) 在 x 为 null 时会因“对 null 调用 equals”报类型错误；null 判断统一走这里。
function rdAssertNull(value) {
    Test.assertMessage(value == null, "expected null");
}

// 新建一个已建立单圈基线 (timerMs, distanceM) 的测试 View。
function rdViewWithBaseline(timerMs, distanceM) {
    var v = new RdTestView();
    v.feed(new RdFakeInfo(timerMs, distanceM));
    return v;
}

// ═══════════════════════════════════════════════════════════
//  Metrics 纯函数
// ═══════════════════════════════════════════════════════════

(:test)
function tLapSnapshotValidation(logger) {
    Test.assert(Metrics.isValidLapSnapshot(0, 0.0));            // 0 是已知值，有效
    Test.assert(Metrics.isValidLapSnapshot(123456, 987.5));
    Test.assert(!Metrics.isValidLapSnapshot(null, 10.0));       // null 是未知，不是 0
    Test.assert(!Metrics.isValidLapSnapshot(10, null));
    Test.assert(!Metrics.isValidLapSnapshot(null, null));
    Test.assert(!Metrics.isValidLapSnapshot(-1, 10.0));         // 负数无效
    Test.assert(!Metrics.isValidLapSnapshot(10, -0.5));
    Test.assert(!Metrics.isValidLapSnapshot("12", 10.0));       // 非数值无效
    Test.assert(!Metrics.isValidLapSnapshot(10, "3.5"));
    Test.assert(!Metrics.isValidLapSnapshot(true, 10.0));
    return true;
}

// NaN / ±Infinity 必须被拒绝。模拟器 VM 实测 nan >= 0 为 true，所以不能靠 (x >= 0) 判断，要靠有限性检查。
(:test)
function tNonFiniteValuesAreRejected(logger) {
    Test.assert(Metrics.isFiniteNumber(0));
    Test.assert(Metrics.isFiniteNumber(0.0));
    Test.assert(Metrics.isFiniteNumber(-3));
    Test.assert(Metrics.isFiniteNumber(123456789));
    Test.assert(Metrics.isFiniteNumber(1.5));
    Test.assert(Metrics.isFiniteNumber(5000000000l));            // Long
    Test.assert(Metrics.isFiniteNumber(2.5d));                   // Double
    Test.assert(!Metrics.isFiniteNumber(null));
    Test.assert(!Metrics.isFiniteNumber("1"));
    Test.assert(!Metrics.isFiniteNumber(true));

    var nan = Math.sqrt(-1.0);                                   // 取不到 NaN 的环境会在此抛异常→测试 ERROR，便于发现
    logger.debug("nan.toString=" + nan.toString() + "  (nan >= 0) is " + (nan >= 0).toString());
    Test.assert(!Metrics.isFiniteNumber(nan));
    Test.assert(!Metrics.isValidLapSnapshot(nan, 10.0));
    Test.assert(!Metrics.isValidLapSnapshot(10, nan));
    Test.assert(!Metrics.isValidLapSnapshot(nan, nan));
    Test.assert(!Metrics.isValidHrZones([nan, 120, 140, 160, 175, 190]));
    Test.assert(!Metrics.isValidHrZones([100, 120, nan, 160, 175, 190]));

    var big = 1.0e38f;
    var inf = big * big;                                         // 单精度溢出为 Infinity
    logger.debug("inf.toString=" + inf.toString());
    Test.assert(!Metrics.isFiniteNumber(inf));
    Test.assert(!Metrics.isFiniteNumber(-inf));
    Test.assert(!Metrics.isValidLapSnapshot(10, inf));
    Test.assert(!Metrics.isValidLapSnapshot(inf, 10.0));
    Test.assert(!Metrics.isValidHrZones([100, 120, 140, 160, 175, inf]));

    // NaN 快照进入统一基线入口：与其他无效快照一样进入待初始化
    var v = rdViewWithBaseline(100000, 300.0);
    v.snapshot = new RdFakeInfo(160000, nan);
    v.onTimerLap();
    Test.assert(v.isPending());
    rdAssertNull(v.baseTimer());
    v.feed(new RdFakeInfo(nan, 10.0));                           // compute 里的补建同样拒绝 NaN
    Test.assert(v.isPending());
    return true;
}

(:test)
function tHrZonesBoundaryValidation(logger) {
    Test.assert(Metrics.isValidHrZones([100, 120, 140, 160, 175, 190]));
    Test.assert(Metrics.isValidHrZones([100, 120, 140, 160, 175, 190, 200]));  // 多余元素忽略
    Test.assert(!Metrics.isValidHrZones(null));
    Test.assert(!Metrics.isValidHrZones("abc"));
    Test.assert(Metrics.isValidHrZones([0, 120, 140, 160, 175, 190]));         // 第一项为 0 仍严格递增：不收紧 V5 原有接受范围
    Test.assert(!Metrics.isValidHrZones([100, 120, 140, 160, 175]));           // 不足 6 个
    Test.assert(!Metrics.isValidHrZones([0, 0, 0, 0, 0, 0]));                  // 全 0（未配置）
    Test.assert(!Metrics.isValidHrZones([100, 0, 140, 160, 175, 190]));        // 中间出现 0（递减）
    Test.assert(!Metrics.isValidHrZones([-5, 120, 140, 160, 175, 190]));       // 负数
    Test.assert(!Metrics.isValidHrZones([100, 120, 120, 160, 175, 190]));      // 相等（非严格递增）
    Test.assert(!Metrics.isValidHrZones([100, 120, 110, 160, 175, 190]));      // 递减
    Test.assert(!Metrics.isValidHrZones([100, 120, 140, 160, 175, 301]));      // 超上限
    Test.assert(!Metrics.isValidHrZones([100, 120, null, 160, 175, 190]));     // 含 null
    Test.assert(!Metrics.isValidHrZones(["100", 120, 140, 160, 175, 190]));    // 含非数值
    return true;
}

// ═══════════════════════════════════════════════════════════
//  单圈基线：Lap / 自动 Lap / 训练步骤完成
// ═══════════════════════════════════════════════════════════

(:test)
function tBaselineIsPairedFromOneValidSnapshot(logger) {
    var v = new RdTestView();                    // 构造时快照为 null → 待初始化
    Test.assert(v.isPending());
    v.feed(new RdFakeInfo(1000, null));          // 距离未知：不得单独建立时间基线，也不得把 null 当 0
    Test.assert(v.isPending());
    rdAssertNull(v.baseTimer());
    rdAssertNull(v.baseDistance());
    v.feed(new RdFakeInfo(2000, null));
    Test.assert(v.isPending());
    v.feed(new RdFakeInfo(3000, 12.5));          // 同一份快照里时间与距离都有效 → 成对建立
    Test.assert(!v.isPending());
    Test.assertEqual(v.baseTimer(), 3000);
    Test.assertEqual(v.baseDistance(), 12.5);
    return true;
}

(:test)
function tManualAndLegacyLapResetBaseline(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.snapshot = new RdFakeInfo(160000, 450.0);
    var handled = v.onTimerLap2({ :lapTrigger => 0 });
    Test.assertEqual(handled, true);             // onTimerLap2 返回 true 的既有行为保持不变
    Test.assertEqual(v.baseTimer(), 160000);
    Test.assertEqual(v.baseDistance(), 450.0);
    v.snapshot = new RdFakeInfo(220000, 600.0);
    v.onTimerLap();                              // 旧回调走同一个统一入口
    Test.assertEqual(v.baseTimer(), 220000);
    Test.assertEqual(v.baseDistance(), 600.0);
    return true;
}

(:test)
function tAutoLapTriggersResetBaseline(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    // 自动 Lap（时间 1 / 距离 2）与训练相关 trigger（16、21、24）全部走同一入口，onTimerLap2 都返回 true
    var triggers = [1, 2, 16, 21, 24];
    for (var i = 0; i < triggers.size(); i += 1) {
        v.snapshot = new RdFakeInfo(160000 + i * 60000, 450.0 + i * 100.0);
        var handled = v.onTimerLap2({ :lapTrigger => triggers[i] });
        Test.assertEqual(handled, true);
        Test.assertEqual(v.baseTimer(), 160000 + i * 60000);
        Test.assertEqual(v.baseDistance(), 450.0 + i * 100.0);
    }
    return true;
}

(:test)
function tWorkoutStepCompleteResetsBaseline(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.snapshot = new RdFakeInfo(160000, 450.0);
    v.onWorkoutStepComplete();                   // 本次缺失的回调
    Test.assertEqual(v.baseTimer(), 160000);
    Test.assertEqual(v.baseDistance(), 450.0);
    Test.assert(!v.isPending());
    // 新圈下一次有效显示：时间与距离都从新边界重新累计；全程时间与距离保持连续
    v.feed(new RdFakeInfo(190000, 520.0));
    Test.assertEqual(v.lapMs(), 30000);
    Test.assertEqual(v.lapM(), 70.0);
    Test.assertEqual(v.lapPace(), 428);          // 30s / 70m = 428.57 s/km → 428（与 Metrics 一致）
    Test.assertEqual(v.shownTimer(), 190000);    // 全程计时未被重置
    return true;
}

(:test)
function tLapPaceReturnsOnlyAfterDistanceThreshold(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.snapshot = new RdFakeInfo(160000, 450.0);
    v.onWorkoutStepComplete();
    v.feed(new RdFakeInfo(163000, 459.0));       // 新圈 9 m：低于 20 m 门槛 → 无配速（保持既有 20 m 阈值）
    Test.assertEqual(v.lapM(), 9.0);
    rdAssertNull(v.lapPace());
    v.feed(new RdFakeInfo(166000, 470.0));       // 新圈 20 m：达到门槛 → 配速恢复
    Test.assertEqual(v.lapM(), 20.0);
    Test.assertEqual(v.lapPace(), 300);          // 6s / 20m = 300 s/km
    return true;
}

(:test)
function tDuplicateNotificationsOnSameSnapshotAreIdempotent(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.snapshot = new RdFakeInfo(160000, 450.0);
    v.onWorkoutStepComplete();
    var t1 = v.baseTimer();
    var d1 = v.baseDistance();
    // 同一份有效快照上的重复通知（STEP + LAP2 + LAP + STEP，不管顺序）：结果完全相同
    v.onTimerLap2({ :lapTrigger => 0 });
    v.onTimerLap();
    v.onWorkoutStepComplete();
    Test.assertEqual(v.baseTimer(), t1);
    Test.assertEqual(v.baseDistance(), d1);
    Test.assert(!v.isPending());
    v.feed(new RdFakeInfo(165000, 470.0));
    Test.assertEqual(v.lapMs(), 5000);
    Test.assertEqual(v.lapM(), 20.0);
    Test.assertEqual(v.lapPace(), 250);
    return true;
}

(:test)
function tConsecutiveManualLapsHaveNoCooldown(logger) {
    // nowMs() 在测试里不推进：任何基于“距上次 Lap 的固定时间”的冷却都会把后两次吞掉
    var v = rdViewWithBaseline(100000, 300.0);
    v.snapshot = new RdFakeInfo(100400, 300.5);
    v.onTimerLap2({ :lapTrigger => 0 });
    Test.assertEqual(v.baseTimer(), 100400);
    v.snapshot = new RdFakeInfo(100450, 300.6);   // 仅 50ms 之后又一次手动 Lap
    v.onTimerLap2({ :lapTrigger => 0 });
    Test.assertEqual(v.baseTimer(), 100450);
    Test.assertEqual(v.baseDistance(), 300.6);
    v.snapshot = new RdFakeInfo(100450, 300.6);   // 同一快照再来一次：幂等，状态不变
    v.onTimerLap2({ :lapTrigger => 0 });
    Test.assertEqual(v.baseTimer(), 100450);
    return true;
}

(:test)
function tInvalidBoundaryClearsOldLapThenRecoversAsPair(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.feed(new RdFakeInfo(130000, 400.0));
    Test.assertEqual(v.lapMs(), 30000);          // 边界前：旧圈数据正常累计
    // 边界快照距离未知：旧基线必须清空并进入待初始化，不能继续显示旧圈数据，也不能用 0 顶替
    v.snapshot = new RdFakeInfo(160000, null);
    v.onWorkoutStepComplete();
    Test.assert(v.isPending());
    rdAssertNull(v.baseTimer());
    rdAssertNull(v.baseDistance());
    rdAssertNull(v.lapMs());
    rdAssertNull(v.lapM());
    rdAssertNull(v.lapPace());
    // 后续快照时间有效、距离仍未知：不得把时间单独补齐
    v.feed(new RdFakeInfo(161000, null));
    Test.assert(v.isPending());
    rdAssertNull(v.baseTimer());
    // 下一份时间与距离同时有效的快照成对建立（计量限制：从这份快照开始累计）
    v.feed(new RdFakeInfo(162000, 460.0));
    Test.assert(!v.isPending());
    Test.assertEqual(v.baseTimer(), 162000);
    Test.assertEqual(v.baseDistance(), 460.0);
    v.feed(new RdFakeInfo(172000, 490.0));
    Test.assertEqual(v.lapMs(), 10000);
    Test.assertEqual(v.lapM(), 30.0);
    Test.assertEqual(v.lapPace(), 333);          // 单圈距离超过 20 m 门槛后恢复配速
    return true;
}

(:test)
function tNullOrBadSnapshotObjectsEnterPending(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.snapshot = null;                           // getActivityInfo() 返回 null
    v.onTimerLap();
    Test.assert(v.isPending());
    rdAssertNull(v.baseTimer());
    v.feed(new RdFakeInfo(110000, 310.0));
    Test.assert(!v.isPending());
    v.snapshot = new RdFakeInfo(-5, 100.0);      // 负数
    v.onTimerLap();
    Test.assert(v.isPending());
    v.feed(new RdFakeInfo(120000, 320.0));
    v.snapshot = new RdFakeInfo("x", 100.0);     // 非数值
    v.onTimerLap();
    Test.assert(v.isPending());
    v.feed(new RdFakeInfo(130000, 330.0));
    Test.assertEqual(v.baseTimer(), 130000);
    return true;
}

(:test)
function tZeroIsKnownValueNotMissing(logger) {
    var v = new RdTestView();
    v.snapshot = new RdFakeInfo(0, 0.0);         // 活动刚开始：0 是已知值
    v.onTimerLap();
    Test.assert(!v.isPending());
    Test.assertEqual(v.baseTimer(), 0);
    Test.assertEqual(v.baseDistance(), 0.0);
    return true;
}

(:test)
function tRealActivityInfoObjectIsAccepted(logger) {
    // 用 SDK 自带的 Activity.Info 类型走一遍 compute()，确认真实类型的字段读取没问题
    var v = new RdTestView();
    var info = new Activity.Info();
    info.timerTime = 5000;
    info.elapsedDistance = 20.0;
    info.currentHeartRate = 140;
    v.compute(info);
    Test.assert(!v.isPending());
    Test.assertEqual(v.baseTimer(), 5000);
    Test.assertEqual(v.baseDistance(), 20.0);
    Test.assertEqual(v.shownHr(), 140);
    return true;
}

// ═══════════════════════════════════════════════════════════
//  生命周期：暂停 / 恢复 / 停止后继续 / 重置 / 新活动
// ═══════════════════════════════════════════════════════════

(:test)
function tPauseResumeStopStartKeepCurrentLap(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.feed(new RdFakeInfo(130000, 400.0));
    var propBefore = v.propReads;
    var snapBefore = v.snapshotReads;
    v.snapshot = new RdFakeInfo(999999, 9999.0); // 若有人误读快照重置基线，下面的断言会失败
    v.onTimerPause();
    v.onTimerResume();
    v.onTimerStop();
    v.onTimerStart();                            // 停止后继续
    Test.assertEqual(v.baseTimer(), 100000);
    Test.assertEqual(v.baseDistance(), 300.0);
    Test.assert(!v.isPending());
    Test.assertEqual(v.snapshotReads, snapBefore); // 这些回调一次都没读过活动快照
    Test.assertEqual(v.propReads, propBefore + 1); // onTimerStart 刷新配置一次
    v.feed(new RdFakeInfo(160000, 480.0));
    Test.assertEqual(v.lapMs(), 60000);          // 单圈连续，没有归零
    return true;
}

(:test)
function tResetClearsActivityStateAndNewActivityRebaselines(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    v.feed(new RdFakeInfo(130000, 400.0));
    v.onTimerReset();
    Test.assert(v.isPending());
    rdAssertNull(v.baseTimer());
    rdAssertNull(v.baseDistance());
    rdAssertNull(v.shownTimer());
    rdAssertNull(v.lapMs());
    // 新活动：计时器回到 0 → 第一份有效快照成对建立（0 是已知值）
    v.feed(new RdFakeInfo(0, 0.0));
    Test.assert(!v.isPending());
    Test.assertEqual(v.baseTimer(), 0);
    v.feed(new RdFakeInfo(4000, 12.0));
    Test.assertEqual(v.lapMs(), 4000);
    return true;
}

// ═══════════════════════════════════════════════════════════
//  配置缓存
// ═══════════════════════════════════════════════════════════

(:test)
function tConfigIsNotReadEveryCompute(logger) {
    var v = new RdTestView();
    Test.assertEqual(v.propReads, 1);            // 初始化读取一次
    var zoneAtInit = v.zoneReads;
    Test.assert(zoneAtInit >= 1);
    var sportAtInit = v.sportReads;
    // 59 秒内每秒 compute 一次：属性与区间接口都不再被调用
    for (var i = 0; i < 59; i += 1) {
        v.clockMs += 1000;
        v.feed(new RdFakeInfo(i * 1000, i * 3.0));
    }
    Test.assertEqual(v.propReads, 1);
    Test.assertEqual(v.zoneReads, zoneAtInit);
    Test.assertEqual(v.sportReads, sportAtInit);
    // 第 60 秒：只刷新区间边界（属性不再读取）
    v.clockMs += 1000;
    v.feed(new RdFakeInfo(59000, 177.0));
    Test.assertEqual(v.propReads, 1);
    Test.assertEqual(v.zoneReads, zoneAtInit + 1);
    Test.assertEqual(v.sportReads, sportAtInit + 1);
    // 之后下一个 59 秒又不再读
    for (var j = 0; j < 59; j += 1) {
        v.clockMs += 1000;
        v.feed(new RdFakeInfo(60000 + j * 1000, 180.0 + j * 3.0));
    }
    Test.assertEqual(v.zoneReads, zoneAtInit + 1);
    // 周期刷新没有动单圈基线
    Test.assertEqual(v.baseTimer(), 0);
    return true;
}

(:test)
function tRealtimeHrAndZoneStillUpdateEveryCompute(logger) {
    var v = new RdTestView();
    var reads = v.zoneReads;
    var info = new RdFakeInfo(1000, 3.0);
    info.currentHeartRate = 135;
    v.clockMs += 1000;
    v.feed(info);
    Test.assertEqual(v.zoneReads, reads);        // 没有读配置
    Test.assertEqual(v.shownHr(), 135);          // 但实时心率照常更新
    info.currentHeartRate = 150;
    v.clockMs += 1000;
    v.feed(info);
    Test.assertEqual(v.shownHr(), 150);
    Test.assertEqual(v.zoneReads, reads);
    return true;
}

(:test)
function tConfigRefreshesImmediatelyOnStartAndSettingsChange(logger) {
    var v = rdViewWithBaseline(100000, 300.0);
    var props = v.propReads;
    var zoneReadsBefore = v.zoneReads;
    v.onTimerStart();                            // 活动开始：立即刷新配置
    Test.assertEqual(v.propReads, props + 1);
    Test.assert(v.zoneReads > zoneReadsBefore);
    Test.assertEqual(v.baseTimer(), 100000);     // 但不重置圈基线
    Test.assertEqual(v.baseDistance(), 300.0);

    v.maxHrProperty = 205;
    v.sportZones = [105, 125, 145, 165, 180, 195];
    v.reloadSettings();                          // 设置变化：立即生效
    Test.assertEqual(v.maxHr(), 205);
    Test.assertEqual(v.zoneAt(0), 105);
    Test.assertEqual(v.zoneAt(5), 195);
    Test.assertEqual(v.baseTimer(), 100000);     // 设置变化不影响当前圈
    Test.assertEqual(v.baseDistance(), 300.0);
    Test.assert(!v.isPending());
    return true;
}

(:test)
function tOutOfRangeMaxHrPropertyIsIgnored(logger) {
    var v = new RdTestView();
    Test.assertEqual(v.maxHr(), 180);
    v.maxHrProperty = 999;                       // 超出 120–230：沿用原兜底值
    v.reloadSettings();
    Test.assertEqual(v.maxHr(), 180);
    v.maxHrProperty = null;                      // 属性缺失：沿用
    v.reloadSettings();
    Test.assertEqual(v.maxHr(), 180);
    v.maxHrProperty = 190;
    v.reloadSettings();
    Test.assertEqual(v.maxHr(), 190);
    return true;
}

(:test)
function tTimerRollbackForcesZoneRefresh(logger) {
    var v = new RdTestView();
    v.clockMs = 5000000;
    v.feed(new RdFakeInfo(1000, 1.0));           // 距上次刷新很久 → 周期刷新，时间戳 = 5,000,000
    var afterPeriodic = v.zoneReads;
    v.clockMs = 100;                             // 计时器回退（now < 上次时间戳）
    v.feed(new RdFakeInfo(2000, 2.0));
    Test.assertEqual(v.zoneReads, afterPeriodic + 1);   // 按过期处理，立即刷新，不会永久沿用旧区间
    var afterRollback = v.zoneReads;
    v.clockMs = 1100;                            // 回退后重新计时：1 秒内不再读
    v.feed(new RdFakeInfo(3000, 3.0));
    Test.assertEqual(v.zoneReads, afterRollback);
    return true;
}

(:test)
function tNativeZoneChangeIsPickedUpWithoutSettingsCallback(logger) {
    // 原生运动配置变化没有触发应用 onSettingsChanged()：60 秒内的周期刷新兜底
    var v = new RdTestView();
    Test.assertEqual(v.zoneAt(0), 100);
    v.sportZones = [110, 130, 150, 170, 185, 200];
    v.clockMs += 30000;
    v.feed(new RdFakeInfo(30000, 90.0));
    Test.assertEqual(v.zoneAt(0), 100);          // 还没到 60 秒：仍是缓存
    v.clockMs += 30000;
    v.feed(new RdFakeInfo(60000, 180.0));
    Test.assertEqual(v.zoneAt(0), 110);          // 到 60 秒：边界已更新
    return true;
}

(:test)
function tInvalidZonesUseExistingFallback(logger) {
    var v = new RdTestView();
    // 运动区间无效（全 0）、通用区间有效 → 用通用区间
    v.sportZones = [0, 0, 0, 0, 0, 0];
    v.genericZones = [100, 120, 140, 160, 175, 190];
    v.reloadSettings();
    Test.assertEqual(v.zoneAt(0), 100);
    // 两者都无效 → null，沿用 %HRmax 兜底
    v.genericZones = [100, 100, 140, 160, 175, 190];
    v.reloadSettings();
    rdAssertNull(v.zones());
    // 运动区间恢复有效 → 只读一次运动区间就够，不再读通用区间
    v.sportZones = [100, 120, 140, 160, 175, 190];
    var before = v.zoneReads;
    v.reloadSettings();
    Test.assertEqual(v.zoneReads, before + 1);
    Test.assert(v.zones() != null);
    // 兜底路径可算出区间值（与 Metrics 一致）
    Test.assert(Metrics.hrZoneValueFromMax(135, 180) != null);
    return true;
}

// ═══════════════════════════════════════════════════════════
//  App 与 View 的接线
// ═══════════════════════════════════════════════════════════

(:test)
function tAppSettingsChangedReloadsTheViewCache(logger) {
    var app = new RdTestApp();
    var views = app.getInitialView() as Array<Object>;
    var view = app.testView;
    Test.assert(view != null);
    Test.assertEqual(views.size(), 1);
    Test.assert(views[0] == view);               // 交给系统的就是 App 持有的同一个 View
    view.feed(new RdFakeInfo(100000, 300.0));
    var props = view.propReads;
    view.maxHrProperty = 207;
    app.onSettingsChanged();                     // 不能只请求重绘：必须让 View 的配置缓存生效
    Test.assertEqual(view.propReads, props + 1);
    Test.assertEqual(view.maxHr(), 207);
    Test.assertEqual(view.baseTimer(), 100000);  // 不影响当前圈
    Test.assertEqual(view.baseDistance(), 300.0);
    return true;
}

(:test)
function tAppSettingsChangedBeforeViewExistsIsSafe(logger) {
    var app = new RdTestApp();
    app.onSettingsChanged();                     // View 还没创建：不得崩溃
    return true;
}
