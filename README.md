# RunDash for Garmin

面向 Garmin Connect IQ 的**全屏跑步 Data Field**（454×454 AMOLED，`minSdkVersion` 5.2.2）。  
仓库：[laiaman/RunDashForGarmin](https://github.com/laiaman/RunDashForGarmin)

`Dash` 取 dashboard（仪表盘）语感，不是行业标准缩写。

## 功能概要

- 当前时间、心率与区间条、步频  
- 累计时间 / 距离  
- `L` 圈配速、`C` 当前配速、`A` 平均配速  
- 单圈时间/距离、电量  
- 心率区间优先读手表 User Profile；不可用时用设置中的最大心率兜底  

安装后请将活动数据页**字段数设为 1**。

## 构建

需要：Connect IQ SDK、目标机型 Device Support、Java 17、本机开发者密钥（勿提交）。

```bash
# 密钥默认读 .secrets/developer_key.der（已 gitignore）
python3 scripts/test_metrics.py
./scripts/build.sh
./scripts/run-sim.sh
```

隐私政策（可作商店 URL）：[`docs/PRIVACY_POLICY_zh.md`](docs/PRIVACY_POLICY_zh.md) · [English](docs/PRIVACY_POLICY_en.md)

建议商店隐私链接（推送后可用）：

`https://github.com/laiaman/RunDashForGarmin/blob/main/docs/PRIVACY_POLICY_zh.md`

## 许可

源码以本仓库为准；请勿将其它应用的商标、图标或反编译产物并入本项目。
