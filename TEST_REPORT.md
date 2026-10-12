# TEST_REPORT — RunDash 970

## 2026-10-10 训练课单圈重置 + 配置读取优化（本轮）

目标：Forerunner 970（`fr970`）。改动文件：`source/Metrics.mc`、`source/RunDash970App.mc`、`source/RunDash970View.mc`（布局、颜色、字体、单位、数据语义、20 m 单圈配速阈值均未改）。

**结论先行：自动化与模拟器内验证通过；真机验收尚未进行，不能据此宣称“训练课按 Lap 推进步骤后单圈不重置”的问题已解决。** “编译成功”也不等于真机问题已解决。

### 验证结果

| 层级 | 内容 | 结果 |
|---|---|---|
| Python 模型/静态 | `scripts/test_metrics.py`（含快照/区间校验镜像）、`scripts/test_lap_lifecycle.py`（23 项：状态机模型 + 源码结构静态检查）、`scripts/test_settings_refresh.py`（9 项：60 秒调度与调用次数模型） | 全部 PASS |
| Monkey C 单元测试 | `scripts/run-unit-tests.sh`：`tests/RunDash970Tests.mc` 共 25 项，在 Connect IQ 模拟器 VM 里执行**真实编译后的** View/App/Metrics（外部读取点由测试子类注入并计数） | 25/25 PASS |
| 变异验证 | `scripts/mutation_check.py`：12 个故意破坏（删 `onWorkoutStepComplete`、`onTimerStart` 重置单圈、`compute()` 每帧读配置、加固定冷却、未知距离当 0、App 只重绘不刷新、`onTimerLap2` 返回 false、去掉计时器回退处理、不校验区间、NaN 放行、暂停重置、60 秒门控失效） | 12/12 被预期测试发现（没有存活变异体） |
| 编译 | `fr970` 正式版、诊断版；`manifest.xml` 里全部 12 个机型（`/tmp` 回归编译，不写 `bin/`） | 全部 `BUILD SUCCESSFUL`；无新增代码警告 |
| 模拟器：V5 基线复现 | 原版在 Timer Controls 里：点 `Lap` 单圈重置（`0:06`→`0:02`），点 `Workout Step` 单圈**不**重置（TIME `00:20` 时 LAP 仍为 `0:12`） | 复现了缺陷；截图见 `bin/lapfix/evidence/` |
| 模拟器：新版运行（空闲，未开始活动） | 诊断版（`EVENT_LOG` 打开）连续运行 394 次 `compute()`（391.6 秒），读事件日志；日志与分析结果归档在 `bin/lapfix/evidence/idle_diag_run.log`、`idle_diag_run_analysis.txt` | Properties 读取 1 次（仅初始化）；区间接口读取 1→7 次（初始化 + 6 次 `PERIODIC`，间隔 60.0–61.0 秒）；`usedMemory` 稳定在 20,392–21,760 B；`compute()` 平均间隔 996 ms |
| 模拟器：日志开关（`EVENT_LOG`） | 正对照：运行诊断版并捕获标准输出；负对照：25 项单元测试运行（`source/` 里 `EVENT_LOG = false`，测试已驱动 `compute()` 与全部回调）的完整输出 | 诊断版约 15 秒输出 19 行 `RDEVT`；单元测试完整输出 109 行，其中 `RDEVT` 为 0 行。**局限**：曾另跑过一次“正式版 PRG 空闲运行 20 秒、输出 0 字节”，但随后同样的诊断版也出现 0 字节（模拟器普通运行模式在连续启停后不再回传输出），无法证明那次应用真的跑起来，**不作为证据**；正式 PRG 本身在真机上是否无日志输出未实测，依据是源码里所有日志调用都在 `if (EVENT_LOG)` 之下且正式构建脚本强制要求 `EVENT_LOG = false` |
| 模拟器：新版 Timer Controls 点击 | 点 `Start` / `Lap` / `Workout Step` 看新版单圈 | **本轮未执行**：需要 GUI 自动化控制模拟器窗口，已按“不再反复要授权”的要求放弃；改由单元测试直接调用各回调代替。手动步骤见 `MANUAL_VALIDATION.md` §6.1 |
| 真机 FR970 | 训练课按 Lap / 自动步骤、连续 Lap、暂停/停止继续、设置变化 | **PENDING_PHYSICAL_DEVICE** |

说明：上面两次模拟器运行都是“空闲”状态（没有开始活动，快照里 `timerTime=0`、`elapsedDistance=null`），所以事件日志里单圈一直是待初始化（`pending=1`，界面单圈三项显示 `--`）。这与“时间与距离必须取自同一份有效快照”的设计一致，但也意味着这两次运行证明的是**配置读取次数、日志开关、内存稳定**，不是单圈重置行为；单圈重置行为由单元测试在模拟器 VM 里直接驱动回调验证，真机行为待验收。

### 单元测试覆盖（对应任务要求）

| 要求场景 | 测试 |
|---|---|
| 普通手动 Lap | `tManualAndLegacyLapResetBaseline` |
| 自动 Lap（时间/距离/训练相关 trigger）；`onTimerLap2` 仍返回 true | `tAutoLapTriggersResetBaseline`、`tManualAndLegacyLapResetBaseline` |
| 训练步骤提前完成 / 自动完成（`onWorkoutStepComplete`） | `tWorkoutStepCompleteResetsBaseline`、`tLapPaceReturnsOnlyAfterDistanceThreshold` |
| 新圈下一次有效显示从新边界累计；总时间/总距离连续；20 m 门槛后配速恢复 | `tWorkoutStepCompleteResetsBaseline`、`tLapPaceReturnsOnlyAfterDistanceThreshold` |
| 同一份快照上的重复通知幂等；连续手动 Lap 不被吞（无固定冷却） | `tDuplicateNotificationsOnSameSnapshotAreIdempotent`、`tConsecutiveManualLapsHaveNoCooldown` |
| 无效边界快照 → 待初始化、不显示旧圈数据 → 有效快照成对恢复 | `tInvalidBoundaryClearsOldLapThenRecoversAsPair`、`tNullOrBadSnapshotObjectsEnterPending`、`tBaselineIsPairedFromOneValidSnapshot` |
| null / 负数 / 非数值 / NaN / Infinity 不当作 0；0 是已知值 | `tLapSnapshotValidation`、`tNonFiniteValuesAreRejected`、`tZeroIsKnownValueNotMissing` |
| 暂停/恢复/停止后继续不重置；重置清空；新活动重新建基线 | `tPauseResumeStopStartKeepCurrentLap`、`tResetClearsActivityStateAndNewActivityRebaselines` |
| 配置不再每次 `compute()` 读取；60 秒只刷区间边界；实时心率/区间显示不受缓存影响 | `tConfigIsNotReadEveryCompute`、`tRealtimeHrAndZoneStillUpdateEveryCompute` |
| 初始化/活动开始/设置变化立即刷新，且不影响当前圈；App 真正刷新 View 缓存 | `tConfigRefreshesImmediatelyOnStartAndSettingsChange`、`tAppSettingsChangedReloadsTheViewCache`、`tAppSettingsChangedBeforeViewExistsIsSafe` |
| 计时器回退；原生运动配置变化没触发 `onSettingsChanged` 也会在 60 秒内追上 | `tTimerRollbackForcesZoneRefresh`、`tNativeZoneChangeIsPickedUpWithoutSettingsCallback` |
| 区间边界异常保留现有兜底；最大心率越界忽略 | `tHrZonesBoundaryValidation`、`tInvalidZonesUseExistingFallback`、`tOutOfRangeMaxHrPropertyIsIgnored` |
| 真实 `Activity.Info` 类型可被 `compute()` 正常消费 | `tRealActivityInfoObjectIsAccepted` |

测试过程中的一个实测发现：模拟器 VM 里 `nan >= 0`、`nan <= 0` 为 `true`（`>=` 按 `!(a < b)` 实现），所以不能靠 `(x >= 0)` 拒绝 NaN。`Metrics.isFiniteNumber()` 改用 `(x - x) == 0`，并由 `tNonFiniteValuesAreRejected` 与变异体 M10 守住。另外 `Test.assertEqual(x, null)` 在 `x == null` 时会报类型错误，测试里 null 判断统一用 `rdAssertNull()`。

### 性能验收（只证明调用次数，不证明耗电）

- 旧版 V5：每次 `compute()` 调 `Properties.getValue` + `UserProfile.getCurrentSport` + `UserProfile.getHeartRateZones`（运动区间无效时再多 1 次）。按 1 Hz、1 小时模型计算：10,803 次配置接口调用（Python 模型 `test_settings_refresh.py`）。
- 新版：初始化/活动开始/设置变化各读一次；其余时间只在每 60 秒读一次区间边界。同一模型 1 小时 123 次。模拟器实测（空闲状态）：394 次 `compute()`（391.6 秒）内 Properties 读 1 次、区间读 7 次（含初始化）。该日志由同一份源码的前一次诊断构建产生；最终诊断版是同源码重新构建（SHA-256 不同、大小相同，见 `BUILD_REPORT.md`），其 15 秒短跑也输出了同格式日志（`bin/lapfix/evidence/final_diag_control_15s.log`）。
- 内存：诊断版（含日志字符串开销）`usedMemory` 20,392–21,760 B，运行约 390 秒无增长；**没有同口径的旧版数字可比**（旧版只有模拟器状态栏 17.4/124.4 kB 的粗读数），不下“更省/更费内存”的结论。PRG 体积：HEAD 源码重编 121,964 B → 新版正式版 128,316 B（+6,352 B，主要是临时事件日志代码和新逻辑）。
- `compute()` 耗时：**未测量**（没有可靠的模拟器内计时手段，不编造数字）。
- **电池收益：未知。** 没有实机电量对比，不宣称已证明异常耗电，也不宣称省电比例。

### 既有编译警告说明

编译输出有 4 条 `Metrics.mc` 的 “Cannot determine if container access is using container type.”（`hrZoneValue` 里的 `zones[...]`）。HEAD 源码同样存在这 4 条（已重编 HEAD 核对），与本轮无关，行号随新增代码后移。`venu3`、`epix2pro51mm` 另有 1 条启动图标尺寸（65×65 vs 设备要求）警告，是资源问题，与本轮无关。

### 历史记录（2026-09-10）

## 自动测试（2026-09-10 版，保留作历史；其中 Lap 生命周期的脚本已在 2026-10-10 重写）

命令：

```bash
python3 scripts/test_metrics.py
```

结果：`PASS`。覆盖配速、时长、距离、Lap Pace、Virtual Pacer、HR Zone 及缺失值镜像公式。

Lap 生命周期回归命令：

```bash
python3 scripts/test_lap_lifecycle.py
```

2026-09-10 当时的结果为 `PASS`，覆盖：stop→start 与 pause→resume 不动基线、真实 Lap 恰好重置一次、reset 后建立新会话基线、`onTimerStart()` 不再调用 `resetLapBaselineFromActivity()`。该函数已在 2026-10-10 被统一入口 `updateLapBaseline()` 取代，脚本改为新模型 + 新静态检查（见上）。

## 编译（2026-09-10 记录）

命令：

```bash
./scripts/build.sh .secrets/developer_key.der
```

结果：`BUILD SUCCESSFUL`  
警告：0（2026-10-10 重编 HEAD 源码实测为 4 条 `Metrics.mc` 容器访问提示，见上；此处“0”与实测不符，以 2026-10-10 实测为准）  
错误：0

## 模拟器 sanity 验证（2026-09-10 记录）

已完成：

- 重启 Connect IQ Simulator，避免旧 PRG 或旧帧残留。
- 加载刚编译的 `bin/RunDash970-fr970.prg`。
- 使用真实 `CIQ Simulator - Forerunner 970` 窗口截图。
- 截图路径：`/private/tmp/rundash970-lap-pause-fix.png`

截图检查：Current Time、Heart Rate、Cadence、Elapsed Time/Timer、BAT、Elapsed/Total Distance、Lap Time、Lap Distance、L/C/A 配速、五段彩色 Zone bar 和绿色 Z 圆圈均已出现；PACER 与 PAUSED 均未出现。发布态 `DEBUG_LAYOUT=false`，所有主屏文字使用中心+垂直中心定位，截图无明显整块文字重叠或圆屏裁切。

模拟器状态：`PASS`

调试态单独验证：`DEBUG_LAYOUT=true` 编译通过并生成 `/private/tmp/rundash970-layout-debug-v3.png`；最终发布态已恢复为 `DEBUG_LAYOUT=false`，重新编译并重新加载。

## 真机验证（2026-09-10 清单，仍有效；2026-10-10 训练课单圈验收见 `MANUAL_VALIDATION.md` §6.1 / §6.2）

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
