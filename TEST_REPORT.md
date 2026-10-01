# TEST_REPORT — RunDash 970

日期：2026-09-10  
目标：Forerunner 970（`fr970`）可手工微调布局、电量缓存与 HR Zone

## 自动测试

命令：

```bash
python3 scripts/test_metrics.py
```

结果：`PASS`。覆盖配速、时长、距离、Lap Pace、Virtual Pacer、HR Zone 及缺失值镜像公式。

Lap 生命周期回归命令：

```bash
python3 scripts/test_lap_lifecycle.py
```

结果：`PASS`。这是 Monkey C 生命周期逻辑镜像和源码不变量测试，不冒充真机测试，覆盖：

- start → 累计 → stop → start：Lap 基线不变，Lap Time/Distance/Pace 连续。
- pause → resume：Lap 基线不变。
- 真实 Lap：基线恰好重置一次。
- reset：清空基线，下一次 compute 建立新会话基线。
- 静态检查 `onTimerStart()` 不再调用 `resetLapBaselineFromActivity()`。

## 编译

命令：

```bash
./scripts/build.sh .secrets/developer_key.der
```

结果：`BUILD SUCCESSFUL`  
警告：0  
错误：0

## 模拟器 sanity 验证

已完成：

- 重启 Connect IQ Simulator，避免旧 PRG 或旧帧残留。
- 加载刚编译的 `bin/RunDash970-fr970.prg`。
- 使用真实 `CIQ Simulator - Forerunner 970` 窗口截图。
- 截图路径：`/private/tmp/rundash970-lap-pause-fix.png`

截图检查：Current Time、Heart Rate、Cadence、Elapsed Time/Timer、BAT、Elapsed/Total Distance、Lap Time、Lap Distance、L/C/A 配速、五段彩色 Zone bar 和绿色 Z 圆圈均已出现；PACER 与 PAUSED 均未出现。发布态 `DEBUG_LAYOUT=false`，所有主屏文字使用中心+垂直中心定位，截图无明显整块文字重叠或圆屏裁切。

模拟器状态：`PASS`

调试态单独验证：`DEBUG_LAYOUT=true` 编译通过并生成 `/private/tmp/rundash970-layout-debug-v3.png`；最终发布态已恢复为 `DEBUG_LAYOUT=false`，重新编译并重新加载。

## 真机验证

状态：`PENDING_PHYSICAL_DEVICE`

用户需要在真实 FR970 上确认：

- Cadence 是 RPM 还是 Garmin 训练界面显示的 SPM。
- BAT 电量百分比是否与手表系统电量一致。
- BAT 是否约 60 秒刷新一次，首次无数据时是否显示 `BAT --`。
- `L`、`C`、`A` 分别与真机 Lap Pace、Current Pace、Average Pace 的对应关系。
- 开始、暂停、继续、停止、重置和手动计圈后的 Timer、Lap Time、Lap Distance、Lap Pace；暂停期间主屏不显示状态文字。
- 手动停止或自动暂停后继续时，Lap Time、Lap Distance、Lap Pace 不应归零；只有真实计圈才应重置 Lap 基线。
- 无 GPS、无 HR、无 Cadence 时的缺失值显示。

完整步骤、记录表和问题模板见 `MANUAL_VALIDATION.md`。
