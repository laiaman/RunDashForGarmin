#!/usr/bin/env python3
"""配置缓存与心率区间边界 60 秒刷新策略的确定性调度模型测试。

镜像 RunDash970View 的 loadSettings / refreshHrZones / refreshHrZonesIfDue，并与 V5 旧行为
（compute() 每次都 loadSettings()）对比“配置接口调用次数”。

只证明：调度逻辑与调用次数；不证明耗电。电池收益未经实测，一律视为未知。
60 秒是本项目的初始策略，不是 Garmin 通用标准；真实时钟/原生运动配置变化的送达仍需模拟器与真机验证。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_metrics import hr_zone_value, hr_zone_value_from_max, is_valid_hr_zones  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
VIEW = ROOT / "source" / "RunDash970View.mc"

_m = re.search(r"\bSETTINGS_ZONE_REFRESH_MS\s*=\s*(\d+)\s*;", VIEW.read_text(encoding="utf-8"))
assert _m, "SETTINGS_ZONE_REFRESH_MS not found in source"
REFRESH_MS = int(_m.group(1))

GOOD = [100, 120, 140, 160, 175, 190]


class Platform:
    """外部接口：只负责计数并返回当前“手表里的配置”。"""

    def __init__(self) -> None:
        self.clock_ms = 1_000_000
        self.max_hr_property = 180
        self.sport_zones = list(GOOD)
        self.generic_zones = None
        self.property_reads = 0
        self.sport_reads = 0
        self.zone_reads = 0

    def read_max_hr(self):
        self.property_reads += 1
        return self.max_hr_property

    def read_sport(self):
        self.sport_reads += 1
        return 1

    def read_zones(self, generic: bool):
        self.zone_reads += 1
        return self.generic_zones if generic else self.sport_zones

    @property
    def interface_calls(self) -> int:
        return self.property_reads + self.sport_reads + self.zone_reads


class OldV5View:
    """V5 旧行为：compute() 每次都读 Properties / getCurrentSport / getHeartRateZones。"""

    def __init__(self, p: Platform) -> None:
        self.p = p
        self.zones = None
        self.max_hr = 180
        self.load_settings()

    def load_settings(self) -> None:
        h = self.p.read_max_hr()
        if h is not None and 120 <= int(h) <= 230:
            self.max_hr = int(h)
        self.p.read_sport()
        z = self.p.read_zones(False)
        if z is None or len(z) < 6:
            z = self.p.read_zones(True)
        self.zones = z if z is not None and len(z) >= 6 else None

    def compute(self) -> None:
        self.load_settings()


class NewView:
    """新行为：初始化/活动开始/设置变化立即刷新；每 REFRESH_MS 仅刷新区间边界；计时器回退按过期处理。"""

    def __init__(self, p: Platform) -> None:
        self.p = p
        self.zones = None
        self.max_hr = 180
        self.stamp = None
        self.reasons: list[str] = []
        self.load_settings("INIT")

    def load_settings(self, reason: str) -> None:
        h = self.p.read_max_hr()
        if h is not None and 120 <= int(h) <= 230:
            self.max_hr = int(h)
        self.refresh_zones(reason)

    def refresh_zones(self, reason: str) -> None:
        self.stamp = self.p.clock_ms  # 先打时间戳：读取失败也不会退化成每帧重试
        self.reasons.append(reason)
        self.p.read_sport()
        z = self.p.read_zones(False)
        if not is_valid_hr_zones(z):
            z = self.p.read_zones(True)
        self.zones = z if is_valid_hr_zones(z) else None

    def refresh_if_due(self) -> None:
        if self.stamp is None:
            self.refresh_zones("INIT")
            return
        age = self.p.clock_ms - self.stamp
        if age >= 0:
            if age < REFRESH_MS:
                return
            self.refresh_zones("PERIODIC")
        else:
            self.refresh_zones("ROLLBACK")

    def compute(self) -> None:
        self.refresh_if_due()

    def on_timer_start(self) -> None:
        self.load_settings("START")

    def on_settings_changed(self) -> None:
        self.load_settings("SETTINGS")


def tick(view, p: Platform, seconds: int, step_s: int = 1) -> None:
    for _ in range(0, seconds, step_s):
        p.clock_ms += step_s * 1000
        view.compute()


def check_old_v5_reads_config_every_compute() -> None:
    p = Platform()
    v = OldV5View(p)
    before = p.interface_calls
    tick(v, p, 3600)
    assert p.property_reads == 1 + 3600
    assert p.interface_calls - before == 3600 * 3  # 每次 Properties + getCurrentSport + getHeartRateZones


def check_new_view_one_hour_call_counts() -> None:
    p = Platform()
    v = NewView(p)
    assert (p.property_reads, p.sport_reads, p.zone_reads) == (1, 1, 1)  # 初始化各读一次
    tick(v, p, 3600)  # 1 Hz，1 小时
    periodic = 3600 // (REFRESH_MS // 1000)
    assert p.property_reads == 1, "Properties 不再随 compute 读取"
    assert p.zone_reads == 1 + periodic and p.sport_reads == 1 + periodic
    assert v.reasons.count("PERIODIC") == periodic
    old = Platform()
    ov = OldV5View(old)
    tick(ov, old, 3600)
    print(
        f"  1 小时 @1Hz 配置接口调用次数：V5 旧版 {old.interface_calls}，新版 {p.interface_calls}"
        f"（仅调用次数对比，不代表耗电收益；电池收益未知）"
    )
    assert p.interface_calls < old.interface_calls / 50


def check_no_reads_inside_refresh_window() -> None:
    p = Platform()
    v = NewView(p)
    reads = p.zone_reads
    tick(v, p, REFRESH_MS // 1000 - 1)  # 59 秒内
    assert p.zone_reads == reads and p.property_reads == 1
    tick(v, p, 1)  # 第 60 秒
    assert p.zone_reads == reads + 1 and p.property_reads == 1


def check_immediate_refresh_on_start_and_settings() -> None:
    p = Platform()
    v = NewView(p)
    tick(v, p, 5)
    p.max_hr_property = 200
    p.sport_zones = [105, 125, 145, 165, 180, 195]
    v.on_settings_changed()  # 应用设置变化：立即生效
    assert v.max_hr == 200 and v.zones[0] == 105
    p.sport_zones = [110, 130, 150, 170, 185, 200]
    v.on_timer_start()  # 活动开始：立即刷新
    assert v.zones[0] == 110
    assert v.reasons[-2:] == ["SETTINGS", "START"]
    # 立即刷新会重置 60 秒计时：之后再过 59 秒仍不重复读
    reads = p.zone_reads
    tick(v, p, REFRESH_MS // 1000 - 1)
    assert p.zone_reads == reads


def check_native_sport_change_picked_up_within_one_period() -> None:
    p = Platform()
    v = NewView(p)
    p.sport_zones = [110, 130, 150, 170, 185, 200]  # 原生配置变化，没有 onSettingsChanged
    tick(v, p, REFRESH_MS // 1000 - 1)
    assert v.zones[0] == 100  # 周期内仍是缓存
    tick(v, p, 1)
    assert v.zones[0] == 110  # 一个周期内追上，不会永久过期


def check_timer_rollback_refreshes() -> None:
    p = Platform()
    v = NewView(p)
    p.clock_ms = 5_000_000
    v.compute()  # 距上次很久：周期刷新
    reads = p.zone_reads
    p.clock_ms = 100  # 计时器回退
    v.compute()
    assert p.zone_reads == reads + 1 and v.reasons[-1] == "ROLLBACK"
    p.clock_ms = 1_100  # 回退后重新计时
    v.compute()
    assert p.zone_reads == reads + 1


def check_invalid_zones_use_fallback() -> None:
    p = Platform()
    v = NewView(p)
    p.sport_zones = [0, 0, 0, 0, 0, 0]
    p.generic_zones = list(GOOD)
    v.on_settings_changed()
    assert v.zones == GOOD  # 运动区间无效 → 通用区间
    p.generic_zones = [100, 100, 140, 160, 175, 190]
    v.on_settings_changed()
    assert v.zones is None  # 都无效 → 走 %HRmax 兜底
    assert hr_zone_value_from_max(135, v.max_hr) is not None
    p.sport_zones = list(GOOD)
    reads = p.zone_reads
    v.on_settings_changed()
    assert v.zones == GOOD and p.zone_reads == reads + 1  # 有效时只读一次，不再读通用区间


def check_failed_read_does_not_retry_every_frame() -> None:
    p = Platform()
    v = NewView(p)
    p.sport_zones = None
    p.generic_zones = None
    tick(v, p, REFRESH_MS // 1000)  # 到点刷新，结果无效 → zones None
    assert v.zones is None
    reads = p.zone_reads
    tick(v, p, REFRESH_MS // 1000 - 1)
    assert p.zone_reads == reads, "失败后也要等下一个周期，不能每帧重试"


def check_realtime_zone_display_not_cached() -> None:
    """配置边界可缓存，但实时心率与区间显示值每次 compute/绘制都用当前心率重新计算。"""
    p = Platform()
    v = NewView(p)
    values = []
    for hr in (100, 120, 140, 160, 175):
        p.clock_ms += 1000
        v.compute()
        values.append(round(hr_zone_value(hr, v.zones), 1))
    assert values == [1.0, 2.0, 3.0, 4.0, 5.0]
    assert p.zone_reads == 1  # 期间没有再读配置


def main() -> int:
    checks = [
        check_old_v5_reads_config_every_compute,
        check_new_view_one_hour_call_counts,
        check_no_reads_inside_refresh_window,
        check_immediate_refresh_on_start_and_settings,
        check_native_sport_change_picked_up_within_one_period,
        check_timer_rollback_refreshes,
        check_invalid_zones_use_fallback,
        check_failed_read_does_not_retry_every_frame,
        check_realtime_zone_display_not_cached,
    ]
    for fn in checks:
        try:
            fn()
        except AssertionError as exc:
            print(f"FAIL: {fn.__name__}: {exc}", file=sys.stderr)
            return 1
    print(f"PASS: {Path(__file__).name} — {len(checks)} checks OK（调度/调用次数模型；不证明耗电收益）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
