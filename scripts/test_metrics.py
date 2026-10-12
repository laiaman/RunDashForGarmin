#!/usr/bin/env python3
"""Deterministic mirrors of source/Metrics.mc formulas.

Runnable without Connect IQ SDK. Does not prove monkeyc compile or simulator behavior.
"""
from __future__ import annotations

import sys

MIN_SPEED_MPS = 0.20
MIN_LAP_DISTANCE_M = 20.0
MAX_PACE_SEC = 3599


def pace_seconds_from_speed(speed_mps):
    if speed_mps is None:
        return None
    speed = float(speed_mps)
    if speed <= MIN_SPEED_MPS:
        return None
    return int(1000.0 / speed)


def format_pace(seconds_per_km):
    if seconds_per_km is None:
        return "--:--"
    total = int(seconds_per_km)
    if total <= 0 or total > MAX_PACE_SEC:
        return "--:--"
    mins = total // 60
    secs = total % 60
    return f"{mins}:{secs:02d}"


def format_duration_ms(ms):
    if ms is None:
        return "--:--"
    total = int(ms) // 1000
    if total < 0:
        return "--:--"
    hours = total // 3600
    mins = (total % 3600) // 60
    secs = total % 60
    if hours > 0:
        return f"{hours}:{mins:02d}:{secs:02d}"
    return f"{mins:02d}:{secs:02d}"


def format_lap_time_ms(ms):
    if ms is None:
        return "--"
    total = int(ms) // 1000
    if total < 0:
        return "--"
    mins = total // 60
    secs = total % 60
    return f"{mins}:{secs:02d}"


def format_distance_meters(meters):
    if meters is None:
        return "--"
    m = float(meters)
    if m < 0.0:
        return "--"
    return f"{m / 1000.0:.2f}"


def format_distance_km(meters):
    if meters is None:
        return "--"
    m = float(meters)
    if m < 0.0:
        return "--"
    return f"{m / 1000.0:.2f}"


def lap_pace_seconds(timer_ms, distance_m, lap_start_timer_ms, lap_start_distance_m):
    if None in (timer_ms, distance_m, lap_start_timer_ms, lap_start_distance_m):
        return None
    dt_ms = int(timer_ms) - int(lap_start_timer_ms)
    dd_m = float(distance_m) - float(lap_start_distance_m)
    if dt_ms <= 0 or dd_m < MIN_LAP_DISTANCE_M:
        return None
    return int((dt_ms / 1000.0) / (dd_m / 1000.0))


def pacer_delta_seconds(timer_ms, distance_m, target_pace_sec_per_km):
    if None in (timer_ms, distance_m, target_pace_sec_per_km):
        return None
    target = int(target_pace_sec_per_km)
    if target <= 0:
        return None
    dist = float(distance_m)
    if dist < MIN_LAP_DISTANCE_M:
        return None
    actual_sec = int(timer_ms) / 1000.0
    expected_sec = (dist / 1000.0) * target
    return int(actual_sec - expected_sec)


def format_signed_seconds(seconds):
    if seconds is None:
        return "--:--"
    v = int(seconds)
    sign = "+"
    if v < 0:
        sign = "-"
        v = -v
    mins = v // 60
    secs = v % 60
    return f"{sign}{mins:02d}:{secs:02d}"


HR_ZONE_ABS_MAX = 300


def is_numeric(value):
    """镜像 Metrics.isNumeric：Number/Long/Float/Double；null 与其他类型（含 Boolean）都不是数值。"""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_finite_number(value):
    """镜像 Metrics.isFiniteNumber：数值且不是 NaN/±Infinity。

    模拟器 VM 实测 nan >= 0、nan <= 0 都为 true（>= 按 !(a < b) 实现），所以 Monkey C 里不能靠 (x >= 0)
    拒绝 NaN，改用 (x - x) == 0：有限数得 0；NaN、±Infinity 得 NaN，与 0 比较为 false。
    """
    return is_numeric(value) and ((value - value) == 0)


def vm_ge(a, b):
    """模拟器 VM 实测的 >= 语义：!(a < b)（NaN 时为 True）。仅用于证明“朴素写法会放过 NaN”。"""
    return not (a < b)


def is_valid_lap_snapshot(timer_ms, distance_m):
    """镜像 Metrics.isValidLapSnapshot：时间/距离同一份快照里都是有限数值且不为负；0 是已知值。"""
    if not is_finite_number(timer_ms) or not is_finite_number(distance_m):
        return False
    return not (timer_ms < 0) and not (distance_m < 0)


def is_valid_hr_zones(zones):
    """镜像 Metrics.isValidHrZones：至少 6 个有限数值，都 >= 0、<= 300、严格递增；多余项忽略。"""
    if not isinstance(zones, (list, tuple)) or len(zones) < 6:
        return False
    prev = None
    for i in range(6):
        v = zones[i]
        if not is_finite_number(v) or v < 0 or v > HR_ZONE_ABS_MAX:
            return False
        if prev is not None and not (v > prev):
            return False
        prev = v
    return True


def hr_zone_value(hr, zones):
    if hr is None or zones is None or len(zones) < 6:
        return None
    h = float(hr)
    abs_min = 30.0
    z5max = float(zones[5])
    if h < abs_min:
        h = abs_min
    if h > z5max:
        h = z5max
    z = 0
    while z < 5 and h >= float(zones[z]):
        z += 1
    lo = abs_min if z == 0 else float(zones[z - 1])
    hi = float(zones[z])
    if hi <= lo:
        return float(z)
    return z + (h - lo) / (hi - lo)


def hr_zone_index(zone_value):
    if zone_value is None:
        return 0
    v = float(zone_value)
    if v < 1.0:
        return 0
    if v >= 6.0:
        return 5
    z = int(v)
    if z < 1:
        return 0
    if z > 5:
        return 5
    return z


def hr_zone_value_from_max(hr, max_hr):
    if hr is None or max_hr is None:
        return None
    max_v = float(max_hr)
    if max_v <= 0.0:
        return None
    zones = [
        int(0.50 * max_v),
        int(0.60 * max_v),
        int(0.70 * max_v),
        int(0.80 * max_v),
        int(0.90 * max_v),
        int(max_v),
    ]
    return hr_zone_value(hr, zones)


def hr_zone(hr, max_hr):
    return hr_zone_index(hr_zone_value_from_max(hr, max_hr))


def zone_pill_text(zone_value):
    """区间胶囊文字：截断（不四舍五入）到 1 位小数，上限 6.0，无心率为 -.-。

    镜像 v4 简报约定：((v * 10).toNumber() / 10.0).format("%.1f")。
    """
    if zone_value is None:
        return "-.-"
    v = float(zone_value)
    if v > 6.0:
        v = 6.0
    return f"{int(v * 10) / 10.0:.1f}"


def check(name, got, expected):
    if got != expected:
        raise AssertionError(f"{name}: got {got!r}, expected {expected!r}")


def main() -> int:
    # Pace from speed: 4:08/km = 248 s/km → speed = 1000/248 m/s
    speed_408 = 1000.0 / 248.0
    check("pace 4:08", pace_seconds_from_speed(speed_408), 248)
    check("format 4:08", format_pace(248), "4:08")
    check("pace null", pace_seconds_from_speed(None), None)
    check("pace zero", pace_seconds_from_speed(0.0), None)
    check("pace stationary", pace_seconds_from_speed(0.20), None)
    check("format invalid", format_pace(0), "--:--")
    check("format huge", format_pace(4000), "--:--")

    # Duration
    check("dur 0", format_duration_ms(0), "00:00")
    check("dur 59s", format_duration_ms(59_000), "00:59")
    check("dur 61min", format_duration_ms(3_661_000), "1:01:01")
    check("dur null", format_duration_ms(None), "--:--")
    check("lap time 5:12", format_lap_time_ms(312_000), "5:12")
    check("lap time 0", format_lap_time_ms(0), "0:00")
    check("lap time 65s", format_lap_time_ms(65_000), "1:05")
    check("lap time null", format_lap_time_ms(None), "--")

    # Distance
    check("dist 0", format_distance_meters(0), "0.00")
    check("dist 850", format_distance_meters(850), "0.85")
    check("dist 999", format_distance_meters(999), "1.00")
    check("dist 1000", format_distance_meters(1000), "1.00")
    check("dist 10k", format_distance_meters(10_000), "10.00")
    check("dist marathon", format_distance_meters(42_195), "42.20")
    check("dist null", format_distance_meters(None), "--")
    check("dist neg", format_distance_meters(-1), "--")
    check("km 0", format_distance_km(0), "0.00")
    check("km 850m", format_distance_km(850), "0.85")
    check("km 1200", format_distance_km(1200), "1.20")
    check("km null", format_distance_km(None), "--")

    # Lap pace: 1 km in 4:08 → 248 s/km
    check(
        "lap pace",
        lap_pace_seconds(248_000, 1000.0, 0, 0.0),
        248,
    )
    check("lap pace short", lap_pace_seconds(10_000, 10.0, 0, 0.0), None)
    check("lap pace null", lap_pace_seconds(None, 1000.0, 0, 0.0), None)
    # After lap reset at 1000m / 248s, next 1000m in 250s → 250 s/km
    check(
        "lap pace after reset",
        lap_pace_seconds(498_000, 2000.0, 248_000, 1000.0),
        250,
    )

    # Pacer: target 300 s/km, ran 1 km in 280 s → ahead by 20 s → -20
    check("pacer ahead", pacer_delta_seconds(280_000, 1000.0, 300), -20)
    check("pacer behind", pacer_delta_seconds(320_000, 1000.0, 300), 20)
    check("pacer short", pacer_delta_seconds(5_000, 10.0, 300), None)
    check("pacer bad target", pacer_delta_seconds(280_000, 1000.0, 0), None)
    check("signed ahead", format_signed_seconds(-20), "-00:20")
    check("signed behind", format_signed_seconds(75), "+01:15")

    # HR zones — Garmin community decimal algorithm
    # sample: Z1min=100, Z1max=120, Z2=140, Z3=160, Z4=175, Z5=190
    sample = [100, 120, 140, 160, 175, 190]
    check("z null", hr_zone_value(None, sample), None)
    # Zone 0: (62-30)/(100-30) ≈ 0.457 → 0.5 rounded later; exact:
    check("z0 mid", round(hr_zone_value(62, sample), 1), 0.5)
    check("z1 start", round(hr_zone_value(100, sample), 1), 1.0)
    check("z1 mid", round(hr_zone_value(110, sample), 1), 1.5)
    check("z2 start", round(hr_zone_value(120, sample), 1), 2.0)
    check("z2 mid", round(hr_zone_value(130, sample), 1), 2.5)
    check("z5 mid", round(hr_zone_value(182, sample), 1), 5.5)
    check("z5 max", round(hr_zone_value(190, sample), 1), 6.0)
    check("z5 over", round(hr_zone_value(200, sample), 1), 6.0)
    check("idx 0.5", hr_zone_index(0.5), 0)
    check("idx 1.5", hr_zone_index(1.5), 1)
    check("idx 2.4", hr_zone_index(2.4), 2)
    check("idx 6.0", hr_zone_index(6.0), 5)
    check("fallback z3", hr_zone(135, 180), 3)
    check("fallback bad max", hr_zone(150, 0), 0)

    # Zone pill text: truncate to 1 decimal (no rounding), cap at 6.0, no HR -> -.-
    check("pill 2.97", zone_pill_text(2.97), "2.9")
    check("pill 6.4", zone_pill_text(6.4), "6.0")
    check("pill 6.0", zone_pill_text(6.0), "6.0")
    check("pill 1.0", zone_pill_text(1.0), "1.0")
    check("pill 3.05", zone_pill_text(3.05), "3.0")
    check("pill null", zone_pill_text(None), "-.-")
    check("pill from hr", zone_pill_text(hr_zone_value(130, sample)), "2.5")

    # Floating cadence-like display path: toNumber truncate semantics
    check("cadence float trunc", int(float(87.6)), 87)

    # 单圈快照校验：时间与距离必须在“同一份快照”里同时有效；未知值不是 0
    nan = float("nan")
    inf = float("inf")
    check("snap ok", is_valid_lap_snapshot(123_456, 987.5), True)
    check("snap zero is known", is_valid_lap_snapshot(0, 0.0), True)
    check("snap int distance", is_valid_lap_snapshot(5, 0), True)
    check("snap null timer", is_valid_lap_snapshot(None, 10.0), False)
    check("snap null distance", is_valid_lap_snapshot(10, None), False)
    check("snap both null", is_valid_lap_snapshot(None, None), False)
    check("snap neg timer", is_valid_lap_snapshot(-1, 10.0), False)
    check("snap neg distance", is_valid_lap_snapshot(10, -0.5), False)
    check("snap str", is_valid_lap_snapshot("12", 10.0), False)
    check("snap bool", is_valid_lap_snapshot(True, 10.0), False)
    check("snap nan timer", is_valid_lap_snapshot(nan, 10.0), False)
    check("snap nan distance", is_valid_lap_snapshot(10, nan), False)
    check("snap inf", is_valid_lap_snapshot(10, inf), False)
    check("snap -inf", is_valid_lap_snapshot(-inf, 10.0), False)
    # 朴素的 (x >= 0) 在 VM 语义下会放过 NaN —— 这正是要用有限性检查的原因
    check("vm nan >= 0 passes naive check", vm_ge(nan, 0), True)
    check("finite check rejects nan", is_finite_number(nan), False)
    check("finite check rejects inf", is_finite_number(inf), False)
    check("finite check accepts big", is_finite_number(2_000_000_000), True)

    # 心率区间边界校验：无效时调用方走现有兜底（%HRmax）
    check("zones ok", is_valid_hr_zones([100, 120, 140, 160, 175, 190]), True)
    check("zones extra ignored", is_valid_hr_zones([100, 120, 140, 160, 175, 190, 200]), True)
    check("zones first zero ok", is_valid_hr_zones([0, 120, 140, 160, 175, 190]), True)
    check("zones null", is_valid_hr_zones(None), False)
    check("zones str", is_valid_hr_zones("abc"), False)
    check("zones short", is_valid_hr_zones([100, 120, 140, 160, 175]), False)
    check("zones all zero", is_valid_hr_zones([0, 0, 0, 0, 0, 0]), False)
    check("zones zero mid", is_valid_hr_zones([100, 0, 140, 160, 175, 190]), False)
    check("zones negative", is_valid_hr_zones([-5, 120, 140, 160, 175, 190]), False)
    check("zones equal", is_valid_hr_zones([100, 120, 120, 160, 175, 190]), False)
    check("zones descending", is_valid_hr_zones([100, 120, 110, 160, 175, 190]), False)
    check("zones too high", is_valid_hr_zones([100, 120, 140, 160, 175, 301]), False)
    check("zones null item", is_valid_hr_zones([100, 120, None, 160, 175, 190]), False)
    check("zones str item", is_valid_hr_zones(["100", 120, 140, 160, 175, 190]), False)
    check("zones nan item", is_valid_hr_zones([nan, 120, 140, 160, 175, 190]), False)
    check("zones nan mid", is_valid_hr_zones([100, 120, nan, 160, 175, 190]), False)
    check("zones inf item", is_valid_hr_zones([100, 120, 140, 160, 175, inf]), False)

    print(f"PASS: {sys.argv[0]} — all deterministic Metrics mirrors OK")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
