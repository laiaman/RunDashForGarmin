#!/usr/bin/env bash
set -euo pipefail
KEY="${1:-$(cd "$(dirname "$0")/.." && pwd)/.secrets/developer_key.der}"
if [[ ! -f "$KEY" ]]; then
  KEY="$HOME/.connectiq/developer_key.der"
fi
if [[ ! -f "$KEY" ]]; then
  echo "找不到开发者密钥。请传入路径，或放到 .secrets/developer_key.der" >&2
  exit 1
fi
mkdir -p bin
monkeyc -d fr970 -f monkey.jungle -o bin/RunDash970-fr970.prg -y "$KEY" -w
