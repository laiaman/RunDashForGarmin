#!/usr/bin/env python3
"""Deterministic mirror of the RunDash 970 Lap lifecycle invariants.

This is a source/lifecycle logic test, not a real-watch or Garmin simulator test.
It verifies that pause/stop/start/resume do not move the Lap baseline.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re


MIN_LAP_DISTANCE_M = 20.0
SOURCE = Path(__file__).resolve().parents[1] / "source" / "RunDash970View.mc"


@dataclass
class LapState:
    baseline_timer_ms: int | None = None
    baseline_distance_m: float | None = None
    timer_ms: int | None = None
    distance_m: float | None = None
    paused: bool = False

    def compute(self, timer_ms: int, distance_m: float) -> None:
        self.timer_ms = timer_ms
        self.distance_m = distance_m
        if self.baseline_timer_ms is None and self.baseline_distance_m is None:
            self.baseline_timer_ms = timer_ms
            self.baseline_distance_m = distance_m

    def on_start(self) -> None:
        self.paused = False

    def on_pause(self) -> None:
        self.paused = True

    def on_resume(self) -> None:
        self.paused = False

    def on_stop(self) -> None:
        self.paused = True

    def on_lap(self) -> None:
        assert self.timer_ms is not None and self.distance_m is not None
        self.baseline_timer_ms = self.timer_ms
        self.baseline_distance_m = self.distance_m

    def on_reset(self) -> None:
        self.baseline_timer_ms = None
        self.baseline_distance_m = None
        self.timer_ms = None
        self.distance_m = None
        self.paused = False

    def lap_values(self) -> tuple[int | None, float | None, float | None]:
        if (
            self.timer_ms is None
            or self.distance_m is None
            or self.baseline_timer_ms is None
            or self.baseline_distance_m is None
        ):
            return None, None, None
        delta_time_ms = self.timer_ms - self.baseline_timer_ms
        delta_distance_m = self.distance_m - self.baseline_distance_m
        if delta_time_ms <= 0 or delta_distance_m < MIN_LAP_DISTANCE_M:
            return None, max(delta_distance_m, 0.0), None
        pace = (delta_time_ms / 1000.0) / (delta_distance_m / 1000.0)
        return delta_time_ms, delta_distance_m, pace


def check_static_on_start_does_not_reset() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    match = re.search(
        r"function onTimerStart\(\)\s*\{(?P<body>.*?)\n\s*\}",
        source,
        flags=re.DOTALL,
    )
    assert match, "onTimerStart() not found"
    assert "resetLapBaselineFromActivity" not in match.group("body")
    assert "mPaused = false" in match.group("body")


def check_stop_start_continues() -> None:
    state = LapState()
    state.compute(0, 0.0)
    state.on_start()
    state.compute(248_000, 1000.0)
    baseline = (state.baseline_timer_ms, state.baseline_distance_m)
    state.on_stop()
    state.on_start()
    state.compute(498_000, 2000.0)
    assert (state.baseline_timer_ms, state.baseline_distance_m) == baseline
    _, distance, pace = state.lap_values()
    assert distance == 2000.0
    assert pace == 249.0


def check_pause_resume_continues() -> None:
    state = LapState()
    state.compute(0, 100.0)
    state.compute(60_000, 300.0)
    baseline = (state.baseline_timer_ms, state.baseline_distance_m)
    state.on_pause()
    state.on_resume()
    state.compute(120_000, 500.0)
    assert (state.baseline_timer_ms, state.baseline_distance_m) == baseline
    _, distance, pace = state.lap_values()
    assert distance == 400.0
    assert pace == 300.0


def check_real_lap_resets_once() -> None:
    state = LapState()
    state.compute(0, 0.0)
    state.compute(248_000, 1000.0)
    state.on_lap()
    first_baseline = (state.baseline_timer_ms, state.baseline_distance_m)
    state.compute(498_000, 2000.0)
    assert first_baseline == (248_000, 1000.0)
    _, distance, pace = state.lap_values()
    assert distance == 1000.0
    assert pace == 250.0


def check_reset_then_new_session_baseline() -> None:
    state = LapState()
    state.compute(248_000, 1000.0)
    state.on_reset()
    state.compute(10_000, 50.0)
    assert (state.baseline_timer_ms, state.baseline_distance_m) == (10_000, 50.0)
    state.compute(20_000, 100.0)
    assert state.lap_values()[1] == 50.0


def main() -> int:
    check_static_on_start_does_not_reset()
    check_stop_start_continues()
    check_pause_resume_continues()
    check_real_lap_resets_once()
    check_reset_then_new_session_baseline()
    print(f"PASS: {Path(__file__).name} — Lap lifecycle invariants OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
