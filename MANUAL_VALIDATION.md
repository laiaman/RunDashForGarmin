# RunDash 970 手动验证流程

本文面向不熟悉 Connect IQ 的用户。模拟器可以由开发环境完成；真实手表安装、运动操作和真机读数必须由用户本人完成。

## 1. 准备条件

准备以下设备和文件：

1. macOS 电脑。
2. Garmin Connect IQ Simulator 与 `fr970` 设备支持。
3. Java 17、`monkeyc`、`monkeydo`。
4. 本项目目录和项目自己的 developer key。私钥不要复制到仓库、聊天或截图中。
5. 真实 Forerunner 970、USB 数据线和 Garmin Connect Mobile / Garmin Express。

进入项目目录（把路径替换成你电脑上的实际项目目录）：

```bash
cd /path/to/AICoachPortableOnMac/RunDash970
```

如果 Java 17 由 Homebrew 提供：

```bash
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```

## 2. 安装/加载 PRG

先运行确定性测试并编译：

```bash
python3 scripts/test_metrics.py
python3 scripts/test_lap_lifecycle.py
python3 scripts/test_settings_refresh.py
./scripts/build.sh .secrets/developer_key.der
```

确认输出为 `PASS` 和 `BUILD SUCCESSFUL`，并确认文件存在：

```bash
ls -l bin/RunDash970-fr970.prg
```

注意：`./scripts/build.sh` 会**覆盖** `bin/RunDash970-fr970.prg`。该文件目前仍是 V5 原版构建（SHA-256 `f0552d3bb39329ef4c8dce1bfe97256ed90b75769988c81e6e1a2486932b8e1d`），2026-10-10 这一轮刻意没有覆盖它，留作回退。需要保留回退版本时，先 `cp bin/RunDash970-fr970.prg bin/RunDash970-fr970.v5-backup.prg`，或只使用下面的 `build-lapfix.sh`。

2026-10-10 起，训练课单圈重置修复版使用独立构建脚本，输出到 `bin/lapfix/`，**不会覆盖** `bin/RunDash970-fr970.prg`：

```bash
./scripts/build-lapfix.sh              # 正式版 -> bin/lapfix/RunDash970-fr970-lapfix.prg（事件日志关闭）
./scripts/build-lapfix.sh --eventlog   # 诊断版 -> bin/lapfix/RunDash970-fr970-lapfix-eventlog.prg（仅用于验证回调）
./scripts/run-unit-tests.sh            # Monkey C 单元测试，需先打开 Connect IQ 模拟器
```

## 3. 在 Connect IQ Simulator 验证

1. 打开 `/Applications/ConnectIQ.app`。
2. 菜单选择 `Simulation`，确认设备为 `Forerunner 970`。
3. 如屏幕不是空白，先退出 Simulator，再重新打开，避免旧 PRG 画面残留。
4. 在项目目录执行：

```bash
./scripts/run-sim.sh
```

5. 在模拟器窗口确认圆屏中出现：时间、HR Zone 条和区间胶囊、HR、CAD、Elapsed/Timer、TOTAL DIST、LAP/NOW/AVG 三项配速、单圈时间、单圈距离、电池图标 + 百分比；确认分隔线为中性灰（不是绿色），时钟下方没有横线，没有 PACER 或 PAUSED 文字。
6. 用 macOS 截图工具截取完整 `CIQ Simulator - Forerunner 970` 窗口，不要只截桌面或编辑器。
7. 对本轮结果保存为：

```text
/private/tmp/rundash970-layout-tunable-v3.png
```

模拟器只能证明程序可编译、可加载和基础字段可见，不能证明真机 Cadence 单位或计圈语义。发布态必须保持 `DEBUG_LAYOUT=false`；临时打开调试模式时还应看到安全圆、网格、中心十字和文字框。

## 4. 真机 FR970 安装

以下步骤只能用户在真机完成：

1. 用 USB 连接 FR970，解锁手表，并等待 macOS 挂载手表磁盘。
2. 在已挂载的手表磁盘中打开 `GARMIN/APPS` 目录。
3. 将 `bin/RunDash970-fr970.prg` 复制到 `GARMIN/APPS`。本项目 PRG 是开发者签名文件；Garmin Express 或 Garmin Connect Mobile 不会替代 USB 文件复制来安装任意开发 PRG。
   - 测试 2026-10-10 单圈修复版时，复制的是 `bin/lapfix/RunDash970-fr970-lapfix.prg`（或诊断版 `...-lapfix-eventlog.prg`）。它与旧 PRG 是同一个应用 ID：**先把手表 `GARMIN/APPS` 里旧的 RunDash PRG 移到电脑上备份，再放入新的，不要同时放两个 PRG**；诊断版与正式版也只能放一个。
4. 安全弹出手表并断开 USB。
5. 在手表：`活动` → 选择 `跑步` → `跑步设置` → `数据页`。
6. 新建或选择一个数据页，将字段数量设置为 `1`，选择 `RunDash 970`。

如果手表拒绝安装，记录错误原文，不要删除或覆盖 developer key。

## 5. 开始/暂停/继续/停止/重置

每一步都记录手表上的显示：

1. 站立且未开始活动：确认缺失数据显示 `--` / `--:--`，不崩溃。
2. 按 `START` 开始；确认 Timer、Elapsed 和 Distance 开始更新。
3. 走/跑至少 2 分钟；确认 HR、Cadence、Current Pace 和 Zone 条在有数据后出现。
4. 记录当前 Lap Time、Lap Distance 和 `L` Lap Pace。
5. 按 `UP` 或手表菜单选择暂停；确认 Timer 停止变化且主屏不出现 `PAUSED` 文字。
6. 再次按 `START` 或选择继续；确认 Timer 正常继续，主屏仍不出现 `PAUSED` 文字，并确认之前的 Lap Time、Lap Distance、`L` Lap Pace 连续，不归零。
7. 使用停止/结束操作使活动进入 stopped 状态，再按 `START` 继续；确认 Lap 三项仍连续。这一步专门覆盖 2026-09-10 修复的 stopped→started 路径。
8. 按 `BACK` 结束活动但先不要保存，确认停止状态不会崩溃。
9. 使用 `Discard` / `放弃` 后重新进入跑步活动，执行重置检查。

## 6. 手动计圈

1. 开始一次跑步活动并跑过至少 20 米。
2. 按 `LAP` 键一次。
3. 确认 Lap Time、Lap Distance 和 `L` Lap Pace 从新一圈重新计算。
4. 再按两次 `LAP`，确认每次只重置一次，没有双倍触发或瞬间归零异常。
5. 若使用自动计圈或训练课，分别记录自动计圈是否同样正确。

确认暂停、停止、继续不会触发 Lap 重置；只有实际计圈按钮、自动计圈或训练步骤完成事件才允许重置 Lap 基线。

### 6.1 训练课推进单圈（2026-10-10 修复的核心场景，只能在真机验收）

背景：在 Garmin 结构化训练课里按 `LAP` 推进训练步骤后，旧版的单圈时间/单圈距离没有重新开始（同场运行的 GRun 正常）。旧版没有实现 `onWorkoutStepComplete()`。本版新增该回调，并把手动 Lap、自动 Lap（新旧两种回调）、训练步骤完成统一到同一个基线更新入口。

准备：在 Garmin Connect 建一个包含「按 LAP 结束的步骤」「按时间结束的步骤」「按距离结束的步骤」的间隔训练课并同步到手表，用该训练课开始跑步；数据页字段数为 1，选择 `RunDash 970`。每一行记录实际观察值：

| # | 操作 | 预期 | 实测 |
|---|---|---|---|
| 1 | 训练课某一步按 `LAP` 提前结束 | Lap Time 从 `0:00`～`0:01` 重新开始，Lap Distance 从 `0.00` 附近重新开始；单圈跑过 20 m 后 `L` 配速恢复；TIME / DIST 总计连续不归零 | |
| 2 | 某一步按时间自动结束 | 同上，在步骤切换的同一时刻重置 | |
| 3 | 某一步按距离自动结束 | 同上 | |
| 4 | 非训练课，手动按 `LAP` | 同上，只重置一次 | |
| 5 | 开启自动计圈（按距离或按时间） | 到点自动重置 | |
| 6 | 连续两次手动 `LAP`（间隔 1–2 秒） | 两次都生效，没有被忽略（本版没有任何固定时间冷却） | |
| 7 | 暂停→继续；停止→继续 | Lap 三项连续，不归零 | |
| 8 | 结束并放弃，再开始新活动 | 单圈从新活动起点计算，没有上一场的残留 | |
| 9 | 跑动中在 Connect IQ 应用设置里改兜底最大心率，或在手表里改心率区间 | 应用设置变化立即生效；手表原生区间变化最多约 60 秒后跟上；两种情况 Lap 都不重置 | |

已知计量限制（来自“时间与距离必须取自同一份有效快照”的设计）：
- 圈边界回调读到的活动快照里，时间或距离任一为 `null`/无效时，Lap Time、Lap Distance 显示 `--`、`L` 配速显示 `--:--`（待初始化），直到下一份时间与距离都有效的快照到来，才从该快照开始成对累计；边界到该快照之间的时间和距离不计入新圈。不会把未知值当作 0。
- 若某个活动类型的 `elapsedDistance` 一直为 `null`（例如模拟器 Data Simulation 没有距离源），单圈三项会一直显示占位符（旧版此时仍会显示单圈时间）。跑步活动正常情况下有距离，若真机出现请记录活动类型和 GPS 状态。

回调送达语义（真机待确认，**当前未知**）：训练步骤完成时 FR970 是否同时触发 `onTimerLap2()` / `onTimerLap()`、先后顺序和间隔。本版对同一份快照上的重复通知是幂等的（结果相同），因此无论是否重复都不会多重置；是否需要进一步按事件序列去重，必须先看下面诊断版的真机日志再设计，不要用固定时间冷却。

### 6.2 事件日志诊断版（仅用于验证回调，不是日常使用版）

1. 构建（诊断版只在临时副本里打开日志开关，仓库源码里 `EVENT_LOG` 保持 `false`）：

```bash
./scripts/build-lapfix.sh --eventlog
```

2. 手表接 USB，先移走 `GARMIN/APPS` 里其他 RunDash PRG，把 `bin/lapfix/RunDash970-fr970-lapfix-eventlog.prg` 复制进去。
3. 在手表 USB 卷里新建**空文本文件** `GARMIN/APPS/LOGS/RunDash970-fr970-lapfix-eventlog.TXT`（文件名必须与 PRG 文件名一致，仅扩展名为 `.TXT`；文件不存在时 `System.println` 不会落盘）。
4. 安全弹出，按 §6.1 的场景 1–7 各做一遍（建议每次不超过 10 分钟：日志每秒一行 `TICK`）。
5. 再接 USB，把 `.TXT` 文件复制回电脑。每行格式 `RDEVT seq=<序号> clk=<毫秒> evt=<类型> key=value ...`：

| `evt` | 含义 | 看什么 |
|---|---|---|
| `INIT` / `LAP2` / `LAP` / `STEP` | 圈边界回调（初始化、新版 Lap、旧版 Lap、训练步骤完成） | `t=` 是该回调读到的 `timerTime`，`d=` 是同一份快照的 `elapsedDistance`；`trig=` 是 `onTimerLap2` 的 lapTrigger（含义见 SDK `LapTriggerType`）；`valid=0` 表示快照无效、进入待初始化；`dupSnap=1` 表示与上一基线完全相同的重复通知；`base_before` / `base_after` 是基线前后 |
| `BASELINE` | 待初始化后由 `compute()` 在第一份有效快照上成对建立基线 | 对应 `valid=0` 之后的恢复 |
| `START` / `PAUSE` / `RESUME` / `STOP` / `RESET` / `WORKOUT_STARTED` | 计时器与训练开始事件 | 还原事件顺序，不改基线 |
| `CFG` | 配置读取：`reason=INIT/START/SETTINGS/PERIODIC/ROLLBACK`，`src=user_zones/fallback_maxHr` | `cfgLoads` 只应随初始化、活动开始、设置变化增加；`zoneReads` 约每 60 秒加 1 |
| `TICK` | 每次 `compute()` 一行 | `lapMs` / `lapM` 由新基线算出；`mem=` 为已用内存字节数 |

6. 回传时把 `.TXT` 文件（或围绕每次 Lap / 步骤完成前后各约 5 行）和你当时按键的时间顺序一起发回。判读重点：一次物理操作到底产生了哪几条 `STEP` / `LAP2` / `LAP`、它们的 `clk` 间隔和 `t` 是否相同。

## 7. 检查每个字段

| 字段 | 检查内容 |
|---|---|
| Current Time | 与手表系统时间一致 |
| 标签 | 强光和暗光下，HR / CAD / TIME / DIST / LAP / NOW / AVG / km 都能一眼认出，并且不贴到相邻数值或圆屏边缘（v5 方案 A：标签为加粗近白色 `#E0E0E0`，km 为 `#B0B0B0`，时钟为 `#D0D0D0`） |
| Heart Rate Zone 条 | 五段条出现：当前段全亮色、已经过的段为暗色、未到达的段为灰色；白色三角指向区间内的位置；无 HR 或低于 1.0 时不画三角 |
| Zone 胶囊 | 胶囊（不是圆圈）位于 HR 与 CAD 之间，填当前区间色，内为黑色 1 位小数（如 `2.9`，截断不四舍五入，最大 `6.0`）；无 HR 时胶囊为灰色，文字为 `-.-`；数字上下留白一致，垂直居中，没有黑色方框底 |
| Heart Rate | 与手表原生 HR 页面比较 |
| Cadence | 记录显示数值和原生跑步页面数值 |
| Elapsed Time / Timer | 开始、暂停、继续后连续且合理 |
| Battery | 电池图标 + `xx%` 整组水平居中，图标内填充宽度随电量变化；系统电量不可用时图标内不填充、文字为 `--`；不低于 50% 为浅灰色（`#B0B0B0`），20–49% 为黄色，低于 20% 为红色（图标和文字同色） |
| Elapsed / Total Distance | 与原生距离比较，注意 GPS 初始漂移 |
| Lap Time | 手动计圈后从零开始；格式为 `M:SS`（如 `5:12`、`0:00`、`1:05`），分钟不补零 |
| Lap Distance | 手动计圈后从零开始；单位 km、两位小数，后面跟浅灰色 `km`（`#B0B0B0`） |
| 距离格式 | 第 1 公里内总距离和单圈距离显示 `0.85` 这类两位小数，不再出现 `850m`；刚开始时为 `0.00` |
| 分隔线 | 颜色为中性灰 `#3A3A3A`，时钟下方没有横线；底部只有一条短竖线，不再连到电量 |
| L Lap Pace | 与原生 Lap Pace 比较 |
| C Current Pace | 与原生 Current Pace 比较 |
| A Average Pace | 与原生 Average Pace 比较 |
| Pause 状态 | 仅通过 Timer 是否停止/继续验证；主屏不显示状态文字 |

电量来自 `System.getSystemStats().battery`，应用约每 60 秒读取一次；不要用电量每帧变化作为测试依据。

## 布局调试模式

只在需要定位像素问题时临时修改 `source/RunDash970View.mc` 顶部的 `DEBUG_LAYOUT`：

```monkeyc
hidden var DEBUG_LAYOUT = true;
```

重新编译并加载后，屏幕会显示安全圆、32px 规则网格、中心十字、各文字锚点和近似包围框。调试完成后必须改回 `false` 并重新编译发布 PRG；不要把带网格的截图作为最终验收图。

## 8. 记录 Cadence 单位和 L/C/A 语义

在同一段稳定跑步中同时查看 RunDash 970 和 Garmin 原生数据页：

- Cadence：记录 RunDash 数值、原生数值、单位（RPM/SPM）和活动类型。
- `L`：按一公里计圈后比较原生 Lap Pace。
- `C`：保持稳定配速 30 秒，比较原生 Current Pace。
- `A`：跑过至少 1 公里，比较原生 Average Pace。

不要凭标签名称猜测，必须记录实际观察值。

## 9. 截图回传

截图必须包含完整手表屏幕和字段，不要裁掉圆屏边缘。建议文件名：

```text
rundash970-real-fr970-YYYYMMDD-HHMM.png
```

同时回传以下信息：

- 手表固件版本。
- 活动类型和是否开启 GPS。
- 每个字段的实际读数。
- Cadence 单位。
- L/C/A 对照结果。
- 是否执行了暂停、继续、停止、重置和手动计圈。

## 10. 问题报告模板

```text
RunDash 970 真机问题报告
日期：
FR970 固件：
活动类型：
GPS：开启/关闭
问题发生步骤：
预期结果：
实际结果：
HR / CAD / PACE / DIST / TIMER / BAT：
Lap Time / Lap Distance / L / C / A：
Cadence 单位：
是否暂停/继续/计圈：
截图文件：
手表是否崩溃或重启：
```

## 11. 卸载/回滚

卸载开发字段：在手表的 `活动` → `跑步` → `数据页` 中删除包含 `RunDash 970` 的数据页，然后从 `GARMIN/APPS` 删除对应 PRG；不要删除 Garmin 原生应用。

回滚：重新选择原来的 Garmin 数据页即可。若需要恢复旧的 RunDash PRG，先退出当前活动，再用已验证的旧版本 PRG 覆盖安装；不要在活动进行中替换应用。

回滚 2026-10-10 单圈修复版：
- 手表：删除 `GARMIN/APPS` 里的 `RunDash970-fr970-lapfix*.prg`，把备份的旧 `RunDash970-fr970.prg`（本仓库 `bin/RunDash970-fr970.prg`，构建脚本不会改动它）放回去。同一应用 ID 只能放一个 PRG；若用过诊断版，一并删除 `GARMIN/APPS/LOGS/` 里对应的 `.TXT`。
- 源码：本次只改了 `source/Metrics.mc`、`source/RunDash970App.mc`、`source/RunDash970View.mc`，尚未提交。丢弃改动：`git restore source/Metrics.mc source/RunDash970App.mc source/RunDash970View.mc`；若已提交，用 `git revert <提交>`。
- 新增的测试与脚本（`tests/`、`monkey-test.jungle`、`scripts/build-lapfix.sh`、`scripts/run-unit-tests.sh`、`scripts/mutation_check.py`、`scripts/test_settings_refresh.py`）不参与正式 PRG 构建，可保留或直接删除；`scripts/test_metrics.py`、`scripts/test_lap_lifecycle.py` 是改写过的，需要旧版时同样 `git restore`。

真实手表上的安装、按钮操作、Cadence 单位确认和 L/C/A 语义确认只能由用户完成，本项目不能代替这些物理验证。
