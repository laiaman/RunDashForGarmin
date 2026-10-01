# RunDash 970 布局手工微调指南

本文面向完全不会操作的用户。它只指导布局数字调整，不要求修改 Metrics、manifest、monkey.jungle、其他源码或密钥。

## 1. 推荐用 Cursor 打开项目

推荐使用 Cursor 客户端：

1. 打开 Cursor。
2. 点击菜单 `File` → `Open Folder...`。
3. 输入并打开：

```text
/Users/laiaman/Documents/AICoachPortableOnMac/RunDash970
```

4. 在左侧 Explorer 打开 `source/RunDash970View.mc`。

当前本机 Cursor 版本是 3.16.29，可以编辑普通 Monkey C 文本；当前未检测到 Garmin/Monkey C 扩展，因此编译结果以 Cursor 内置终端执行的 `monkeyc` 脚本为准，不要把编辑器语法高亮当成编译通过。

## 2. 找到 Layout Constants

在 `RunDash970View.mc` 顶部找到：

```monkeyc
// Change only the values in this block when tuning the 454x454 layout.
```

下面直到运行时数据变量之前的区域就是 `Layout Constants`。这里集中放置：

- `LAYOUT_*_X`、`LAYOUT_*_Y`：文字和图形位置。
- `LAYOUT_FONT_*`：按分组统一调字号（见下方字体分组表）。
- `LAYOUT_TEXT_COLOR`、`LAYOUT_LINE_COLOR`：颜色。
- `LAYOUT_ZONE_*`：五段 Zone bar 颜色。
- `LAYOUT_ZONE_CIRCLE_*`：中心 Zone 圆圈位置和半径。
- `LAYOUT_HLINE_*` / `LAYOUT_VLINE_*`：横线与竖线；共用 `LAYOUT_LINE_COLOR`、`LAYOUT_LINE_WIDTH`，端点全部独立。
- `LAYOUT_BATTERY_*`：电量位置、圆半径、刷新间隔与变色阈值/颜色。

### 字体分组（同组改一处即可）

| 变量 | 默认值 | 覆盖范围 |
|------|--------|----------|
| `LAYOUT_FONT_LABEL` | `Graphics.FONT_XTINY` | 标签：HR / Cad / T / D / L / C / A / lap |
| `LAYOUT_FONT_ELAPSED_DISTANCE` | `Graphics.FONT_LARGE` | 累计时间数值 + 总距离数值 |
| `LAYOUT_FONT_CLOCK` | `Graphics.FONT_XTINY` | 顶部时钟 |
| `LAYOUT_FONT_ZONE` | `Graphics.FONT_XTINY` | 心率区间圆圈内数字 |
| `LAYOUT_FONT_BATTERY` | `Graphics.FONT_XTINY` | 底部电量 |
| `LAYOUT_FONT_VALUE` | `Graphics.FONT_SMALL` | 其他数值：HR值 / Cad值 / L·C·A 配速 / Lap Info 时间与距离 |

### 佳明官方字体常量（已核对）

**是的**：`FONT_XTINY`、`FONT_TINY` 等是 Garmin Connect IQ 在 `Toybox.Graphics` 中定义的官方 `FontDefinition` 常量，不是项目自定义数字。本项目只能在这些常量之间切换；**不能**写成 `14`、`18` 这类任意像素字号。

官方文档：[Toybox.Graphics — FontDefinition](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html)

代码里必须写完整前缀，例如：

```monkeyc
hidden var LAYOUT_FONT_VALUE = Graphics.FONT_TINY;
```

| 常量 | 官方说明 | 相对大小（名义顺序） |
|------|----------|----------------------|
| `Graphics.FONT_XTINY` | Extra tiny Connect IQ font | 最小（当前默认） |
| `Graphics.FONT_TINY` | Tiny Connect IQ font | ↑ |
| `Graphics.FONT_SMALL` | Small Connect IQ font | ↑ |
| `Graphics.FONT_MEDIUM` | Medium Connect IQ font | ↑ |
| `Graphics.FONT_LARGE` | Large Connect IQ font | 通用文字最大 |
| `Graphics.FONT_NUMBER_MILD` | 仅数字，普通尺寸 | 数字专用 |
| `Graphics.FONT_NUMBER_MEDIUM` | 仅数字，中等 | ↑ |
| `Graphics.FONT_NUMBER_HOT` | 仅数字，大 | ↑ |
| `Graphics.FONT_NUMBER_THAI_HOT` | 仅数字，超大 | 数字最大 |

补充说明：

- `FONT_SYSTEM_XTINY` … `FONT_SYSTEM_LARGE` 与对应的 `FONT_*` **等价**（历史别名，效果相同）；本项目统一用无 `SYSTEM` 的写法。
- 实际像素高度因设备而异；在 FR970 上改大后务必重新编译并截图，必要时再微调对应 `LAYOUT_*_Y` / `LAYOUT_*_X`。
- `FONT_NUMBER_*` 只适合数字/冒号类内容；标签（如 `HR`、`Cad`、`lap`）请继续用 `FONT_XTINY`～`FONT_LARGE`。
- 若官方预置字号仍不够，才需要自定义字体资源（本项目当前未使用）。

### 数字专用字体：社区推荐（FONT_NUMBER_*）

来源：Garmin Connect IQ 开发者论坛常见实践（非官方硬性规范）。代表性讨论：

- [FONT_NUMBER_* and alpha characters](https://forums.garmin.com/developer/connect-iq/f/discussion/400036/font_number_-and-alpha-characters)
- [Advice on consistent device layout design](https://forums.garmin.com/developer/connect-iq/f/discussion/270150/advice-on-consistent-device-layout-design)
- [Thai Hot Font, not so Thai, more Hot](https://forums.garmin.com/developer/connect-iq/f/discussion/1378/thai-hot-font-not-so-thai-more-hot)

**核心结论：**

1. `FONT_NUMBER_*` 是为大数字设计的受限字符集字体（省内存），名义大小：`MILD` → `MEDIUM` → `HOT` → `THAI_HOT`。
2. **没有万能推荐档**；同名常量在不同机型上的实际像素高度差异很大，名称只是 guideline。
3. **标签绝不要用** `FONT_NUMBER_*`（字母会缺字/方框）。
4. 数字字体通常支持的字符大约是：`0-9`、`:`、`.`、`+`、`-`、`/`、`%`、`#`、`( )`、`°`；带 `km`、`HR`、`lap` 等字母的字符串不要用。
5. 更稳妥做法：用 `dc.getTextDimensions` / `dc.getFontHeight` 量完再选最大能放下的字号；本项目当前手工调常量即可。

**场景对照（社区常见选择）：**

| 场景 | 更常见的选择 |
|------|----------------|
| 主配速 / 主时间（独占大块区域） | `FONT_NUMBER_HOT` 或 `FONT_NUMBER_THAI_HOT` |
| 中等强调数值（HR、距离、次要配速） | `FONT_NUMBER_MEDIUM` 或 `FONT_NUMBER_MILD` |
| 多字段挤在一屏（如本 RunDash） | 多数从 `MILD` / `MEDIUM` 起步，很少直接 `THAI_HOT` |
| 系统字仍不够大 / 要跨机统一字形 | 自定义字体（表盘更常见；本项目暂未用） |

**对本项目 RunDash 970 的实用建议：**

| 字段组变量 | 建议尝试顺序 | 注意 |
|------------|--------------|------|
| `LAYOUT_FONT_ELAPSED_DISTANCE`（累计时间 / 总距离数值） | `NUMBER_MEDIUM` → 不够空再降 `MILD`；够空可试 `HOT` | 距离若显示含字母单位（如 `km`），改回 `FONT_TINY`/`SMALL` |
| `LAYOUT_FONT_VALUE`（HR / Cad / L·C·A / Lap Info 数值） | 先 `NUMBER_MILD`，再视空间 `MEDIUM` | 一屏字段多，慎用 `HOT`/`THAI_HOT` |
| `LAYOUT_FONT_CLOCK` | `NUMBER_MILD` 或 `NUMBER_MEDIUM` | 仅 `HH:MM`，适合数字字体 |
| `LAYOUT_FONT_ZONE` | 通常继续 `FONT_XTINY`～`SMALL` | 圆圈内空间小，数字字体外边距大，易溢出 |
| `LAYOUT_FONT_BATTERY` | `NUMBER_MILD` 或普通 `TINY` | `85%` 一般可用；确认 `--` 显示正常 |
| `LAYOUT_FONT_LABEL` | 只用 `FONT_XTINY`～`FONT_LARGE` | **禁止** `FONT_NUMBER_*` |

改用 `FONT_NUMBER_*` 后，几乎一定要再调对应行的 `LAYOUT_*_Y` / `LAYOUT_*_X`，因为数字字体的 ascent/descent（上下空白）通常比普通字更大。

调字号示例：

```monkeyc
// 标签保持普通文字字体（禁止 NUMBER_*）
hidden var LAYOUT_FONT_LABEL = Graphics.FONT_XTINY;

// 累计时间 + 总距离：数字专用中等
hidden var LAYOUT_FONT_ELAPSED_DISTANCE = Graphics.FONT_NUMBER_MEDIUM;

// 其他数值：数字专用普通
hidden var LAYOUT_FONT_VALUE = Graphics.FONT_NUMBER_MILD;

// 时钟：数字专用
hidden var LAYOUT_FONT_CLOCK = Graphics.FONT_NUMBER_MILD;

// Zone / 电量：先保持小字，再按空间单独试
hidden var LAYOUT_FONT_ZONE = Graphics.FONT_XTINY;
hidden var LAYOUT_FONT_BATTERY = Graphics.FONT_XTINY;
```

### 标签/数值 X 坐标分离

将每个显示元素的**标签**（如 HR、Cad、T、D、L、C、A、lap）与**数据数值**拆成独立 X 坐标，可分别移动。Y 仍由各行 `LAYOUT_*_Y` 控制。

| 变量 | 默认值 | 用途 |
|------|--------|------|
| **颜色** | | |
| `LAYOUT_LABEL_COLOR` | `COLOR_WHITE` | 标签颜色（可调暗以区分标签和数值） |
| **HR / Cad 行** | | |
| `LAYOUT_HR_CAD_LABEL_Y` | 75 | **仅** "HR" / "Cad" 标签共用 Y（不与数值、Zone 共用） |
| `LAYOUT_HR_LABEL_X` | 100 | "HR" 标签 X 坐标 |
| `LAYOUT_HR_VALUE_X` | 152 | 心率数值 X 坐标 |
| `LAYOUT_HR_VALUE_Y` | 75 | 心率数值 Y（独立） |
| `LAYOUT_CAD_LABEL_X` | 304 | "Cad" 标签 X 坐标 |
| `LAYOUT_CAD_VALUE_X` | 354 | 步频数值 X 坐标 |
| `LAYOUT_CAD_VALUE_Y` | 75 | 步频数值 Y（独立） |
| **累计时间行 (T)** | | |
| `LAYOUT_TD_LABEL_X` | 22 | "T" 与 "D" 标签共用 X（向左只改这一处） |
| `LAYOUT_ELAPSED_LABEL_Y` | 175 | "T" 标签 Y（独立，不与数值共用） |
| `LAYOUT_ELAPSED_VALUE_X` | 250 | 累计时间数值 X 坐标 |
| `LAYOUT_ELAPSED_VALUE_Y` | 175 | 累计时间数值 Y（独立） |
| **总距离行 (D)** | | |
| `LAYOUT_DISTANCE_LABEL_Y` | 275 | "D" 标签 Y（X 用 `LAYOUT_TD_LABEL_X`） |
| `LAYOUT_DISTANCE_LABEL_Y` | 275 | "D" 标签 Y（独立，不与数值共用） |
| `LAYOUT_DISTANCE_VALUE_X` | 250 | 总距离数值 X 坐标 |
| `LAYOUT_DISTANCE_VALUE_Y` | 275 | 总距离数值 Y（独立） |
| **单圈配速行 (L)** | | |
| `LAYOUT_LAP_PACE_LABEL_X` | 197 | "L" 标签 X 坐标 |
| `LAYOUT_LAP_PACE_LABEL_Y` | 158 | "L" 标签 Y（独立，不与数值共用） |
| `LAYOUT_LAP_PACE_VALUE_X` | 250 | 单圈配速数值 X 坐标 |
| `LAYOUT_LAP_PACE_VALUE_Y` | 158 | 单圈配速数值 Y（独立） |
| **当前配速行 (C)** | | |
| `LAYOUT_CURRENT_PACE_LABEL_X` | 197 | "C" 标签 X 坐标 |
| `LAYOUT_CURRENT_PACE_LABEL_Y` | 190 | "C" 标签 Y（独立，不与数值共用） |
| `LAYOUT_CURRENT_PACE_VALUE_X` | 250 | 当前配速数值 X 坐标 |
| `LAYOUT_CURRENT_PACE_VALUE_Y` | 190 | 当前配速数值 Y（独立） |
| **平均配速行 (A)** | | |
| `LAYOUT_AVERAGE_PACE_LABEL_X` | 197 | "A" 标签 X 坐标 |
| `LAYOUT_AVERAGE_PACE_LABEL_Y` | 222 | "A" 标签 Y（独立，不与数值共用） |
| `LAYOUT_AVERAGE_PACE_VALUE_X` | 250 | 平均配速数值 X 坐标 |
| `LAYOUT_AVERAGE_PACE_VALUE_Y` | 222 | 平均配速数值 Y（独立） |
| **合并单圈信息行** | | |
| `LAYOUT_LAP_INFO_Y` | 385 | 单圈时间/距离数值 Y |
| `LAYOUT_LAP_INFO_T_X` | 90 | 左侧 "T" 标签 X 坐标 |
| `LAYOUT_LAP_INFO_T_Y` | 385 | 左侧 "T" 标签 Y（独立） |
| `LAYOUT_LAP_INFO_TIME_X` | 152 | 单圈时间数值 X 坐标 |
| `LAYOUT_LAP_INFO_LAP_X` | 227 | 中间 "lap" 文字 X 坐标 |
| `LAYOUT_LAP_INFO_LAP_Y` | 385 | 中间 "lap" 文字 Y（独立） |
| `LAYOUT_LAP_INFO_DIST_X` | 300 | 单圈距离数值 X 坐标 |
| `LAYOUT_LAP_INFO_D_X` | 362 | 右侧 "D" 标签 X 坐标 |
| `LAYOUT_LAP_INFO_D_Y` | 385 | 右侧 "D" 标签 Y（独立） |

### 绘制函数说明

| 函数 | 使用的字体 | 用途 |
|------|-----------|------|
| `drawLabel(dc, x, y, text)` | `LAYOUT_FONT_LABEL` | 绘制标签 |
| `drawValue(dc, x, y, text)` | `LAYOUT_FONT_VALUE` | 绘制其他数据数值 |
| `drawTextAt(dc, x, y, text, color, font)` | 传入字体 | 时钟 / Zone / 电量 / 累计时间与总距离 |
| `drawDebugBox(dc, x, y, text, font)` | 传入字体 | 调试边界框（自动调用） |

后续只改这里的数字或颜色值。不要移动 `drawText`、`drawLine`、`drawCircle` 调用，也不要把 PACER 或 PAUSED 文字加回去。

## 3. X/Y、字号和颜色怎么理解

在 454×454 画布中：

- X 向右增加，向左减少。
- Y 向下增加，向上减少。
- `LAYOUT_CENTER_X = 227` 是圆屏中心。
- 主屏文字使用 `Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER`，所以 X/Y 是文字中心点，不是左上角或 baseline。
- `LAYOUT_FONT_*` 必须赋值为佳明官方 `Graphics.FONT_*` 常量（见上文「佳明官方字体常量」）；默认 `Graphics.FONT_XTINY`。改某一组后必须重新编译并截图检查。
- 颜色使用十六进制 RGB，例如 `0xFFFFFF` 是白色，`0x006B3C` 是深绿色。

每轮只调整 4–8px。例如：

```text
LAYOUT_LAP_TIME_Y = 279
```

想向下移动时改成 `283` 或 `287`；想向上移动时改成 `275`。一次不要同时大幅修改很多行，否则无法判断是哪一项造成重叠。

## 4. 增加或移动横线与圆圈

所有分隔线共用：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `LAYOUT_LINE_COLOR` | `0x006B3C` | 线颜色（深绿） |
| `LAYOUT_LINE_WIDTH` | `2` | 线宽/粗细（像素），全部横线 + 竖线共用 |

每条线的端点全部独立，互不影响。

**横线**（每条：`LEFT` / `RIGHT` / `Y`）：搜 `LAYOUT_HLINE_*`

**竖线 1–2**（每条：`X` / `TOP` / `BOTTOM`）：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `LAYOUT_VLINE_1_X` | 300 | 竖线 1 水平位置 |
| `LAYOUT_VLINE_1_TOP` | 120 | 竖线 1 上端 Y |
| `LAYOUT_VLINE_1_BOTTOM` | 340 | 竖线 1 下端 Y |
| `LAYOUT_VLINE_2_X` | 154 | 竖线 2 水平位置 |
| `LAYOUT_VLINE_2_TOP` | 120 | 竖线 2 上端 Y |
| `LAYOUT_VLINE_2_BOTTOM` | 340 | 竖线 2 下端 Y |

调参示例：

```monkeyc
// 所有线一起加粗
hidden var LAYOUT_LINE_WIDTH = 3;

// 只改第 2 条竖线的左右和上下端
hidden var LAYOUT_VLINE_2_X = 180;
hidden var LAYOUT_VLINE_2_TOP = 140;
hidden var LAYOUT_VLINE_2_BOTTOM = 320;
```

横线应放在两行文字之间，不能穿过文字中心。发布绘制顺序是：调试网格/安全圆/中心十字（仅 DEBUG）→ 分隔线（横线 + 竖线）→ Zone bar 和 Zone 圆圈 → 主屏文字 → SDK 实测文字框和锚点（仅 DEBUG）。

Zone bar 由以下常量控制：

- `LAYOUT_ZONE_BAR_X`
- `LAYOUT_ZONE_BAR_Y`
- `LAYOUT_ZONE_BAR_WIDTH`
- `LAYOUT_ZONE_BAR_HEIGHT`

中心绿色 Zone 圆圈由以下常量控制：

- `LAYOUT_ZONE_CIRCLE_X`
- `LAYOUT_ZONE_CIRCLE_Y`
- `LAYOUT_ZONE_CIRCLE_RADIUS`

圆圈内只显示短文本区间数字或 `-`，不要放入 `ZONE` 等长文本。

### 电量椭圆与变色（结构同心率区间圆）

电量文字居中画在椭圆内，中心：

- `LAYOUT_BATTERY_CIRCLE_X`
- `LAYOUT_BATTERY_CIRCLE_Y`

用 `dc.drawEllipse(x, y, a, b)`：`a` 为水平半径，`b` 为垂直半径（上下更窄）。

| 变量 | 默认 | 说明 |
|------|------|------|
| `LAYOUT_BATTERY_ELLIPSE_PAD_X` | 6 | 文字半宽之外的水平边距 |
| `LAYOUT_BATTERY_ELLIPSE_PAD_Y` | 2 | 文字半高之外的垂直边距（贴合数字高度） |
| `LAYOUT_BATTERY_ELLIPSE_A_MIN` | 22 | 水平半径下限 |
| `LAYOUT_BATTERY_ELLIPSE_B_MIN` | 10 | 垂直半径下限 |

实际半径：水平 `a` 固定按 `"100%"` 实测半宽 + `PAD_X` 预留（电量从 `5%` 到 `100%` 椭圆宽度不变）；垂直 `b = max(B_MIN, 当前文字半高+PAD_Y)`。想更扁就减小 `PAD_Y` / `B_MIN`。

文字与椭圆颜色随电量百分比变化（`batteryColor()`）：

| 条件 | 默认阈值 | 颜色变量 | 默认色 |
|------|----------|----------|--------|
| 电量未知（`--`） | — | `LAYOUT_BATTERY_COLOR_UNKNOWN` | 白 |
| `>= LAYOUT_BATTERY_HIGH_PCT` | 50 | `LAYOUT_BATTERY_COLOR_HIGH` | 绿 `0x00B050` |
| `>= LAYOUT_BATTERY_MID_PCT` | 20 | `LAYOUT_BATTERY_COLOR_MID` | 黄 `0xFFB000` |
| `< MID` | — | `LAYOUT_BATTERY_COLOR_LOW` | 红 `0xFF1010` |

调参示例：

```monkeyc
hidden var LAYOUT_BATTERY_ELLIPSE_PAD_X = 8;  // 左右更松
hidden var LAYOUT_BATTERY_ELLIPSE_PAD_Y = 1;  // 上下更贴数字
hidden var LAYOUT_BATTERY_ELLIPSE_B_MIN = 8;  // 更扁
```

电量约每 `LAYOUT_BATTERY_REFRESH_MS`（默认 60s）刷新一次。

## 5. 如何开启 DEBUG_LAYOUT

默认值必须是：

```monkeyc
hidden var DEBUG_LAYOUT = false;
```

需要定位时临时改为：

```monkeyc
hidden var DEBUG_LAYOUT = true;
```

调试模式会增加安全圆、规则网格、中心十字、每个实际文字的 SDK 实测包围框和中心锚点。它只在 `DEBUG_LAYOUT=true` 时调用，生产态 `false` 不执行这些绘制；背景调试图形先画，实测框和锚点最后画。

调试截图建议保存为：

```text
/private/tmp/rundash970-layout-debug-v3.png
```

调试完成后必须改回 `false`，再重新编译最终 PRG。最终截图不能带网格和包围框。

## 6. 保存和编译

在 Cursor 中按 `Cmd+S` 保存。打开菜单 `Terminal` → `New Terminal`，在项目根目录执行：

```bash
cd /Users/laiaman/Documents/AICoachPortableOnMac/RunDash970
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
python3 scripts/test_metrics.py
./scripts/build.sh .secrets/developer_key.der
```

必须看到：

```text
PASS: scripts/test_metrics.py — all deterministic Metrics mirrors OK
BUILD SUCCESSFUL
```

编译 warning 和 error 都必须为 0。不要用旧的 `bin/RunDash970-fr970.prg` 代替新编译产物。

只改布局常量时，日常可跳过 `test_metrics.py`，直接 build；生命周期相关改动仍建议跑全测。

## 7. 启动/重载 Simulator

**不是每次都要退出重开。** 改布局后看效果，优先用下面的快捷流程。

### 7.1 日常快捷流程（推荐）

前提：Connect IQ Simulator **已经开着**，设备选的是 `Forerunner 970`。

1. 改完 `RunDash970View.mc`，`Cmd+S` 保存。
2. 终端执行编译 + 重载（Simulator 不用关）：

```bash
cd /Users/laiaman/Documents/AICoachPortableOnMac/RunDash970
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
./scripts/build.sh .secrets/developer_key.der
./scripts/run-sim.sh
```

`run-sim.sh` 内部就是 `monkeydo bin/RunDash970-fr970.prg fr970`：往**已运行**的 Simulator 推送新 PRG。多数情况下这一步就够。

更短写法（同一终端会话里 `JAVA_HOME`/`PATH` 已 export 过时）：

```bash
./scripts/build.sh .secrets/developer_key.der && ./scripts/run-sim.sh
```

### 7.2 首次启动（Simulator 还没开）

1. 打开 `/Applications/ConnectIQ.app`（或 SDK 自带的 `connectiq`）。
2. 确认设备是 `Forerunner 970`。
3. 再执行上面的 `build` + `run-sim.sh`。

### 7.3 完整退出重开（仅故障时）

出现以下情况再完整重启：

- 提示 `Unable to connect to simulator`
- 画面明显不是刚编译的版本（旧布局残留）
- Simulator 卡住、黑屏、无响应

步骤：

1. 退出正在运行的 Connect IQ Simulator。
2. 重新打开 `/Applications/ConnectIQ.app`。
3. 确认设备是 `Forerunner 970`。
4. 重新 `build` + `run-sim.sh`。

也可先确认 PRG 是否真的更新了：

```bash
ls -l bin/RunDash970-fr970.prg
```

修改时间应接近刚才的 build 时间。

### 7.4 没有「热重载」这件事

Connect IQ **不会**在你保存 `.mc` 后自动刷新表盘。必须：

`保存 → monkeyc 编译出新 .prg → monkeydo 推到 Simulator`

没有比这更短的官方路径；省掉的只是「退出/重开 Simulator」这一步。

## 8. 截完整窗口

截图必须包含完整标题栏 `CIQ Simulator - Forerunner® 970`、完整手表和底部状态栏，不要只截圆屏或 Cursor 编辑器。最终布局截图使用：

```text
/private/tmp/rundash970-layout-tunable-v3.png
```

如果使用 macOS 截图工具，先点击模拟器标题栏使它成为前台窗口，再选择窗口截图。

## 9. 验收清单

发布态 `DEBUG_LAYOUT=false` 时逐项确认：

- [ ] Current Time 出现且在圆屏安全区内。
- [ ] HR 和 CAD 没有横向相碰。
- [ ] 五段彩色 Zone bar 出现。
- [ ] 绿色圆圈内只有 `Z1`–`Z5` 或 `Z-`。
- [ ] ELAPSED、TOTAL DIST、L、C、A、LAP TIME、LAP DIST 均出现。
- [ ] BAT 显示 `BAT xx%` 或 `BAT --`。
- [ ] PACER 不出现。
- [ ] PAUSED 不出现。
- [ ] 横线不穿过任何文字。
- [ ] 没有明显整块重叠、字符残留或圆屏边缘裁切。
- [ ] Metrics 通过，编译 warning/error 均为 0。

电量通过 `System.getSystemStats().battery` 获取并约每 60 秒刷新一次；首次没有可用值时显示 `BAT --`，不要要求它每帧变化。

## 10. 关闭 DEBUG 并做 release build

确认调试截图后：

1. 把 `DEBUG_LAYOUT` 改回 `false`。
2. 按 `Cmd+S`。
3. 退出并重启 Simulator，避免旧调试帧残留。
4. 重新执行 Metrics 和 build 命令。
5. 重新加载 PRG，确认网格、十字和包围框都消失。
6. 只把无调试图形的截图作为最终截图。

## 11. 备份和回滚上一版 PRG

在覆盖 build 之前可在终端备份：

```bash
cp bin/RunDash970-fr970.prg /private/tmp/RunDash970-fr970.previous.prg
```

回滚时先退出 Simulator，再恢复并重新加载：

```bash
cp /private/tmp/RunDash970-fr970.previous.prg bin/RunDash970-fr970.prg
```

如果备份不存在，使用 Git 或项目外部备份恢复，不要删除 developer key。

## 12. 常见报错

- `Unable to locate a Java Runtime`：先设置上面的 `JAVA_HOME` 和 `PATH`，确认 `java -version` 显示 OpenJDK 17。
- `BUILD SUCCESSFUL` 但模拟器画面没变化：先再跑一次 `./scripts/run-sim.sh`；仍旧则退出并重开 Simulator，再 build + `run-sim.sh`，并确认 `bin/RunDash970-fr970.prg` 的修改时间。
- `The simulator must be running` / `Unable to connect to simulator`：先打开 Connect IQ Simulator，等界面起来后再执行 `run-sim.sh`；仍失败再完整退出重开（见 §7.3）。
- 安装时提示签名或权限错误：确认使用项目原有 `.secrets/developer_key.der`，不要生成新 key 覆盖旧 key。
- 文字重叠：只改对应 `LAYOUT_*_Y` 或 X 常量 4–8px，再完整执行测试、build、重载和截图。

## 13. 如何反馈给主模型

每次反馈请同时提供：

1. 截图路径或截图文件。
2. 元素名称：例如 `LAP TIME`、`BAT`、`ZONE 圆圈`。
3. 方向：向上、向下、向左、向右，或“与哪一项重叠”。
4. 像素建议：例如“`BAT` 向上 6px”或“分隔线向下 4px”。
5. 是否开启了 `DEBUG_LAYOUT`。
6. Metrics 输出和编译 warning/error 输出。

示例：

```text
截图：/private/tmp/rundash970-layout-debug-v3.png
元素：BAT
问题：距离 LAP DIST 太近
建议：BAT 向下 6px
DEBUG_LAYOUT：true
```

## 14. 2026-09-10 Lap 生命周期回归

本轮只修复生命周期，不改变布局坐标。暂停、停止、继续和再次开始都不能移动 Lap 基线；`onTimerStart()` 只更新内部暂停状态。只有首次会话建立基线、真实 `onTimerLap2()`、`onTimerReset()` 或新会话才会改变/清空基线。

布局调试后可在终端执行：

```bash
python3 scripts/test_metrics.py
python3 scripts/test_lap_lifecycle.py
./scripts/build.sh .secrets/developer_key.der
```

真机复测时，先记录 Lap Time、Lap Distance、`L` Lap Pace，再执行暂停→继续和停止→继续；两条路径都不得让这三个值归零。按 `LAP` 后才应恰好重置一次。该行为不能仅由布局截图证明。
