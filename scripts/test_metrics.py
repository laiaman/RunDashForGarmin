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
    return f"{mins}.{secs:02d}"


def format_distance_meters(meters):
    if meters is None:
        return "--"
    m = float(meters)
    if m < 0.0:
        return "--"
    if m < 1000.0:
        return f"{int(m)}m"
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
    check("lap time 5:12", format_lap_time_ms(312_000), "5.12")
    check("lap time 0", format_lap_time_ms(0), "0.00")
    check("lap time 65s", format_lap_time_ms(65_000), "1.05")
    check("lap time null", format_lap_time_ms(None), "--")

    # Distance
    check("dist 0", format_distance_meters(0), "0m")
    check("dist 999", format_distance_meters(999), "999m")
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

    # Floating cadence-like display path: toNumber truncate semantics
    check("cadence float trunc", int(float(87.6)), 87)

    print(f"PASS: {sys.argv[0]} — all deterministic Metrics mirrors OK")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
