# BUILD_REPORT — RunDash 970

## 2026-10-10 训练课单圈重置 + 配置读取优化（本轮）

目标：Garmin Forerunner 970（`fr970`）。范围：`source/Metrics.mc`、`source/RunDash970App.mc`、`source/RunDash970View.mc`；布局、颜色、字体、单位、数据语义、设备列表、SDK 最低版本均未改（`manifest.xml` 未动）。

**这是编译与模拟器/单元测试层面的结果，不是真机验收；“编译成功”不代表训练课按 Lap 推进步骤后单圈重置的问题已在手表上解决（`PENDING_PHYSICAL_DEVICE`）。**

### 构建命令与产物

```bash
scripts/build-lapfix.sh              # 正式版（EVENT_LOG = false，运行时不输出日志）
scripts/build-lapfix.sh --eventlog   # 诊断版（在临时副本里把 EVENT_LOG 置 true，仓库源码不改）
```

| 产物 | 路径（`bin/lapfix/`，已被 `.gitignore` 忽略） | 大小 | SHA-256 | 用途 |
|---|---|---|---|---|
| 正式版 | `RunDash970-fr970-lapfix.prg` | 128,316 B | `4a941eff8e3f4537a493c90987f9f73e495dc3495d25e8ae8309fef532ffef4a` | **真机验收用** |
| 诊断版（可选） | `RunDash970-fr970-lapfix-eventlog.prg` | 128,492 B | `779668762e348fcb782a8c9cfd185a26685c534a72ba6eeb4074a464176cb812` | 只在需要确认 FR970 回调顺序时用，见 `MANUAL_VALIDATION.md` §6.2 |
| 原产物（未改动） | `bin/RunDash970-fr970.prg` | — | `f0552d3bb39329ef4c8dce1bfe97256ed90b75769988c81e6e1a2486932b8e1d` | 回退用（HEAD `aef7424` 的构建） |

- 每个产物旁有 `BUILD_INFO-formal.txt` / `BUILD_INFO-eventlog.txt`（构建时间、git HEAD、哈希、警告数、原产物哈希），以及同名 `.prg.debug.xml` 与 `-settings.json`。
- 正式版用相同源码连续构建两次得到相同 SHA-256；诊断版在临时目录里编译，相同源码两次构建的 SHA-256 不同（大小相同），推测与临时路径有关，**以对应 `BUILD_INFO-eventlog.txt` 为准**。
- 手表上同一个 app ID 同时只会有一个 PRG，正式版与诊断版不要同时拷贝（见 `MANUAL_VALIDATION.md` §4）。
- 脚本不输出也不修改签名密钥；不安装到手表、不发布商店、不推送远端；本轮没有提交 git。
- 体积：HEAD 源码重编 121,964 B → 新正式版 128,316 B（+6,352 B，主要是新的单圈/配置逻辑与受 `EVENT_LOG` 保护的临时日志代码）。

### 编译警告

4 条 `Metrics.mc` “Cannot determine if container access is using container type.”（`hrZoneValue` 里 `zones[...]`，行 192/201/207/209）。重编 HEAD 源码同样是这 4 条，不是本轮引入；新增代码没有带来新警告。错误 0。

### 全机型回归编译（`manifest.xml` 12 个机型，输出到 `/tmp`，不写 `bin/`）

| 机型 | 结果 | 警告 / 错误 |
|---|---|---|
| `fr970`、`fr965`、`fr57047mm`、`venu445mm`、`fenix847mm`、`fenix8pro47mm`、`fenix947mm`、`fenix9pro47mm`、`d2mach2`、`d2mach2pro` | OK | 4 / 0（仅上述基线警告） |
| `venu3`、`epix2pro51mm` | OK | 5 / 0（基线 4 条 + 1 条启动图标尺寸警告，资源问题，与本轮无关） |

只证明这些机型能编译，没有在这些机型的模拟器或真机上运行。

### 测试

Python 模型/静态 3 个脚本全部 PASS；Monkey C 单元测试 25/25 PASS；变异验证 12/12 被发现。细节与“未覆盖项”见 `TEST_REPORT.md`。

### 回退

见 `MANUAL_VALIDATION.md` §11：恢复使用 `bin/RunDash970-fr970.prg`（未改动），源码用 `git restore source/Metrics.mc source/RunDash970App.mc source/RunDash970View.mc`；新增的测试/脚本文件可保留也可删除。

---

## 2026-09-10 记录（Lap 生命周期修复，历史）

日期：2026-09-10  
目标：Garmin Forerunner 970（`fr970`）  
本轮范围：Lap 生命周期修复；布局、DEBUG_LAYOUT、电量缓存和 HR Zone 保持不变

## 环境

| 项目 | 实际结果 |
|---|---|
| OS | macOS Darwin 25.5.0 |
| Java | Homebrew OpenJDK 17.0.20.1 |
| Connect IQ SDK | 9.2.0 |
| `monkeyc` / `monkeydo` | `/usr/local/bin/monkeyc`、`/usr/local/bin/monkeydo` |
| `fr970` 支持 | SDK 已提供并成功编译、加载 |
| Developer key | 使用项目现有私有 key；未打印、未提交 |

## 实际构建

```bash
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
python3 scripts/test_metrics.py
python3 scripts/test_lap_lifecycle.py
./scripts/build.sh .secrets/developer_key.der
```

结果：

```text
PASS: scripts/test_metrics.py — all deterministic Metrics mirrors OK
BUILD SUCCESSFUL
```

Lap 生命周期回归测试结果：

```text
PASS: test_lap_lifecycle.py — Lap lifecycle invariants OK
```

编译警告：0  
编译错误：0  

DEBUG_LAYOUT=true 调试态也已单独编译通过，警告 0、错误 0，并生成 `/private/tmp/rundash970-layout-debug-v3.png`；随后已恢复 `DEBUG_LAYOUT=false` 并重新编译最终 PRG。

PRG：`bin/RunDash970-fr970.prg`  
调试产物：`bin/RunDash970-fr970.prg.debug.xml`  
截图：`/private/tmp/rundash970-lap-pause-fix.png`

## 模拟器结果

已重启 Connect IQ Simulator，清屏后加载本轮刚编译的 PRG，并截取真实 `CIQ Simulator - Forerunner 970` 窗口。发布态 `DEBUG_LAYOUT=false`。截图用于确认 BAT、五段 Zone bar、绿色 Z 圆圈和深绿色分隔线出现，PACER/PAUSED 不出现，其他字段未发生整块重叠或圆屏裁切，结果为 PASS。

电量通过 `System.getSystemStats().battery` 读取，并由 `mBatteryLastRefreshMs` 按约 60 秒缓存；初始化默认 `BAT --`，有效范围限定为 0–100。

2026-09-10 修复：`onTimerStart()` 不再调用 `resetLapBaselineFromActivity()`，避免 stopped→started 或 pause→resume 路径将 Lap Time、Lap Distance、Lap Pace 错误归零。

## 未完成项目

真实 FR970 手表安装、开始/暂停/继续/停止/重置、手动计圈、Cadence 单位和 L/C/A 语义仍需用户在真机完成，状态为 `PENDING_PHYSICAL_DEVICE`。详见 `MANUAL_VALIDATION.md`。
