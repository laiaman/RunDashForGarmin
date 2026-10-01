#!/usr/bin/env python3
"""列出本机已安装、分辨率为 454×454 的 Connect IQ 设备包。"""

from __future__ import annotations

import json
import os
import sys

ROOT = os.path.expanduser("~/Library/Application Support/Garmin/ConnectIQ/Devices")

# 本项目锁定 minSdk 5.2.2，这些 API 5.1 的 454 机型即使装了也不要写入 manifest
EXCLUDE_HINTS = (
    "approachs70",
    "descentmk3",
)


def main() -> int:
    if not os.path.isdir(ROOT):
        print(f"未找到设备目录: {ROOT}")
        print("请先打开 Connect IQ SDK Manager 安装目标机型。")
        return 1

    rows = []
    for name in sorted(os.listdir(ROOT)):
        path = os.path.join(ROOT, name, "compiler.json")
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        res = data.get("resolution") or {}
        if res.get("width") != 454 or res.get("height") != 454:
            continue
        api = data.get("apiVersion") or data.get("ciqApiVersion") or "?"
        display = data.get("displayName") or name
        family = data.get("deviceFamily") or ""
        excluded = any(h in name.lower() for h in EXCLUDE_HINTS)
        rows.append((name, display, api, family, excluded))

    if not rows:
        print("本机尚未安装任何 454×454 设备包（当前通常只有未装或仅 fr970）。")
        return 0

    print(f"{'product_id':24} {'api':8} {'exclude':8} display")
    print("-" * 80)
    for name, display, api, family, excluded in rows:
        flag = "YES" if excluded else "no"
        print(f"{name:24} {str(api):8} {flag:8} {display}  ({family})")

    usable = [r[0] for r in rows if not r[4]]
    print()
    print("可写入 manifest 的 <iq:product>（已排除 API 5.1 提示项）:")
    for pid in usable:
        print(f'    <iq:product id="{pid}" />')
    return 0


if __name__ == "__main__":
    sys.exit(main())
