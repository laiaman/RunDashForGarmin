# BUILD_REPORT — RunDash 970

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
