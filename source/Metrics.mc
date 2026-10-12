import Toybox.Lang;

module Metrics {
    // Speed threshold (~0.20 m/s ≈ 83:20/km). Below this, treat as stationary/no GPS fix.
    const MIN_SPEED_MPS = 0.20;
    const MIN_LAP_DISTANCE_M = 20.0;
    const MAX_PACE_SEC = 3599;

    function paceSecondsFromSpeed(speedMps) {
        if (speedMps == null) {
            return null;
        }
        var speed = speedMps.toFloat();
        if (speed <= MIN_SPEED_MPS) {
            return null;
        }
        return (1000.0 / speed).toNumber();
    }

    function formatPace(secondsPerKm) {
        if (secondsPerKm == null) {
            return "--:--";
        }
        var total = secondsPerKm.toNumber();
        if (total <= 0 || total > MAX_PACE_SEC) {
            return "--:--";
        }
        var mins = (total / 60).toNumber();
        var secs = total % 60;
        return mins.format("%d") + ":" + secs.format("%02d");
    }

    function formatDurationMs(ms) {
        if (ms == null) {
            return "--:--";
        }
        var total = (ms.toNumber() / 1000).toNumber();
        if (total < 0) {
            return "--:--";
        }
        var hours = (total / 3600).toNumber();
        var mins = ((total % 3600) / 60).toNumber();
        var secs = total % 60;

        if (hours > 0) {
            return hours.format("%d") + ":" + mins.format("%02d") + ":" + secs.format("%02d");
        }
        return mins.format("%02d") + ":" + secs.format("%02d");
    }

    // 单圈时间：M:SS（如 5:12），分钟不补零，不用 05:12。
    function formatLapTimeMs(ms) {
        if (ms == null) {
            return "--";
        }
        var total = (ms.toNumber() / 1000).toNumber();
        if (total < 0) {
            return "--";
        }
        var mins = (total / 60).toNumber();
        var secs = total % 60;
        return mins.format("%d") + ":" + secs.format("%02d");
    }

    // 始终按公里、两位小数（如 0.85、1.20），不足 1000m 也不再输出 "850m"。
    function formatDistanceMeters(meters) {
        if (meters == null) {
            return "--";
        }
        var m = meters.toFloat();
        if (m < 0.0) {
            return "--";
        }
        return (m / 1000.0).format("%.2f");
    }

    // 始终按公里、两位小数（如 0.85、1.20），不用 "850m"。
    function formatDistanceKm(meters) {
        if (meters == null) {
            return "--";
        }
        var m = meters.toFloat();
        if (m < 0.0) {
            return "--";
        }
        return (m / 1000.0).format("%.2f");
    }

    function lapPaceSeconds(timerMs, distanceM, lapStartTimerMs, lapStartDistanceM) {
        if (timerMs == null || distanceM == null || lapStartTimerMs == null || lapStartDistanceM == null) {
            return null;
        }
        var dtMs = timerMs.toNumber() - lapStartTimerMs.toNumber();
        var ddM = distanceM.toFloat() - lapStartDistanceM.toFloat();
        if (dtMs <= 0 || ddM < MIN_LAP_DISTANCE_M) {
            return null;
        }
        // (ms → s) / (m → km) = sec/km
        return ((dtMs / 1000.0) / (ddM / 1000.0)).toNumber();
    }

    // 数值判定：Number / Long / Float / Double。null 与其他类型都不是数值。
    function isNumeric(value) {
        return (value instanceof Number) || (value instanceof Long)
            || (value instanceof Float) || (value instanceof Double);
    }

    // 有限数值：是数值，且不是 NaN / ±Infinity。
    // 不能靠 (x >= 0) 拒绝 NaN：模拟器 VM 实测 nan >= 0、nan <= 0 都为 true（>= 按 !(a < b) 实现）。
    // 这里用 (x - x) == 0：有限数相减得 0；NaN、±Infinity 相减得 NaN，与 0 比较为 false。
    function isFiniteNumber(value) {
        return isNumeric(value) && ((value - value) == 0);
    }

    // 单圈基线用的活动快照校验：时间（ms）与距离（m）必须在“同一份快照”里同时有效。
    // 有效 = 两者都是有限数值且不为负。null、非数值、负数、NaN、Infinity 一律视为未知，绝不当作 0；0 是已知值。
    function isValidLapSnapshot(timerMs, distanceM) {
        if (!isFiniteNumber(timerMs) || !isFiniteNumber(distanceM)) {
            return false;
        }
        return !(timerMs < 0) && !(distanceM < 0);
    }

    // Negative = ahead of target; positive = behind target.
    function pacerDeltaSeconds(timerMs, distanceM, targetPaceSecPerKm) {
        if (timerMs == null || distanceM == null || targetPaceSecPerKm == null) {
            return null;
        }
        var target = targetPaceSecPerKm.toNumber();
        if (target <= 0) {
            return null;
        }
        var dist = distanceM.toFloat();
        if (dist < MIN_LAP_DISTANCE_M) {
            return null;
        }
        var actualSec = timerMs.toNumber() / 1000.0;
        var expectedSec = (dist / 1000.0) * target;
        return (actualSec - expectedSec).toNumber();
    }

    function formatSignedSeconds(seconds) {
        if (seconds == null) {
            return "--:--";
        }
        var v = seconds.toNumber();
        var sign = "+";
        if (v < 0) {
            sign = "-";
            v = -v;
        }
        var mins = (v / 60).toNumber();
        var secs = v % 60;
        return sign + mins.format("%02d") + ":" + secs.format("%02d");
    }

    // Garmin 社区小数区间算法（对齐原生 Data Field）：
    // zones = [Z1min, Z1max, Z2max, Z3max, Z4max, Z5max]
    // Zone0: 30→Z1min → 0.x；Z1→1.x … Z5→5.x；≥Z5max → 6.0
    // 参考: https://forums.garmin.com/developer/connect-iq/f/discussion/405762/
    const HR_ZONE_ABS_MIN = 30;
    // 区间边界的宽松上限（bpm）：仅用于挡掉明显异常值，不是 Garmin 规范。
    const HR_ZONE_ABS_MAX = 300;

    // 校验手表用户心率区间边界：至少 6 个数值（[Z1min, Z1max, Z2max, Z3max, Z4max, Z5max]，多余项忽略），
    // 都 >= 0、严格递增、且不超过 HR_ZONE_ABS_MAX。校验失败的调用方应走现有兜底（%HRmax）。
    // 第一项允许为 0（不额外收紧 V5 原本接受的数据），但全 0 / 重复 / 递减都会因“严格递增”被拒绝。
    // NaN / Infinity 由 isFiniteNumber 拒绝（见其注释：不能靠 >= 比较）。
    function isValidHrZones(zones) {
        if (!(zones instanceof Array) || zones.size() < 6) {
            return false;
        }
        var prev = null;
        for (var i = 0; i < 6; i += 1) {
            var v = zones[i];
            if (!isFiniteNumber(v) || (v < 0) || (v > HR_ZONE_ABS_MAX)) {
                return false;
            }
            if (prev != null && !(v > prev)) {
                return false;
            }
            prev = v;
        }
        return true;
    }

    function hrZoneValue(hr, zones) {
        if (hr == null || zones == null || zones.size() < 6) {
            return null;
        }
        var h = hr.toFloat();
        var z5max = zones[5].toFloat();
        if (h < HR_ZONE_ABS_MIN.toFloat()) {
            h = HR_ZONE_ABS_MIN.toFloat();
        }
        if (h > z5max) {
            h = z5max;
        }

        var z = 0;
        while (z < 5 && h >= zones[z].toFloat()) {
            z++;
        }

        var lo = HR_ZONE_ABS_MIN.toFloat();
        if (z > 0) {
            lo = zones[z - 1].toFloat();
        }
        var hi = zones[z].toFloat();
        if (hi <= lo) {
            return z.toFloat();
        }
        return z.toFloat() + (h - lo) / (hi - lo);
    }

    // 小数区间 → 区间条整数区号 0–5（6.0 仍点亮 Z5）
    function hrZoneIndex(zoneValue) {
        if (zoneValue == null) {
            return 0;
        }
        var v = zoneValue.toFloat();
        if (v < 1.0) {
            return 0;
        }
        if (v >= 6.0) {
            return 5;
        }
        var z = v.toNumber();
        if (z < 1) {
            return 0;
        }
        if (z > 5) {
            return 5;
        }
        return z;
    }

    // 兜底：无用户区间时按 %HRmax 估边界，再走同一套小数算法。
    function hrZoneValueFromMax(hr, maxHr) {
        if (hr == null || maxHr == null) {
            return null;
        }
        var maxV = maxHr.toFloat();
        if (maxV <= 0.0) {
            return null;
        }
        var zones = [
            (0.50 * maxV).toNumber(),
            (0.60 * maxV).toNumber(),
            (0.70 * maxV).toNumber(),
            (0.80 * maxV).toNumber(),
            (0.90 * maxV).toNumber(),
            maxV.toNumber()
        ];
        return hrZoneValue(hr, zones);
    }

    // 兼容旧调用：返回整数区号。
    function hrZone(hr, maxHr) {
        return hrZoneIndex(hrZoneValueFromMax(hr, maxHr));
    }
}
