#!/usr/bin/env bash
# 编译并在 Connect IQ 模拟器里运行 Monkey C 单元测试（tests/RunDash970Tests.mc，jungle: monkey-test.jungle）。
#
# 前置：Connect IQ 模拟器已启动（终端运行 `connectiq`，或打开 ConnectIQ.app）。
# 产物只写到临时目录（默认 /tmp/rundash-unit-tests），不触碰 bin/，也不会输出开发者密钥内容。
# 用法：scripts/run-unit-tests.sh [输出目录]
# 退出码：0 = 全部通过；1 = 有失败/错误；2 = 编译失败或环境不满足。
#
# 注意：这是在模拟器 VM 里跑“真实编译后的” View/App/Metrics 逻辑（外部读取点由测试子类注入），
# 不能证明真机是否送达 onWorkoutStepComplete / onTimerLap2，那部分见 MANUAL_VALIDATION.md 的事件日志验收。
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="${RUNDASH_KEY:-$PWD/.secrets/developer_key.der}"
[[ -f "$KEY" ]] || KEY="$HOME/.connectiq/developer_key.der"
if [[ ! -f "$KEY" ]]; then
  echo "找不到开发者密钥。请设置 RUNDASH_KEY，或放到 .secrets/developer_key.der" >&2
  exit 2
fi

# macOS 的 /usr/bin/java 只是占位 stub：没有可用 Java 时，尝试 Homebrew 的 openjdk@17。
if ! java -version >/dev/null 2>&1; then
  for J in /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
           /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
    if [[ -x "$J/bin/java" ]]; then
      export JAVA_HOME="$J"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
fi
if ! java -version >/dev/null 2>&1; then
  echo "找不到可用的 Java（monkeyc 需要）。请安装 JDK 17 或设置 JAVA_HOME" >&2
  exit 2
fi

if ! pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1; then
  echo "Connect IQ 模拟器未运行：请先在另一个终端执行 connectiq，或打开 ConnectIQ.app" >&2
  exit 2
fi

OUT="${1:-/tmp/rundash-unit-tests}"
mkdir -p "$OUT"
PRG="$OUT/rd_unit_tests.prg"
LOG="$OUT/result.log"

echo "==> 编译单元测试（monkeyc -t，fr970）"
if ! monkeyc -t -d fr970 -f monkey-test.jungle -o "$PRG" -y "$KEY" -w; then
  echo "单元测试编译失败" >&2
  exit 2
fi

echo "==> 在模拟器里运行（最长 180 秒）"
: > "$LOG"
monkeydo "$PRG" fr970 -t > "$LOG" 2>&1 &
MPID=$!
SECS=0
while kill -0 "$MPID" 2>/dev/null; do
  sleep 1
  SECS=$((SECS + 1))
  if (( SECS >= 180 )); then
    echo "超时 180 秒：终止 monkeydo（模拟器可能卡住，可退出并重开 ConnectIQ.app 再试）" >&2
    # monkeydo 是脚本，真正干活的是它启动的 Java 进程，两者都要结束
    pkill -f "MonkeyDoDeux.*${PRG}" 2>/dev/null || true
    kill "$MPID" 2>/dev/null || true
    break
  fi
done
wait "$MPID" 2>/dev/null || true
cat "$LOG"

if grep -q "^PASSED" "$LOG" && ! grep -Eq "^FAILED|ERROR$" "$LOG"; then
  echo "==> 单元测试全部通过 (日志: ${LOG})"
  exit 0
fi
echo "==> 单元测试存在失败或错误，或未得到结果 (日志: ${LOG})" >&2
exit 1
