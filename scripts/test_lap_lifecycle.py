#!/usr/bin/env python3
"""单圈（Lap）基线的确定性模型测试 + 源码结构静态检查。

两部分：
  1. LapModel：镜像 RunDash970View 的单圈状态机（成对快照基线 / 待初始化 / 幂等 / 无冷却），
     覆盖手动 Lap、自动 Lap、训练步骤完成、暂停/恢复/停止后继续、重置/新活动、无效快照与恢复、重复通知、
     连续手动 Lap、设置变化不影响当前圈。
  2. 静态检查：直接解析 source/*.mc，确认关键结构没被改坏（回调是否存在、onTimerLap2 是否仍返回 true、
     onTimerStart 是否不碰单圈基线、compute() 里是否没有配置/快照读取、事件日志是否默认关闭且全部受开关保护、
     App 是否真正刷新 View 的配置缓存）。

这只是模型/静态测试，不是真机或 Garmin 模拟器测试：
  - 它不能证明 Monkey C 回调真的被系统送达（尤其是 onWorkoutStepComplete 在真机上是否同时触发 Lap 回调及其顺序）；
  - Monkey C 逻辑本身由 tests/RunDash970Tests.mc 在模拟器 VM 里执行（scripts/run-unit-tests.sh）；
  - 回调送达与真机行为见 MANUAL_VALIDATION.md 的事件日志验收清单。
"""
from __future__ import annotations

import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_metrics import MIN_LAP_DISTANCE_M, is_valid_lap_snapshot  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
VIEW = ROOT / "source" / "RunDash970View.mc"
APP = ROOT / "source" / "RunDash970App.mc"
METRICS = ROOT / "source" / "Metrics.mc"

NAN = float("nan")


# ══════════════════════════════════════════════════════════════
#  1. 单圈状态机模型（镜像 RunDash970View）
# ══════════════════════════════════════════════════════════════
@dataclass
class Snap:
    """一次 Activity.getActivityInfo() 的结果（None 字段 = 未知）。"""

    timer_ms: object = None
    distance_m: object = None


class LapModel:
    def __init__(self, device: "Device") -> None:
        self.device = device
        self.base_t = None
        self.base_d = None
        self.pending = True
        self.timer = None  # compute() 最近一次的显示值
        self.distance = None
        self.paused = False
        self.settings_loads = 0
        self.update_baseline()  # 对应 initialize()：updateLapBaseline("INIT")

    # —— 基线（对应 setLapBaselineIfValid / clearLapBaseline / updateLapBaseline）——
    def set_if_valid(self, t, d) -> bool:
        if not is_valid_lap_snapshot(t, d):
            return False
        self.base_t, self.base_d, self.pending = t, d, False
        return True

    def clear_baseline(self) -> None:
        self.base_t = self.base_d = None
        self.pending = True

    def update_baseline(self) -> None:
        snap = self.device.snapshot  # 一次只读一份快照
        t = d = None
        if snap is not None:
            t, d = snap.timer_ms, snap.distance_m
        if not self.set_if_valid(t, d):
            self.clear_baseline()

    # —— DataField 回调 ——
    def compute(self, t, d) -> None:
        self.timer, self.distance = t, d
        if self.pending:
            self.set_if_valid(self.timer, self.distance)

    def on_timer_lap2(self, trigger=0) -> bool:
        self.update_baseline()
        return True

    def on_timer_lap(self) -> None:
        self.update_baseline()

    def on_workout_step_complete(self) -> None:
        self.update_baseline()

    def on_timer_start(self) -> None:
        self.paused = False
        self.settings_loads += 1  # loadSettings("START")：刷新配置，不碰单圈基线

    def on_timer_pause(self) -> None:
        self.paused = True

    def on_timer_resume(self) -> None:
        self.paused = False

    def on_timer_stop(self) -> None:
        self.paused = True

    def on_timer_reset(self) -> None:
        self.timer = self.distance = None
        self.clear_baseline()
        self.paused = False

    def reload_settings(self) -> None:
        self.settings_loads += 1  # 应用设置变化：刷新配置，不碰单圈基线

    # —— 显示值（公式同 drawFullScreen970）——
    def lap_time_ms(self):
        if self.timer is None or self.base_t is None:
            return None
        return max(int(self.timer) - int(self.base_t), 0)

    def lap_distance_m(self):
        if self.distance is None or self.base_d is None:
            return None
        return max(float(self.distance) - float(self.base_d), 0.0)

    def lap_pace(self):
        if None in (self.timer, self.distance, self.base_t, self.base_d):
            return None
        dt = int(self.timer) - int(self.base_t)
        dd = float(self.distance) - float(self.base_d)
        if dt <= 0 or dd < MIN_LAP_DISTANCE_M:
            return None
        return int((dt / 1000.0) / (dd / 1000.0))


class Device:
    """模拟设备：持有“此刻 Activity.getActivityInfo() 会返回什么”。"""

    def __init__(self) -> None:
        self.snapshot: Snap | None = None

    def at(self, t, d) -> None:
        self.snapshot = Snap(t, d)


def running(t=100_000, d=300.0):
    dev = Device()
    dev.at(t, d)
    model = LapModel(dev)
    model.compute(t, d)
    return dev, model


# ══════════════════════════════════════════════════════════════
#  模型行为检查
# ══════════════════════════════════════════════════════════════
def check_paired_baseline_from_one_snapshot() -> None:
    dev = Device()  # 构造时无快照 → 待初始化
    m = LapModel(dev)
    assert m.pending and m.base_t is None and m.base_d is None
    m.compute(1_000, None)  # 距离未知：不能单独补时间，也不能当 0
    m.compute(2_000, None)
    assert m.pending and m.base_t is None and m.base_d is None
    m.compute(3_000, 12.5)  # 同一份快照里都有效 → 成对建立
    assert (m.base_t, m.base_d, m.pending) == (3_000, 12.5, False)


def check_manual_and_auto_lap_reset() -> None:
    dev, m = running()
    for trigger, t, d in [(0, 160_000, 450.0), (1, 220_000, 600.0), (2, 280_000, 760.0)]:
        dev.at(t, d)
        assert m.on_timer_lap2(trigger) is True  # onTimerLap2 保持返回 true
        assert (m.base_t, m.base_d) == (t, d)
    dev.at(340_000, 900.0)
    m.on_timer_lap()  # 旧回调同一入口
    assert (m.base_t, m.base_d) == (340_000, 900.0)


def check_workout_step_complete_resets_lap() -> None:
    dev, m = running(100_000, 300.0)
    m.compute(130_000, 400.0)
    assert m.lap_time_ms() == 30_000 and m.lap_distance_m() == 100.0
    dev.at(160_000, 450.0)
    m.compute(160_000, 450.0)
    m.on_workout_step_complete()  # 训练步骤完成（按 Lap 提前完成 / 按时间或距离自动完成）
    assert (m.base_t, m.base_d) == (160_000, 450.0)
    m.compute(190_000, 520.0)  # 新圈下一次有效显示：时间/距离都从新边界累计
    assert m.lap_time_ms() == 30_000
    assert abs(m.lap_distance_m() - 70.0) < 1e-9
    assert m.lap_pace() == int(30.0 / 0.07)  # 428
    assert m.timer == 190_000 and m.distance == 520.0  # 全程时间/距离连续，不受圈事件影响


def check_total_time_distance_unaffected_by_lap_events() -> None:
    dev, m = running(100_000, 300.0)
    m.compute(150_000, 420.0)
    before = (m.timer, m.distance)
    dev.at(150_000, 420.0)
    m.on_workout_step_complete()
    m.on_timer_lap2(0)
    m.on_timer_lap()
    assert (m.timer, m.distance) == before


def check_duplicate_notifications_same_snapshot_idempotent() -> None:
    """同一份有效快照上，STEP / LAP2 / LAP 以任意顺序、任意次数通知，结果相同。"""
    orders = [
        ("step",),
        ("step", "lap2"),
        ("lap2", "step"),
        ("step", "lap"),
        ("lap", "step"),
        ("step", "lap2", "lap", "step"),
        ("lap2", "lap", "lap2"),
    ]
    results = set()
    for order in orders:
        dev, m = running(100_000, 300.0)
        dev.at(160_000, 450.0)
        for ev in order:
            {"step": m.on_workout_step_complete, "lap2": m.on_timer_lap2, "lap": m.on_timer_lap}[ev]()
        m.compute(165_000, 470.0)
        results.add((m.base_t, m.base_d, m.pending, m.lap_time_ms(), m.lap_distance_m(), m.lap_pace()))
    assert len(results) == 1, results
    (r,) = results
    assert r == (160_000, 450.0, False, 5_000, 20.0, 250)


def check_consecutive_manual_laps_have_no_cooldown() -> None:
    """没有任何固定时间冷却：相隔很短的连续手动 Lap 每次都生效（模型里没有时钟这个输入）。"""
    dev, m = running(100_000, 300.0)
    dev.at(100_400, 300.5)
    m.on_timer_lap2(0)
    assert m.base_t == 100_400
    dev.at(100_450, 300.6)  # 仅 50 ms 之后
    m.on_timer_lap2(0)
    assert (m.base_t, m.base_d) == (100_450, 300.6)
    dev.at(100_450, 300.6)  # 同一快照再来一次：幂等
    m.on_timer_lap2(0)
    assert (m.base_t, m.base_d) == (100_450, 300.6)


def check_near_simultaneous_duplicates_with_different_snapshots() -> None:
    """真机若在同一圈边界先后送达 STEP 与 LAP2 且两次快照相差一个采样点：后一次覆盖前一次。

    这是计量上的已知限制（相差 <= 一个快照粒度，通常 <= 1 秒），不是 bug。
    要不要进一步去重，必须先看真机事件日志里 STEP/LAP2/LAP 的真实顺序和间隔再设计——
    这里刻意没有固定时间冷却，因为它会吞掉用户相隔很短的连续手动 Lap。
    """
    dev, m = running(100_000, 300.0)
    dev.at(160_000, 450.0)
    m.on_workout_step_complete()
    dev.at(160_020, 450.1)  # 第二个回调拿到稍晚一点的快照
    m.on_timer_lap2(16)
    assert (m.base_t, m.base_d) == (160_020, 450.1)  # 以最后一次为准，偏差 20 ms / 0.1 m


def check_pause_resume_stop_continue_keep_lap() -> None:
    dev, m = running(100_000, 300.0)
    m.compute(130_000, 400.0)
    base = (m.base_t, m.base_d)
    dev.at(999_999, 9_999.0)  # 若这些回调误读快照重置基线，下面的断言会失败
    m.on_timer_pause()
    m.on_timer_resume()
    m.on_timer_stop()
    m.on_timer_start()  # 停止后继续
    assert (m.base_t, m.base_d, m.pending) == (*base, False)
    m.compute(160_000, 480.0)
    assert m.lap_time_ms() == 60_000 and m.lap_distance_m() == 180.0


def check_reset_then_new_activity() -> None:
    dev, m = running(100_000, 300.0)
    m.compute(130_000, 400.0)
    m.on_timer_reset()
    assert m.pending and m.base_t is None and m.base_d is None
    assert m.timer is None and m.lap_time_ms() is None
    m.compute(0, 0.0)  # 新活动：0 是已知值，第一份有效快照成对建立
    assert (m.base_t, m.base_d, m.pending) == (0, 0.0, False)
    m.compute(4_000, 12.0)
    assert m.lap_time_ms() == 4_000


def check_invalid_boundary_then_recovery() -> None:
    dev, m = running(100_000, 300.0)
    m.compute(130_000, 400.0)
    assert m.lap_time_ms() == 30_000  # 边界前旧圈正常累计
    dev.snapshot = Snap(160_000, None)  # 边界快照距离未知
    m.on_workout_step_complete()
    assert m.pending and m.base_t is None and m.base_d is None  # 进入待初始化，不再显示旧圈数据
    assert m.lap_time_ms() is None and m.lap_distance_m() is None and m.lap_pace() is None
    m.compute(161_000, None)  # 时间有效、距离未知：不得单独补时间
    assert m.pending and m.base_t is None
    m.compute(162_000, 460.0)  # 下一份时间与距离同时有效 → 成对建立
    assert (m.base_t, m.base_d, m.pending) == (162_000, 460.0, False)
    m.compute(172_000, 490.0)
    assert m.lap_time_ms() == 10_000 and m.lap_distance_m() == 30.0 and m.lap_pace() == 333


def check_bad_snapshot_values_enter_pending() -> None:
    for bad in (None, Snap(None, 5.0), Snap(5, None), Snap(-5, 100.0), Snap(5, -1.0), Snap("x", 1.0), Snap(NAN, 1.0),
                Snap(5, NAN), Snap(5, float("inf"))):
        dev, m = running(100_000, 300.0)
        dev.snapshot = bad
        m.on_timer_lap()
        assert m.pending and m.base_t is None and m.base_d is None, bad
        m.compute(110_000, 310.0)  # 恢复
        assert (m.base_t, m.base_d) == (110_000, 310.0), bad


def check_zero_is_known_not_missing() -> None:
    dev = Device()
    dev.at(0, 0.0)
    m = LapModel(dev)
    assert (m.base_t, m.base_d, m.pending) == (0, 0.0, False)


def check_lap_pace_threshold_kept() -> None:
    dev, m = running(100_000, 300.0)
    dev.at(160_000, 450.0)
    m.on_workout_step_complete()
    m.compute(163_000, 459.0)  # 新圈 9 m < 20 m：无配速
    assert m.lap_distance_m() == 9.0 and m.lap_pace() is None
    m.compute(166_000, 470.0)  # 新圈 20 m：配速恢复
    assert m.lap_distance_m() == 20.0 and m.lap_pace() == 300


def check_settings_change_does_not_touch_lap() -> None:
    dev, m = running(100_000, 300.0)
    m.compute(130_000, 400.0)
    base = (m.base_t, m.base_d, m.pending)
    loads = m.settings_loads
    m.reload_settings()  # 应用设置变化
    m.on_timer_start()  # 活动开始刷新配置
    assert (m.base_t, m.base_d, m.pending) == base
    assert m.settings_loads == loads + 2


# ══════════════════════════════════════════════════════════════
#  2. 源码结构静态检查
# ══════════════════════════════════════════════════════════════
def strip_comments_and_strings(src: str, keep_strings: bool = False) -> str:
    """去掉 // 和 /* */ 注释，并（默认）清空字符串字面量内容、保留引号，避免注释/日志文字干扰检查与花括号配对。

    keep_strings=True 时保留字符串内容（用于需要检查 "ROLLBACK" 这类字面量的场合）。
    """
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            start = i
            i += 1
            while i < n and src[i] != '"':
                i += 2 if src[i] == "\\" else 1
            i += 1
            out.append(src[start:i] if keep_strings else '""')
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j == -1 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def function_body(code: str, name: str) -> str:
    m = re.search(r"\bfunction\s+" + re.escape(name) + r"\s*\([^)]*\)\s*\{", code)
    assert m, f"function {name}() not found"
    depth, i = 1, m.end()
    while depth and i < len(code):
        depth += {"{": 1, "}": -1}.get(code[i], 0)
        i += 1
    assert depth == 0, f"unbalanced braces in {name}()"
    return code[m.end() : i - 1]


def load(path: Path, keep_strings: bool = False) -> str:
    return strip_comments_and_strings(path.read_text(encoding="utf-8"), keep_strings)


def check_static_callbacks() -> None:
    view = load(VIEW)
    step = function_body(view, "onWorkoutStepComplete")
    assert "updateLapBaseline(" in step, "onWorkoutStepComplete 必须走统一基线入口"

    lap2 = function_body(view, "onTimerLap2")
    assert "updateLapBaseline(" in lap2
    assert re.search(r"\breturn\s+true\s*;", lap2), "onTimerLap2 必须保持返回 true"
    assert not re.search(r"\breturn\s+false\s*;", lap2)

    lap = function_body(view, "onTimerLap")
    assert "updateLapBaseline(" in lap, "旧版 onTimerLap 兼容回调必须保留并走统一入口"

    start = function_body(view, "onTimerStart")
    assert "loadSettings(" in start, "活动开始应立即刷新配置"
    for forbidden in ("updateLapBaseline", "clearLapBaseline", "setLapBaselineIfValid", "mLapStart", "clearActivityState"):
        assert forbidden not in start, f"onTimerStart 不得触碰单圈基线：{forbidden}"

    for name in ("onTimerPause", "onTimerResume", "onTimerStop"):
        body = function_body(view, name)
        for forbidden in ("updateLapBaseline", "clearLapBaseline", "setLapBaselineIfValid", "mLapStart", "loadSettings"):
            assert forbidden not in body, f"{name} 不得触碰单圈基线/配置：{forbidden}"

    assert "clearActivityState(" in function_body(view, "onTimerReset"), "onTimerReset 必须清空活动状态"
    assert "clearLapBaseline(" in function_body(view, "clearActivityState")


def check_static_unified_baseline() -> None:
    view = load(VIEW)
    upd = function_body(view, "updateLapBaseline")
    assert upd.count("readActivitySnapshot(") == 1, "一次只读一份快照"
    assert "setLapBaselineIfValid(" in upd and "clearLapBaseline(" in upd
    for forbidden in ("nowMs", "getTimer", "cooldown", "Cooldown"):
        assert forbidden not in upd, f"updateLapBaseline 不得有固定时间冷却：{forbidden}"

    setter = function_body(view, "setLapBaselineIfValid")
    assert "Metrics.isValidLapSnapshot(" in setter
    assert setter.count("mLapStartTimerMs =") == 1 and setter.count("mLapStartDistanceM =") == 1

    # 两个基线成员只能在 setLapBaselineIfValid / clearLapBaseline 里被赋值（不能从不同次 compute 分别补齐）
    for m in re.finditer(r"\bmLapStart(?:Timer|Distance)M\s*=(?!=)", view):
        line_start = view.rfind("\n", 0, m.start()) + 1
        line = view[line_start : view.find("\n", m.start())]
        if re.match(r"\s*hidden\s+var\b", line):
            continue  # 声明
        owner = None
        for fn in ("setLapBaselineIfValid", "clearLapBaseline"):
            body_start = view.find(function_body(view, fn))
            if body_start <= m.start() < body_start + len(function_body(view, fn)):
                owner = fn
        assert owner, f"单圈基线只能在 setLapBaselineIfValid/clearLapBaseline 里赋值：{line.strip()}"

    comp = function_body(view, "compute")
    assert "mLapBaselinePending" in comp and "setLapBaselineIfValid(" in comp
    assert re.search(r"setLapBaselineIfValid\(\s*mTimerMs\s*,\s*mDistanceM\s*\)", comp), "补建必须用同一份快照的两个值"


def check_static_compute_has_no_config_or_snapshot_reads() -> None:
    view = load(VIEW)
    comp = function_body(view, "compute")
    for forbidden in (
        "loadSettings(",
        "Properties.",
        "UserProfile.",
        "getHeartRateZones",
        "getCurrentSport",
        "getActivityInfo",
        "readActivitySnapshot",
        "readMaxHrProperty",
        "readHrZones",
        "readCurrentSport",
    ):
        assert forbidden not in comp, f"compute() 不应直接读配置/快照：{forbidden}"
    assert "refreshHrZonesIfDue(" in comp, "compute() 只允许通过 60s 门控刷新区间边界"


def check_static_api_call_sites_are_single() -> None:
    view = load(VIEW)
    for api, accessor in (
        ("Properties.getValue(", "readMaxHrProperty"),
        ("UserProfile.getCurrentSport(", "readCurrentSport"),
        ("UserProfile.getHeartRateZones(", "readHrZones"),
        ("Activity.getActivityInfo(", "readActivitySnapshot"),
    ):
        assert view.count(api) == 1, f"{api} 应只有一个调用点（{accessor}），实际 {view.count(api)}"
        assert api in function_body(view, accessor), f"{api} 应在 {accessor}() 里"


def check_static_zone_refresh_policy() -> None:
    view = load(VIEW, keep_strings=True)
    assert re.search(r"\bSETTINGS_ZONE_REFRESH_MS\s*=\s*60000\s*;", view), "区间边界周期刷新应为 60000 ms（项目初始策略）"
    due = function_body(view, "refreshHrZonesIfDue")
    assert "SETTINGS_ZONE_REFRESH_MS" in due
    assert "age < 0" in due or "age >= 0" in due, "必须处理计时器回退"
    assert '"ROLLBACK"' in due and '"PERIODIC"' in due and '"INIT"' in due
    refresh = function_body(view, "refreshHrZones")
    assert "Metrics.isValidHrZones(" in refresh, "区间边界必须校验"
    assert "mZonesRefreshedMs = nowMs()" in refresh, "刷新要先打时间戳，失败也不能退化成每帧重试"
    init = function_body(view, "initialize")
    assert "loadSettings(" in init, "初始化时加载配置"
    load_body = function_body(view, "loadSettings")
    assert "refreshHrZones(" in load_body
    assert "loadSettings(" in function_body(view, "reloadSettings")


def check_static_event_log_default_off_and_guarded() -> None:
    raw = VIEW.read_text(encoding="utf-8")
    code = strip_comments_and_strings(raw)
    flags = re.findall(r"hidden\s+var\s+EVENT_LOG\s*=\s*(\w+)\s*;", code)
    assert flags == ["false"], f"EVENT_LOG 必须默认 false（正式构建关闭），实际 {flags}"
    assert code.count("System.println(") == 1 and "System.println(" in function_body(code, "logLine"), \
        "println 只允许出现在 logLine()"

    lines = code.splitlines()
    call = re.compile(r"\blog(?:LapBoundary|TimerEvent|BaselineEstablished|Tick|Config|Line)\s*\(")
    for idx, line in enumerate(lines):
        if not call.search(line) or re.search(r"\bfunction\b", line):
            continue
        if "EVENT_LOG" in line:
            continue
        prev = next((lines[j] for j in range(idx - 1, -1, -1) if lines[j].strip()), "")
        in_log_helper = False
        # 日志辅助函数之间的互相调用（logLine 被 logTick 等调用）发生在 EVENT_LOG 保护之内
        for helper in ("logLapBoundary", "logTimerEvent", "logBaselineEstablished", "logTick", "logConfig"):
            body = function_body(code, helper)
            if line.strip() in body:
                in_log_helper = True
        assert "if (EVENT_LOG)" in prev or in_log_helper, f"日志调用未受 EVENT_LOG 保护：{line.strip()}"


def check_static_app_refreshes_view_cache() -> None:
    app = load(APP)
    assert re.search(r"\bmView\b", app) and "mView = createView()" in function_body(app, "getInitialView")
    body = function_body(app, "onSettingsChanged")
    assert "mView" in body and "reloadSettings()" in body, "onSettingsChanged 必须让 View 配置缓存生效，而不是只请求重绘"
    assert "requestUpdate" in body


def check_static_scope_untouched() -> None:
    metrics = load(METRICS)
    assert re.search(r"\bMIN_LAP_DISTANCE_M\s*=\s*20\.0\s*;", metrics), "20 m 单圈配速阈值必须保持"
    view = load(VIEW)
    comp = function_body(view, "compute")
    # 仍然使用 currentSpeed / averageSpeed / timerTime / elapsedDistance，不引入平滑窗口
    for field in ("currentSpeed", "averageSpeed", "timerTime", "elapsedDistance"):
        assert field in comp, f"compute() 应继续使用 {field}"
    for forbidden in ("smooth", "Smooth", "window", "Window"):
        assert forbidden not in comp


def check_static_lap2_unchanged_vs_head() -> None:
    """onTimerLap2 返回 true 的既有行为：与 git HEAD 对照（取不到 git 则跳过）。"""
    try:
        head = subprocess.run(
            ["git", "show", "HEAD:source/RunDash970View.mc"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        print("  (skip) git HEAD 不可用，跳过 onTimerLap2 与 HEAD 的对照")
        return
    head_body = function_body(strip_comments_and_strings(head), "onTimerLap2")
    assert re.search(r"\breturn\s+true\s*;", head_body), "HEAD 的 onTimerLap2 本来就返回 true"


CHECKS = [
    check_paired_baseline_from_one_snapshot,
    check_manual_and_auto_lap_reset,
    check_workout_step_complete_resets_lap,
    check_total_time_distance_unaffected_by_lap_events,
    check_duplicate_notifications_same_snapshot_idempotent,
    check_consecutive_manual_laps_have_no_cooldown,
    check_near_simultaneous_duplicates_with_different_snapshots,
    check_pause_resume_stop_continue_keep_lap,
    check_reset_then_new_activity,
    check_invalid_boundary_then_recovery,
    check_bad_snapshot_values_enter_pending,
    check_zero_is_known_not_missing,
    check_lap_pace_threshold_kept,
    check_settings_change_does_not_touch_lap,
    check_static_callbacks,
    check_static_unified_baseline,
    check_static_compute_has_no_config_or_snapshot_reads,
    check_static_api_call_sites_are_single,
    check_static_zone_refresh_policy,
    check_static_event_log_default_off_and_guarded,
    check_static_app_refreshes_view_cache,
    check_static_scope_untouched,
    check_static_lap2_unchanged_vs_head,
]


def main() -> int:
    for fn in CHECKS:
        try:
            fn()
        except AssertionError as exc:
            print(f"FAIL: {fn.__name__}: {exc}", file=sys.stderr)
            return 1
    print(f"PASS: {Path(__file__).name} — {len(CHECKS)} checks OK (model + static; 不证明真机回调送达)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
