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
./scripts/build.sh .secrets/developer_key.der
```

确认输出为 `PASS` 和 `BUILD SUCCESSFUL`，并确认文件存在：

```bash
ls -l bin/RunDash970-fr970.prg
```

## 3. 在 Connect IQ Simulator 验证

1. 打开 `/Applications/ConnectIQ.app`。
2. 菜单选择 `Simulation`，确认设备为 `Forerunner 970`。
3. 如屏幕不是空白，先退出 Simulator，再重新打开，避免旧 PRG 画面残留。
4. 在项目目录执行：

```bash
./scripts/run-sim.sh
```

5. 在模拟器窗口确认圆屏中出现：时间、HR Zone 条/当前 ZONE、HR、CAD、Elapsed/Timer、TOTAL DIST、L/C/A、Lap Time、Lap Distance、BAT；确认没有 PACER 或 PAUSED 文字。
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

确认暂停、停止、继续不会触发 Lap 重置；只有实际计圈按钮或自动计圈事件才允许重置 Lap 基线。

## 7. 检查每个字段

| 字段 | 检查内容 |
|---|---|
| Current Time | 与手表系统时间一致 |
| Heart Rate Zone | 彩色五段条出现；当前区间为 `Z1`–`Z5`，无 HR 时为 `ZONE --` |
| Heart Rate | 与手表原生 HR 页面比较 |
| Cadence | 记录显示数值和原生跑步页面数值 |
| Elapsed Time / Timer | 开始、暂停、继续后连续且合理 |
| Battery | 显示 `BAT xx%`；系统电量不可用时显示 `BAT --` |
| Elapsed / Total Distance | 与原生距离比较，注意 GPS 初始漂移 |
| Lap Time | 手动计圈后从零开始 |
| Lap Distance | 手动计圈后从零开始 |
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

真实手表上的安装、按钮操作、Cadence 单位确认和 L/C/A 语义确认只能由用户完成，本项目不能代替这些物理验证。
