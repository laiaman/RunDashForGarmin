#!/usr/bin/env python3
"""变异验证：证明 tests/RunDash970Tests.mc 里的单元测试“真的会失败”。

做法：把 source/ 复制到临时目录，每次只做一处故意破坏（例如删掉 onWorkoutStepComplete、加固定冷却、
让 compute() 每帧读配置、把未知距离当 0……），用 `monkeyc -t` 编译并在 Connect IQ 模拟器里跑单元测试，
确认预期的测试会失败（变异体被“杀死”）。仓库源码与 bin/ 不会被改动。

前置：Connect IQ 模拟器已启动（connectiq）。
用法：python3 scripts/mutation_check.py [变异体名前缀 ...] [--keep]
退出码：0 = 基准全绿且所有变异体都被预期的测试杀死；1 = 有变异体存活或没被预期测试发现；2 = 环境问题。
耗时：每个变异体约 10–20 秒。
"""
from __future__ import annotations

import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# (名称, 源文件, 旧文本(必须恰好出现 1 次), 新文本, 预期至少失败的测试)
MUTANTS = [
    ("M01_no_workout_step_callback", "RunDash970View.mc",
     'function onWorkoutStepComplete() {\n        updateLapBaseline("STEP", null);\n    }',
     'function onWorkoutStepComplete() {\n    }',
     ["tWorkoutStepCompleteResetsBaseline"]),
    ("M02_timer_start_resets_lap", "RunDash970View.mc",
     'mPaused = false;\n        loadSettings("START");',
     'mPaused = false;\n        updateLapBaseline("START", null);\n        loadSettings("START");',
     ["tPauseResumeStopStartKeepCurrentLap"]),
    ("M03_compute_loads_settings_every_frame", "RunDash970View.mc",
     'function compute(info) {\n        refreshHrZonesIfDue();',
     'function compute(info) {\n        loadSettings("EVERY");',
     ["tConfigIsNotReadEveryCompute"]),
    ("M04_fixed_cooldown_between_laps", "RunDash970View.mc",
     'function updateLapBaseline(source, trigger) {\n        var timerMs = null;',
     'hidden var mLastLapClk = null;\n    function updateLapBaseline(source, trigger) {\n'
     '        if (mLastLapClk != null && nowMs() - mLastLapClk < 1000) { return; }\n'
     '        mLastLapClk = nowMs();\n        var timerMs = null;',
     ["tConsecutiveManualLapsHaveNoCooldown"]),
    ("M05_unknown_distance_treated_as_zero", "RunDash970View.mc",
     'var prevTimerMs = mLapStartTimerMs;\n        var prevDistanceM = mLapStartDistanceM;',
     'if (distanceM == null) { distanceM = 0.0; }\n        var prevTimerMs = mLapStartTimerMs;\n'
     '        var prevDistanceM = mLapStartDistanceM;',
     ["tInvalidBoundaryClearsOldLapThenRecoversAsPair", "tNullOrBadSnapshotObjectsEnterPending"]),
    ("M06_app_only_requests_update", "RunDash970App.mc",
     'if (mView != null) {\n            mView.reloadSettings();\n        }',
     '',
     ["tAppSettingsChangedReloadsTheViewCache"]),
    ("M07_lap2_returns_false", "RunDash970View.mc",
     'updateLapBaseline("LAP2", trigger);\n        return true;',
     'updateLapBaseline("LAP2", trigger);\n        return false;',
     ["tManualAndLegacyLapResetBaseline", "tAutoLapTriggersResetBaseline"]),
    ("M08_no_timer_rollback_handling", "RunDash970View.mc",
     'refreshHrZones("ROLLBACK");',
     '',
     ["tTimerRollbackForcesZoneRefresh"]),
    ("M09_zones_not_validated", "RunDash970View.mc",
     'if (Metrics.isValidHrZones(zones)) {\n            mHrZones = zones;',
     'if (zones != null) {\n            mHrZones = zones;',
     ["tInvalidZonesUseExistingFallback"]),
    ("M10_nan_passes_snapshot_check", "Metrics.mc",
     'return isNumeric(value) && ((value - value) == 0);',
     'return isNumeric(value);',
     ["tNonFiniteValuesAreRejected"]),
    ("M11_pause_resets_lap", "RunDash970View.mc",
     'function onTimerPause() {\n        mPaused = true;',
     'function onTimerPause() {\n        mPaused = true;\n        updateLapBaseline("PAUSE", null);',
     ["tPauseResumeStopStartKeepCurrentLap"]),
    ("M12_periodic_refresh_every_frame", "RunDash970View.mc",
     'if (age < SETTINGS_ZONE_REFRESH_MS) {\n                    return;\n                }',
     'if (age < 0) {\n                    return;\n                }',
     ["tConfigIsNotReadEveryCompute"]),
]


def find_key() -> str:
    for cand in (os.environ.get("RUNDASH_KEY"), str(REPO / ".secrets" / "developer_key.der"),
                 str(Path.home() / ".connectiq" / "developer_key.der")):
        if cand and Path(cand).is_file():
            return cand
    print("找不到开发者密钥：请设置 RUNDASH_KEY 或放到 .secrets/developer_key.der", file=sys.stderr)
    raise SystemExit(2)


def build_env() -> dict:
    env = dict(os.environ)
    if subprocess.run(["java", "-version"], capture_output=True, env=env).returncode != 0:
        for home in ("/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home",
                     "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"):
            if (Path(home) / "bin" / "java").is_file():
                env["JAVA_HOME"] = home
                env["PATH"] = home + "/bin:" + env.get("PATH", "")
                break
    if subprocess.run(["java", "-version"], capture_output=True, env=env).returncode != 0:
        print("找不到可用的 Java（monkeyc 需要）", file=sys.stderr)
        raise SystemExit(2)
    return env


def run_unit(work: Path, name: str, srcdir: Path, key: str, env: dict):
    jungle = work / f"{name}.jungle"
    jungle.write_text(
        f"project.manifest = {REPO}/manifest.xml\n"
        f"base.sourcePath = {srcdir};{REPO}/tests\n"
        f"base.resourcePath = {REPO}/resources;{REPO}/resources-zhs\n",
        encoding="utf-8",
    )
    prg = work / f"{name}.prg"
    c = subprocess.run(["monkeyc", "-t", "-d", "fr970", "-f", str(jungle), "-o", str(prg), "-y", key],
                       env=env, capture_output=True, text=True)
    if "BUILD SUCCESSFUL" not in c.stdout:
        return None, "编译失败: " + (c.stdout + c.stderr)[-600:].replace("\n", " ")
    # monkeydo 是脚本，真正干活的是它启动的 Java 进程：放进独立进程组，超时后整组结束
    proc = subprocess.Popen(["monkeydo", str(prg), "fr970", "-t"], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        out, _ = proc.communicate(timeout=150)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.communicate()
        return None, "运行超时 150 秒（模拟器可能卡住，请退出并重开 ConnectIQ.app）"
    return out, None


def parse_results(out: str) -> dict:
    res, in_results = {}, False
    for line in out.splitlines():
        if line.startswith("RESULTS"):
            in_results = True
            continue
        if in_results:
            m = re.match(r"^(t\w+)\s+(PASS|FAIL|ERROR)\s*$", line)
            if m:
                res[m.group(1)] = m.group(2)
    return res


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    keep = "--keep" in sys.argv
    if subprocess.run(["pgrep", "-f", "ConnectIQ.app/Contents/MacOS/simulator"], capture_output=True).returncode != 0:
        print("Connect IQ 模拟器未运行：请先执行 connectiq 或打开 ConnectIQ.app", file=sys.stderr)
        return 2
    key, env = find_key(), build_env()
    work = Path(tempfile.mkdtemp(prefix="rundash-mutants-"))
    try:
        base_src = work / "src_base"
        shutil.copytree(REPO / "source", base_src)
        out, err = run_unit(work, "base", base_src, key, env)
        if err:
            print("基准", err)
            return 2
        base = parse_results(out)
        bad = sorted(k for k, v in base.items() if v != "PASS")
        print(f"基准：{len(base)} 个测试，未通过={bad}")
        if bad or not base:
            return 1

        survivors = 0
        for name, fname, old, new, expect in MUTANTS:
            if args and not any(name.startswith(a) for a in args):
                continue
            src = work / f"src_{name}"
            shutil.copytree(REPO / "source", src)
            path = src / fname
            text = path.read_text(encoding="utf-8")
            if text.count(old) != 1:
                print(f"{name}: 变异点在源码里出现 {text.count(old)} 次（应为 1）——源码结构变了，请更新本脚本")
                survivors += 1
                continue
            path.write_text(text.replace(old, new), encoding="utf-8")
            out, err = run_unit(work, name, src, key, env)
            if err:
                print(f"{name}: {err}")
                survivors += 1
                continue
            failed = sorted(k for k, v in parse_results(out).items() if v != "PASS")
            hit = [e for e in expect if e in failed]
            if hit:
                print(f"{name}: KILLED   预期测试已失败={hit}  (共 {len(failed)} 个测试失败)")
            else:
                survivors += 1
                print(f"{name}: SURVIVED 预期测试 {expect} 没有失败；实际失败={failed}")
        print("全部变异体已被预期测试杀死" if not survivors else f"有 {survivors} 个变异体存活/异常")
        return 0 if not survivors else 1
    finally:
        if keep:
            print("保留临时目录:", work)
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
