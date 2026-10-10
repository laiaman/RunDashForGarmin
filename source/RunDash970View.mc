using Toybox.Activity;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Math;
import Toybox.Lang;
using Toybox.System;
using Toybox.UserProfile;
using Toybox.WatchUi;

class RunDash970View extends WatchUi.DataField {

    // ═══════════════════════════════════════════════════════════
    //  调试开关
    // ═══════════════════════════════════════════════════════════
    hidden var DEBUG_LAYOUT = false;
    hidden var DEBUG_COLOR = 0xFF00FF;
    hidden var DEBUG_GRID_COLOR = 0x404040;

    // ═══════════════════════════════════════════════════════════
    //  全局样式
    // ═══════════════════════════════════════════════════════════
    hidden var LAYOUT_CENTER_X = 227;            // 454px 屏幕水平中心
    hidden var LAYOUT_SAFE_CENTER_Y = 227;       // 调试安全圆圆心 Y
    hidden var LAYOUT_SAFE_RADIUS = 195;         // 调试安全圆半径
    hidden var LAYOUT_TEXT_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden var LAYOUT_JUSTIFY_LEFT = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden var LAYOUT_JUSTIFY_RIGHT = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden var LAYOUT_TEXT_COLOR = Graphics.COLOR_WHITE;
    hidden var LAYOUT_MUTED_COLOR = 0x8A8A8A;   // 弱色：无心率胶囊文字（电量正常/未知色已改用 LAYOUT_BATTERY_COLOR_*）
    hidden var LAYOUT_ACCENT_COLOR = 0x00D060;   // 预留强调色
    hidden var LAYOUT_LINE_COLOR = 0x3A3A3A;     // 分隔线中性灰（v4 设计；2026-10-07 用户确认由 #2A2A2A 提亮到 #3A3A3A）
    hidden var LAYOUT_LINE_WIDTH = 2;            // 所有分隔线共用线宽（像素）
    hidden var LAYOUT_LABEL_COLOR = 0xE0E0E0;    // 标签近白（v5 方案 A，2026-10-08）：HR / CAD / TIME / DIST / LAP / NOW / AVG / 底部 LAP
    hidden var LAYOUT_CLOCK_COLOR = 0xD0D0D0;    // 顶部时钟（v5 方案 A 提亮）
    hidden var LAYOUT_KM_DIM_COLOR = 0xB0B0B0;   // km 单位：DIST 下方的 km 与单圈距离后的 km 共用（v5 方案 A 提亮）

    // ─── 字体分组（字号仍用这些常量；字重见 ensureFonts）───
    // 标签组回退字体：矢量字体不可用时使用（保持系统字体，不加粗）
    hidden var LAYOUT_FONT_LABEL = Graphics.FONT_XTINY;
    // 标签组矢量字号（像素，Condensed Bold）：HR / CAD 24；TIME / DIST / 右栏 LAP·NOW·AVG 22；底部 LAP、km 20
    hidden var LAYOUT_LABEL_SIZE_TOP = 24;
    hidden var LAYOUT_LABEL_SIZE_SIDE = 22;
    hidden var LAYOUT_LABEL_SIZE_SMALL = 20;
    // 累计时间 + 总距离数值组（字号来源；绘制用 Condensed Bold）
    hidden var LAYOUT_FONT_ELAPSED_DISTANCE = Graphics.FONT_NUMBER_MILD;
    // 时钟 / 区间 / 电量（字号来源；绘制用 Condensed Regular）
    hidden var LAYOUT_FONT_CLOCK = Graphics.FONT_XTINY;
    hidden var LAYOUT_FONT_ZONE = Graphics.FONT_XTINY;
    hidden var LAYOUT_FONT_BATTERY = Graphics.FONT_XTINY;
    // 其他数据数值组（字号来源；绘制用 Condensed Bold）
    hidden var LAYOUT_FONT_VALUE = Graphics.FONT_MEDIUM;
    // 右栏配速放不下时缩一号使用的数值字体
    hidden var LAYOUT_FONT_VALUE_SMALL = Graphics.FONT_SMALL;

    // ═══════════════════════════════════════════════════════════
    //  分隔线（共用 LAYOUT_LINE_COLOR / LAYOUT_LINE_WIDTH；每条线端点全部独立）
    // ═══════════════════════════════════════════════════════════
    // 横线 2（右上）
    hidden var LAYOUT_HLINE_2_LEFT = 285;
    hidden var LAYOUT_HLINE_2_RIGHT = 440;
    hidden var LAYOUT_HLINE_2_Y = 190;
    // 横线 3（左）
    hidden var LAYOUT_HLINE_3_LEFT = 30;
    hidden var LAYOUT_HLINE_3_RIGHT = 285;
    hidden var LAYOUT_HLINE_3_Y = 232;
    // 横线 4（右下）
    hidden var LAYOUT_HLINE_4_LEFT = 285;
    hidden var LAYOUT_HLINE_4_RIGHT = 440;
    hidden var LAYOUT_HLINE_4_Y = 270;
    // 横线 5（底部）
    hidden var LAYOUT_HLINE_5_LEFT = 36;
    hidden var LAYOUT_HLINE_5_RIGHT = 418;
    hidden var LAYOUT_HLINE_5_Y = 349;
    // 竖线 1
    hidden var LAYOUT_VLINE_1_X = 285;
    hidden var LAYOUT_VLINE_1_TOP = 132;
    hidden var LAYOUT_VLINE_1_BOTTOM = 349;
    // 底部短竖线（LAP 标签与单圈数值之间）
    hidden var LAYOUT_LAP_VLINE_X = 227;
    hidden var LAYOUT_LAP_VLINE_TOP = 374;
    hidden var LAYOUT_LAP_VLINE_BOTTOM = 402;

    // ═══════════════════════════════════════════════════════════
    //  按字段分区布局（从屏幕顶部到底部；y 均为垂直中心，除非另有说明）
    // ═══════════════════════════════════════════════════════════

    // ─── 时钟 (Clock) ───
    hidden var LAYOUT_TIME_Y = 26;

    // ─── HR（心率）───
    hidden var LAYOUT_HR_CAD_LABEL_Y = 83;       // HR / CAD 标签共用 Y（v5 方案 A：24 号字，与数字下沿对齐）
    hidden var LAYOUT_HR_LABEL_X = 90;           // "HR" 标签中心 X
    hidden var LAYOUT_HR_VALUE_X = 188;          // 心率数值右边缘 X（右对齐）
    hidden var LAYOUT_HR_VALUE_Y = 72;           // 心率数值 Y（独立）

    // ─── Zone（心率区间胶囊 + 彩条）───
    hidden var LAYOUT_ZONE_PILL_X = 227;         // 胶囊中心 X
    hidden var LAYOUT_ZONE_PILL_Y = 72;          // 胶囊中心 Y
    hidden var LAYOUT_ZONE_PILL_W = 56;
    hidden var LAYOUT_ZONE_PILL_H = 30;
    hidden var LAYOUT_ZONE_PILL_RADIUS = 15;
    // 胶囊文字垂直居中：按字形顶端定位，y = cy + digitH/2 - ascent + DY。
    // digitH = round(ascent * DIGIT_RATIO)（Roboto 数字高 0.711 em / ascent 0.927 em）。
    // 模拟器里看偏上就把 DY 调大，偏下就调小（单位：像素）。
    hidden var LAYOUT_ZONE_DIGIT_RATIO = 0.767;
    hidden var LAYOUT_ZONE_TEXT_DY = 0;
    hidden var LAYOUT_ZONE_BAR_X = 42;           // 区间条左端
    hidden var LAYOUT_ZONE_BAR_Y = 105;          // 区间条顶端
    hidden var LAYOUT_ZONE_BAR_SEG_W = 71;       // 每段宽度
    hidden var LAYOUT_ZONE_BAR_GAP = 4;          // 段间隙
    hidden var LAYOUT_ZONE_BAR_HEIGHT = 10;
    hidden var LAYOUT_ZONE_BAR_RADIUS = 2;       // 段圆角
    hidden var LAYOUT_ZONE_MARKER_TOP = 118;     // 三角标记顶点 Y
    hidden var LAYOUT_ZONE_MARKER_BOTTOM = 127;  // 三角标记底边 Y
    hidden var LAYOUT_ZONE_MARKER_HALF_W = 6;    // 三角标记底边半宽
    hidden var LAYOUT_ZONE_COLOR_1 = 0x39FF14;   // Z1 绿
    hidden var LAYOUT_ZONE_COLOR_2 = 0x00C8FF;   // Z2 蓝
    hidden var LAYOUT_ZONE_COLOR_3 = 0xFFB000;   // Z3 黄
    hidden var LAYOUT_ZONE_COLOR_4 = 0xFF6A00;   // Z4 橙
    hidden var LAYOUT_ZONE_COLOR_5 = 0xFF1010;   // Z5 红
    hidden var LAYOUT_ZONE_DIM_1 = 0x145907;     // Z1 暗色（已经过的段）
    hidden var LAYOUT_ZONE_DIM_2 = 0x004659;     // Z2 暗色
    hidden var LAYOUT_ZONE_DIM_3 = 0x593E00;     // Z3 暗色
    hidden var LAYOUT_ZONE_DIM_4 = 0x592500;     // Z4 暗色
    hidden var LAYOUT_ZONE_DIM_5 = 0x590606;     // Z5 暗色
    hidden var LAYOUT_ZONE_COLOR_IDLE = 0x333333; // 未到达区间 / 无心率胶囊

    // ─── Cad（步频）───
    hidden var LAYOUT_CAD_LABEL_X = 349;         // "CAD" 标签左边缘 X（左对齐，避免 24 号字贴到数值右缘约 344）
    hidden var LAYOUT_CAD_VALUE_X = 266;         // 步频数值左边缘 X（左对齐）
    hidden var LAYOUT_CAD_VALUE_Y = 72;          // 步频数值 Y（独立）

    // ─── TIME（累计时间）───
    hidden var LAYOUT_TIME_LABEL_X = 44;         // "TIME" 标签左边缘 X
    hidden var LAYOUT_TIME_LABEL_Y = 146;
    hidden var LAYOUT_ELAPSED_VALUE_Y = 186;     // 时间数值 Y（独立）
    hidden var LAYOUT_ELAPSED_VALUE_RIGHT = 276; // 与总距离共用的右边缘（右对齐）
    // 模拟数据总开关。看完布局改 false，再装手表。
    hidden var LAYOUT_PREVIEW_DATA = false;

    // ─── DIST（总距离）───
    hidden var LAYOUT_DIST_LABEL_X = 44;         // "DIST" 与其下方 km 共用左边缘 X
    hidden var LAYOUT_DIST_LABEL_Y = 252;
    hidden var LAYOUT_DIST_KM_Y = 274;           // DIST 下方 km（v5 方案 A）
    hidden var LAYOUT_DISTANCE_VALUE_Y = 296;    // 距离数值 Y（独立；右边缘同累计时间）

    // ─── 右栏配速（LAP / NOW / AVG）：数值右对齐，标签在数值右侧 ───
    hidden var LAYOUT_PACE_VALUE_RIGHT = 388;    // 数值右边缘 X
    hidden var LAYOUT_PACE_LABEL_X = 394;        // 标签左边缘 X
    hidden var LAYOUT_PACE_LABEL_DY = 12;        // 标签 Y = 数值 Y - DY（v5 方案 A：22 号字，大写顶端与配速数字顶端平齐）
    hidden var LAYOUT_PACE_FIT_LEFT = 290;       // 数值左端不得小于此值，否则缩一号字
    hidden var LAYOUT_LAP_PACE_VALUE_Y = 162;
    hidden var LAYOUT_CURRENT_PACE_VALUE_Y = 232;
    hidden var LAYOUT_AVERAGE_PACE_VALUE_Y = 311;

    // ─── 底部单圈行：LAP 标签 / 短竖线 / 单圈时间 + 单圈距离 km ───
    hidden var LAYOUT_LAP_LABEL_X = 227;         // "LAP" 标签中心 X
    hidden var LAYOUT_LAP_LABEL_Y = 362;         // v5 方案 A
    hidden var LAYOUT_LAP_INFO_Y = 390;          // 单圈时间/距离数值共用 Y（小号数字字体，墨迹约 373–406）
    hidden var LAYOUT_LAP_INFO_TIME_RIGHT = 215; // 单圈时间右边缘 X（短竖线 227 左侧 12px）
    hidden var LAYOUT_LAP_INFO_DIST_LEFT = 239;  // 单圈距离左边缘 X（短竖线 227 右侧 12px，避开 LAP 标签）
    hidden var LAYOUT_LAP_INFO_KM_GAP = 4;       // 单圈距离数值与 km 的间距
    hidden var LAYOUT_LAP_INFO_KM_Y = 400;       // km 与数字下沿对齐（v5 方案 A）

    // ─── Battery（电池图标 + 百分比文字，整组水平居中）───
    hidden var LAYOUT_BATTERY_X = 227;            // 整组水平中心 X
    hidden var LAYOUT_BATTERY_Y = 430;            // 整组垂直中心 Y
    hidden var LAYOUT_BATTERY_TEXT_SIZE = 22;     // 百分比矢量字号（px），数字高度与 14px 机身接近
    hidden var LAYOUT_BATTERY_BODY_W = 28;        // 机身宽
    hidden var LAYOUT_BATTERY_BODY_H = 14;        // 机身高
    hidden var LAYOUT_BATTERY_BODY_RADIUS = 3;    // 机身圆角
    hidden var LAYOUT_BATTERY_BODY_LINE = 2;      // 机身描边宽
    hidden var LAYOUT_BATTERY_NUB_W = 3;          // 正极宽
    hidden var LAYOUT_BATTERY_NUB_H = 6;          // 正极高
    hidden var LAYOUT_BATTERY_GAP = 6;            // 图标与文字间隙
    hidden var LAYOUT_BATTERY_FILL_INSET = 3;     // 填充距机身左/上边缘
    hidden var LAYOUT_BATTERY_FILL_MAX_W = 22;    // 100% 时填充宽
    hidden var LAYOUT_BATTERY_FILL_H = 8;         // 填充高
    hidden var LAYOUT_BATTERY_REFRESH_MS = 60000; // 刷新间隔 ms
    // 电量变色：>= HIGH 浅灰，>= MID 黄，否则红；未知同浅灰。图标与文字同色。
    hidden var LAYOUT_BATTERY_HIGH_PCT = 50;
    hidden var LAYOUT_BATTERY_MID_PCT = 20;
    hidden var LAYOUT_BATTERY_COLOR_HIGH = 0xB0B0B0;
    hidden var LAYOUT_BATTERY_COLOR_MID = 0xFFB000;
    hidden var LAYOUT_BATTERY_COLOR_LOW = 0xFF1010;
    hidden var LAYOUT_BATTERY_COLOR_UNKNOWN = 0xB0B0B0;

    // ═══════════════════════════════════════════════════════════
    //  运行时数据字段
    // ═══════════════════════════════════════════════════════════
    hidden var mHr = null;
    hidden var mAvgHr = null;
    hidden var mCadence = null;
    hidden var mAvgCadence = null;
    hidden var mCurrentSpeed = null;
    hidden var mAverageSpeed = null;
    hidden var mDistanceM = null;          // 累计距离（米）
    hidden var mTimerMs = null;            // 计时器（毫秒）
    hidden var mElapsedMs = null;          // 经过时间（毫秒）
    hidden var mLapStartDistanceM = null;  // 单圈起始距离
    hidden var mLapStartTimerMs = null;    // 单圈起始时间
    hidden var mMaxHr = 180;               // 无用户区间时的兜底最大心率
    hidden var mHrZones = null;            // 手表用户区间 [Z1min..Z5max]，bpm
    hidden var mPaused = false;
    hidden var mBatteryText = "--";
    hidden var mBatteryPct = null;         // 0–100，未知为 null（供变色）
    hidden var mBatteryLastRefreshMs = null;
    // 同字号矢量字体。null 表示尚未创建；创建失败则回退系统字体。
    hidden var mFontClock = null;
    hidden var mFontZone = null;
    hidden var mFontBattery = null;
    hidden var mFontElapsed = null;
    hidden var mFontValue = null;
    hidden var mFontValueSmall = null;
    hidden var mFontLabelTop = null;
    hidden var mFontLabelSide = null;
    hidden var mFontLabelSmall = null;

    // ═══════════════════════════════════════════════════════════
    //  初始化与设置
    // ═══════════════════════════════════════════════════════════

    function initialize() {
        DataField.initialize();
        loadSettings();
        resetLapBaselineFromActivity();
        refreshBattery();
    }

    // 读取 Data Field 兜底最大心率，并刷新手表用户心率区间。
    function loadSettings() {
        var maxHr = Properties.getValue("maxHeartRate");
        if (maxHr != null) {
            var h = maxHr.toNumber();
            if (h != null && h >= 120 && h <= 230) {
                mMaxHr = h;
            }
        }
        refreshHrZones();
    }

    // 读 Garmin 用户/运动配置的心率区间（bpm）。失败则保持 null，走 %HRmax 兜底。
    function refreshHrZones() {
        if (!(UserProfile has :getHeartRateZones)) {
            mHrZones = null;
            return;
        }
        var sport = UserProfile.HR_ZONE_SPORT_RUNNING;
        if (UserProfile has :getCurrentSport) {
            sport = UserProfile.getCurrentSport();
        }
        var zones = UserProfile.getHeartRateZones(sport);
        if (zones == null || zones.size() < 6) {
            zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        }
        if (zones != null && zones.size() >= 6
            && zones[0] != null && zones[5] != null) {
            mHrZones = zones;
        } else {
            mHrZones = null;
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  数据计算（Garmin 每帧回调）
    // ═══════════════════════════════════════════════════════════

    function compute(info) {
        loadSettings();
        mHr = info.currentHeartRate;
        mAvgHr = info.averageHeartRate;
        mCadence = info.currentCadence;
        mAvgCadence = info.averageCadence;
        mCurrentSpeed = info.currentSpeed;
        mAverageSpeed = info.averageSpeed;
        mDistanceM = info.elapsedDistance;
        mTimerMs = info.timerTime;
        mElapsedMs = info.elapsedTime;

        // 首次有效数据时建立单圈基线
        if (mLapStartDistanceM == null && mDistanceM != null) {
            mLapStartDistanceM = mDistanceM;
        }
        if (mLapStartTimerMs == null && mTimerMs != null) {
            mLapStartTimerMs = mTimerMs;
        }
        return null;
    }

    // ═══════════════════════════════════════════════════════════
    //  绘制入口
    // ═══════════════════════════════════════════════════════════

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc.getWidth() >= 440 && dc.getHeight() >= 440) {
            drawFullScreen970(dc);
        } else {
            drawCompactFallback(dc);
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  FR970 完整布局绘制
    // ═══════════════════════════════════════════════════════════

    function drawFullScreen970(dc) {
        refreshBattery();

        // 数据准备：优先手表用户区间，否则 %HRmax 兜底
        var zoneValue = Metrics.hrZoneValue(mHr, mHrZones);
        if (zoneValue == null) {
            zoneValue = Metrics.hrZoneValueFromMax(mHr, mMaxHr);
        }
        var zone = Metrics.hrZoneIndex(zoneValue);
        var currentPace = Metrics.paceSecondsFromSpeed(mCurrentSpeed);
        var paceText = Metrics.formatPace(currentPace);
        var distanceText = Metrics.formatDistanceMeters(mDistanceM);
        var timerText = Metrics.formatDurationMs(mTimerMs);

        // 单圈时间
        var lapTimeMs = null;
        if (mTimerMs != null && mLapStartTimerMs != null) {
            lapTimeMs = mTimerMs.toNumber() - mLapStartTimerMs.toNumber();
            if (lapTimeMs < 0) { lapTimeMs = 0; } // 防止设备时间回退
        }

        // 单圈距离
        var lapDistance = null;
        if (mDistanceM != null && mLapStartDistanceM != null) {
            lapDistance = mDistanceM.toFloat() - mLapStartDistanceM.toFloat();
            if (lapDistance < 0.0) { lapDistance = 0.0; }
        }

        var lapTimeText = Metrics.formatLapTimeMs(lapTimeMs);
        var lapDistanceText = Metrics.formatDistanceKm(lapDistance);
        var lapPaceText = Metrics.formatPace(Metrics.lapPaceSeconds(
            mTimerMs, mDistanceM, mLapStartTimerMs, mLapStartDistanceM));
        var averagePaceText = Metrics.formatPace(Metrics.paceSecondsFromSpeed(mAverageSpeed));

        var clock = System.getClockTime();
        var timeText = clock.hour.format("%02d") + ":" + clock.min.format("%02d");

        var hrValue = valueOrDash(mHr);
        var cadValue = valueOrDash(mCadence);
        var zoneText = zoneCapsuleText(zoneValue);

        // 模拟一组正常跑步中途数据，仅 LAYOUT_PREVIEW_DATA=true 时覆盖显示。
        if (LAYOUT_PREVIEW_DATA) {
            timeText = "06:32";
            hrValue = "142";
            cadValue = "176";
            zoneValue = 2.4;
            zone = 2;
            zoneText = "2.4";
            timerText = "1:23:45";
            distanceText = "18.60";
            lapTimeText = "5:12";
            lapDistanceText = "1.25";
            lapPaceText = "4:16";
            paceText = "4:22";
            averagePaceText = "4:30";
            mBatteryPct = 68;
            mBatteryText = "68%";
        }

        // 调试背景（最先绘制，被正文覆盖）
        if (DEBUG_LAYOUT) {
            drawDebugBackground(dc);
        }

        ensureFonts();

        // 图形层：分隔线 → 区间条 → 区间胶囊 → 电池图标
        drawSeparators(dc);
        drawHrZoneBar(dc, zoneValue);
        drawZonePill(dc, zone, zoneText);
        drawBattery(dc);

        // ── 时钟 (Clock) ──
        drawTextAt(dc, LAYOUT_CENTER_X, LAYOUT_TIME_Y, timeText, LAYOUT_CLOCK_COLOR, mFontClock);

        // ── HR（心率）── 标签居中，数值右对齐
        drawLabel(dc, LAYOUT_HR_LABEL_X, LAYOUT_HR_CAD_LABEL_Y, "HR", mFontLabelTop, LAYOUT_TEXT_JUSTIFY);
        drawTextAt2(dc, LAYOUT_HR_VALUE_X, LAYOUT_HR_VALUE_Y, hrValue, LAYOUT_TEXT_COLOR, mFontValue, LAYOUT_JUSTIFY_RIGHT);

        // ── CAD（步频）── 数值左对齐，标签左对齐
        drawTextAt2(dc, LAYOUT_CAD_VALUE_X, LAYOUT_CAD_VALUE_Y, cadValue, LAYOUT_TEXT_COLOR, mFontValue, LAYOUT_JUSTIFY_LEFT);
        drawLabel(dc, LAYOUT_CAD_LABEL_X, LAYOUT_HR_CAD_LABEL_Y, "CAD", mFontLabelTop, LAYOUT_JUSTIFY_LEFT);

        // ── TIME（累计时间）── 标签左对齐，数值右对齐
        drawLabel(dc, LAYOUT_TIME_LABEL_X, LAYOUT_TIME_LABEL_Y, "TIME", mFontLabelSide, LAYOUT_JUSTIFY_LEFT);
        drawTextAt2(dc, LAYOUT_ELAPSED_VALUE_RIGHT, LAYOUT_ELAPSED_VALUE_Y, timerText, LAYOUT_TEXT_COLOR, mFontElapsed, LAYOUT_JUSTIFY_RIGHT);

        // ── DIST（总距离）── 标签 + 下方 km 单位；数值与累计时间共用右边缘
        drawLabel(dc, LAYOUT_DIST_LABEL_X, LAYOUT_DIST_LABEL_Y, "DIST", mFontLabelSide, LAYOUT_JUSTIFY_LEFT);
        drawTextAt2(dc, LAYOUT_DIST_LABEL_X, LAYOUT_DIST_KM_Y, "km", LAYOUT_KM_DIM_COLOR, mFontLabelSmall, LAYOUT_JUSTIFY_LEFT);
        drawTextAt2(dc, LAYOUT_ELAPSED_VALUE_RIGHT, LAYOUT_DISTANCE_VALUE_Y, distanceText, LAYOUT_TEXT_COLOR, mFontElapsed, LAYOUT_JUSTIFY_RIGHT);

        // ── 右栏配速：LAP / NOW / AVG ──
        drawPaceRow(dc, LAYOUT_LAP_PACE_VALUE_Y, "LAP", lapPaceText);
        drawPaceRow(dc, LAYOUT_CURRENT_PACE_VALUE_Y, "NOW", paceText);
        drawPaceRow(dc, LAYOUT_AVERAGE_PACE_VALUE_Y, "AVG", averagePaceText);

        // ── 底部单圈行：LAP 标签 / 短竖线 / 单圈时间 + 单圈距离 km ──
        drawLabel(dc, LAYOUT_LAP_LABEL_X, LAYOUT_LAP_LABEL_Y, "LAP", mFontLabelSmall, LAYOUT_TEXT_JUSTIFY);
        // 以短竖线为轴：时间右对齐、距离左对齐，km 紧跟距离数值
        drawTextAt2(dc, LAYOUT_LAP_INFO_TIME_RIGHT, LAYOUT_LAP_INFO_Y, lapTimeText, LAYOUT_TEXT_COLOR, mFontValueSmall, LAYOUT_JUSTIFY_RIGHT);
        drawTextAt2(dc, LAYOUT_LAP_INFO_DIST_LEFT, LAYOUT_LAP_INFO_Y, lapDistanceText, LAYOUT_TEXT_COLOR, mFontValueSmall, LAYOUT_JUSTIFY_LEFT);
        var lapKmX = LAYOUT_LAP_INFO_DIST_LEFT + dc.getTextWidthInPixels(lapDistanceText, mFontValueSmall) + LAYOUT_LAP_INFO_KM_GAP;
        drawTextAt2(dc, lapKmX, LAYOUT_LAP_INFO_KM_Y, "km", LAYOUT_KM_DIM_COLOR, mFontLabelSmall, LAYOUT_JUSTIFY_LEFT);

        // 电池图标与文字已在图形层 drawBattery 中绘制
    }

    // ═══════════════════════════════════════════════════════════
    //  绘制辅助函数
    // ═══════════════════════════════════════════════════════════

    // 按现有系统字体的像素高度创建同高矢量字体。只换字重，不改字号常量。
    function ensureFonts() {
        if (mFontElapsed != null) {
            return;
        }
        mFontClock = vectorFont(["RobotoCondensedRegular", "RobotoRegular"], LAYOUT_FONT_CLOCK);
        mFontZone = vectorFont(["RobotoCondensedRegular", "RobotoRegular"], LAYOUT_FONT_ZONE);
        mFontBattery = vectorFontPx(["RobotoCondensedRegular", "RobotoRegular"], LAYOUT_BATTERY_TEXT_SIZE, LAYOUT_FONT_BATTERY);
        mFontValue = vectorFont(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_FONT_VALUE);
        mFontValueSmall = vectorFont(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_FONT_VALUE_SMALL);
        // 标签字体：按像素字号创建，不可用时回退 FONT_XTINY
        mFontLabelTop = vectorFontPx(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_LABEL_SIZE_TOP, LAYOUT_FONT_LABEL);
        mFontLabelSide = vectorFontPx(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_LABEL_SIZE_SIDE, LAYOUT_FONT_LABEL);
        mFontLabelSmall = vectorFontPx(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_LABEL_SIZE_SMALL, LAYOUT_FONT_LABEL);
        // 最后创建 mFontElapsed：它同时作为“字体已创建”标记
        mFontElapsed = vectorFont(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_FONT_ELAPSED_DISTANCE);
    }

    function vectorFont(faces, systemFont) {
        return vectorFontPx(faces, Graphics.getFontHeight(systemFont), systemFont);
    }

    // 指定像素字号的矢量字体；创建失败则回退 fallback 系统字体。
    function vectorFontPx(faces, px, fallback) {
        var sized = Graphics.getVectorFont({
            :face => faces,
            :size => px
        });
        if (sized != null) {
            return sized;
        }
        return fallback;
    }

    // 居中 + 垂直居中绘制，调试模式自动显示边界框。
    function drawTextAt(dc, x, y, text, color, font) {
        drawTextAt2(dc, x, y, text, color, font, LAYOUT_TEXT_JUSTIFY);
    }

    // 指定对齐方式绘制（LAYOUT_JUSTIFY_LEFT / RIGHT / LAYOUT_TEXT_JUSTIFY）。
    // 背景必须透明：黑色背景会按字体单元高度擦掉相邻文字（曾导致 LAP 标签和电量被单圈数值遮挡）。
    function drawTextAt2(dc, x, y, text, color, font, justify) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, justify);
        if (DEBUG_LAYOUT) {
            drawDebugBox(dc, x, y, text, font, justify);
        }
    }

    // 标签：统一标签近白色。
    function drawLabel(dc, x, y, text, font, justify) {
        drawTextAt2(dc, x, y, text, LAYOUT_LABEL_COLOR, font, justify);
    }

    // 右栏配速一行：数值右对齐 x 388，标签左对齐 x 394（y = 数值 y - 12，标签用 Side 22 号字）。
    // 数值左端越过 LAYOUT_PACE_FIT_LEFT（竖线 1 右侧）时缩一号字。
    function drawPaceRow(dc, valueY, label, text) {
        var font = mFontValue;
        var w = dc.getTextWidthInPixels(text, font);
        if (LAYOUT_PACE_VALUE_RIGHT - w < LAYOUT_PACE_FIT_LEFT) {
            font = mFontValueSmall;
        }
        drawTextAt2(dc, LAYOUT_PACE_VALUE_RIGHT, valueY, text, LAYOUT_TEXT_COLOR, font, LAYOUT_JUSTIFY_RIGHT);
        drawLabel(dc, LAYOUT_PACE_LABEL_X, valueY - LAYOUT_PACE_LABEL_DY, label, mFontLabelSide, LAYOUT_JUSTIFY_LEFT);
    }

    // 调试边界框 + 锚点十字。按水平对齐方式推算框的左边缘。
    function drawDebugBox(dc, anchorX, anchorY, text, font, justify) {
        var dim = dc.getTextDimensions(text, font) as Array<Number>;
        var left = anchorX - (dim[0] / 2);
        var h = justify & 3;
        if (h == Graphics.TEXT_JUSTIFY_RIGHT) {
            left = anchorX - dim[0];
        } else if (h == Graphics.TEXT_JUSTIFY_LEFT) {
            left = anchorX;
        }
        dc.setColor(DEBUG_COLOR, Graphics.COLOR_BLACK);
        dc.drawRectangle(left, anchorY - (dim[1] / 2), dim[0], dim[1]);
        dc.drawLine(anchorX - 3, anchorY, anchorX + 3, anchorY);
        dc.drawLine(anchorX, anchorY - 3, anchorX, anchorY + 3);
    }

    // 四条横线 + 竖线 1 + 底部短竖线；颜色/线宽统一，端点各自独立。
    function drawSeparators(dc) {
        dc.setColor(LAYOUT_LINE_COLOR, Graphics.COLOR_BLACK);
        dc.setPenWidth(LAYOUT_LINE_WIDTH);
        dc.drawLine(LAYOUT_HLINE_2_LEFT, LAYOUT_HLINE_2_Y, LAYOUT_HLINE_2_RIGHT, LAYOUT_HLINE_2_Y);
        dc.drawLine(LAYOUT_HLINE_3_LEFT, LAYOUT_HLINE_3_Y, LAYOUT_HLINE_3_RIGHT, LAYOUT_HLINE_3_Y);
        dc.drawLine(LAYOUT_HLINE_4_LEFT, LAYOUT_HLINE_4_Y, LAYOUT_HLINE_4_RIGHT, LAYOUT_HLINE_4_Y);
        dc.drawLine(LAYOUT_HLINE_5_LEFT, LAYOUT_HLINE_5_Y, LAYOUT_HLINE_5_RIGHT, LAYOUT_HLINE_5_Y);
        dc.drawLine(LAYOUT_VLINE_1_X, LAYOUT_VLINE_1_TOP, LAYOUT_VLINE_1_X, LAYOUT_VLINE_1_BOTTOM);
        dc.drawLine(LAYOUT_LAP_VLINE_X, LAYOUT_LAP_VLINE_TOP, LAYOUT_LAP_VLINE_X, LAYOUT_LAP_VLINE_BOTTOM);
        dc.setPenWidth(1);
    }

    // 五段心率区间条：当前段全亮，已过的段暗色，未到达的段 IDLE；
    // 白色三角标记按小数区间值定位（zoneValue 为空或 < 1.0 时不画三角）。
    function drawHrZoneBar(dc, zoneValue) {
        var zone = Metrics.hrZoneIndex(zoneValue);
        var pitch = LAYOUT_ZONE_BAR_SEG_W + LAYOUT_ZONE_BAR_GAP;

        for (var i = 0; i < 5; i += 1) {
            var zoneNum = i + 1;
            var color = LAYOUT_ZONE_COLOR_IDLE;
            if (zone == zoneNum) {
                color = zoneColor(zoneNum);
            } else if (zone > zoneNum) {
                color = zoneDimColor(zoneNum);
            }
            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.fillRoundedRectangle(LAYOUT_ZONE_BAR_X + i * pitch, LAYOUT_ZONE_BAR_Y,
                LAYOUT_ZONE_BAR_SEG_W, LAYOUT_ZONE_BAR_HEIGHT, LAYOUT_ZONE_BAR_RADIUS);
        }

        if (zone > 0) {
            var frac = 1.0;
            if (zoneValue.toFloat() < 6.0) {
                frac = zoneValue.toFloat() - zone;
            }
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            var mx = LAYOUT_ZONE_BAR_X + (zone - 1) * pitch + (frac * LAYOUT_ZONE_BAR_SEG_W + 0.5).toNumber();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.fillPolygon([
                [mx, LAYOUT_ZONE_MARKER_TOP],
                [mx - LAYOUT_ZONE_MARKER_HALF_W, LAYOUT_ZONE_MARKER_BOTTOM],
                [mx + LAYOUT_ZONE_MARKER_HALF_W, LAYOUT_ZONE_MARKER_BOTTOM]
            ]);
        }
    }

    // 当前区间全亮色；无效区间用 IDLE。
    function zoneColor(zone) {
        if (zone == 1) { return LAYOUT_ZONE_COLOR_1; }
        if (zone == 2) { return LAYOUT_ZONE_COLOR_2; }
        if (zone == 3) { return LAYOUT_ZONE_COLOR_3; }
        if (zone == 4) { return LAYOUT_ZONE_COLOR_4; }
        if (zone == 5) { return LAYOUT_ZONE_COLOR_5; }
        return LAYOUT_ZONE_COLOR_IDLE;
    }

    // 已经过的区间暗色；无效区间用 IDLE。
    function zoneDimColor(zone) {
        if (zone == 1) { return LAYOUT_ZONE_DIM_1; }
        if (zone == 2) { return LAYOUT_ZONE_DIM_2; }
        if (zone == 3) { return LAYOUT_ZONE_DIM_3; }
        if (zone == 4) { return LAYOUT_ZONE_DIM_4; }
        if (zone == 5) { return LAYOUT_ZONE_DIM_5; }
        return LAYOUT_ZONE_COLOR_IDLE;
    }

    // 心率区间胶囊：有区间时填当前区间色 + 黑字；无心率填 IDLE + 灰字。
    // 文字背景透明（不能用 drawTextAt，它以黑色作背景会在胶囊上盖出黑框）。
    // 垂直居中：不用 TEXT_JUSTIFY_VCENTER（按字体单元高度居中，数字字形会偏离中线），
    // 改为按字形顶端定位：y = cy + digitH/2 - ascent + DY。
    function drawZonePill(dc, zone, text) {
        var cx = LAYOUT_ZONE_PILL_X;
        var cy = LAYOUT_ZONE_PILL_Y;
        var fill = LAYOUT_ZONE_COLOR_IDLE;
        var textColor = LAYOUT_MUTED_COLOR;
        if (zone > 0) {
            fill = zoneColor(zone);
            textColor = Graphics.COLOR_BLACK;
        }
        dc.setColor(fill, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(cx - (LAYOUT_ZONE_PILL_W / 2), cy - (LAYOUT_ZONE_PILL_H / 2),
            LAYOUT_ZONE_PILL_W, LAYOUT_ZONE_PILL_H, LAYOUT_ZONE_PILL_RADIUS);

        var ascent = Graphics.getFontAscent(mFontZone);
        var digitH = (ascent * LAYOUT_ZONE_DIGIT_RATIO + 0.5).toNumber();
        var ty = (cy + (digitH / 2.0) - ascent + LAYOUT_ZONE_TEXT_DY + 0.5).toNumber();
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty, mFontZone, text, Graphics.TEXT_JUSTIFY_CENTER);
        if (DEBUG_LAYOUT) {
            // 调试：胶囊中线
            dc.setColor(DEBUG_COLOR, Graphics.COLOR_BLACK);
            dc.drawLine(cx - (LAYOUT_ZONE_PILL_W / 2), cy, cx + (LAYOUT_ZONE_PILL_W / 2), cy);
        }
    }

    // 电池：图标（机身 + 正极 + 电量填充）+ 6px 间隙 + 百分比文字，整组按文字实测宽度水平居中。
    // 图标和文字同色（batteryColor）。机身用“外层实心 + 内层黑色”画出 2px 边框，避免依赖笔宽对齐。
    function drawBattery(dc) {
        var color = batteryColor();
        var textW = dc.getTextWidthInPixels(mBatteryText, mFontBattery);
        var bw = LAYOUT_BATTERY_BODY_W;
        var bh = LAYOUT_BATTERY_BODY_H;
        var total = bw + LAYOUT_BATTERY_NUB_W + LAYOUT_BATTERY_GAP + textW;
        var x0 = LAYOUT_BATTERY_X - (total / 2);
        var y0 = LAYOUT_BATTERY_Y - (bh / 2);
        var line = LAYOUT_BATTERY_BODY_LINE;

        // 机身边框
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(x0, y0, bw, bh, LAYOUT_BATTERY_BODY_RADIUS);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(x0 + line, y0 + line, bw - (2 * line), bh - (2 * line),
            LAYOUT_BATTERY_BODY_RADIUS - line);
        // 正极
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.fillRectangle(x0 + bw, LAYOUT_BATTERY_Y - (LAYOUT_BATTERY_NUB_H / 2),
            LAYOUT_BATTERY_NUB_W, LAYOUT_BATTERY_NUB_H);
        // 电量填充：未知或 0 不填
        if (mBatteryPct != null && mBatteryPct > 0) {
            var fillW = (LAYOUT_BATTERY_FILL_MAX_W * mBatteryPct / 100.0 + 0.5).toNumber();
            if (fillW < 1) { fillW = 1; }
            dc.fillRectangle(x0 + LAYOUT_BATTERY_FILL_INSET, y0 + LAYOUT_BATTERY_FILL_INSET,
                fillW, LAYOUT_BATTERY_FILL_H);
        }

        // 百分比文字（左对齐，紧跟图标）
        drawTextAt2(dc, x0 + bw + LAYOUT_BATTERY_NUB_W + LAYOUT_BATTERY_GAP, LAYOUT_BATTERY_Y,
            mBatteryText, color, mFontBattery, LAYOUT_JUSTIFY_LEFT);
    }

    // 按电量百分比选择图标/文字颜色。
    function batteryColor() {
        if (mBatteryPct == null) {
            return LAYOUT_BATTERY_COLOR_UNKNOWN;
        }
        if (mBatteryPct >= LAYOUT_BATTERY_HIGH_PCT) {
            return LAYOUT_BATTERY_COLOR_HIGH;
        }
        if (mBatteryPct >= LAYOUT_BATTERY_MID_PCT) {
            return LAYOUT_BATTERY_COLOR_MID;
        }
        return LAYOUT_BATTERY_COLOR_LOW;
    }

    // 调试网格、安全圆和中心十字。
    function drawDebugBackground(dc) {
        dc.setColor(DEBUG_GRID_COLOR, Graphics.COLOR_BLACK);
        for (var grid = 32; grid < 454; grid += 32) {
            dc.drawLine(grid, 0, grid, 453);
            dc.drawLine(0, grid, 453, grid);
        }
        dc.setColor(DEBUG_COLOR, Graphics.COLOR_BLACK);
        dc.drawCircle(LAYOUT_CENTER_X, LAYOUT_SAFE_CENTER_Y, LAYOUT_SAFE_RADIUS);
        dc.drawLine(LAYOUT_CENTER_X - 12, LAYOUT_SAFE_CENTER_Y, LAYOUT_CENTER_X + 12, LAYOUT_SAFE_CENTER_Y);
        dc.drawLine(LAYOUT_CENTER_X, LAYOUT_SAFE_CENTER_Y - 12, LAYOUT_CENTER_X, LAYOUT_SAFE_CENTER_Y + 12);
    }

    // 小屏幕备用布局。
    function drawCompactFallback(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var pace = Metrics.paceSecondsFromSpeed(mCurrentSpeed);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(cx, cy - 32, Graphics.FONT_NUMBER_HOT, Metrics.formatPace(pace),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0xAAAAAA, Graphics.COLOR_BLACK);
        dc.drawText(cx, cy + 38, Graphics.FONT_TINY, "RunDash · use 1-field layout",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ═══════════════════════════════════════════════════════════
    //  数据格式化
    // ═══════════════════════════════════════════════════════════

    // 电量缓存（60s 间隔刷新）。
    function refreshBattery() {
        var now = System.getTimer();
        if (mBatteryLastRefreshMs != null) {
            var age = now - mBatteryLastRefreshMs;
            if (age >= 0 && age < LAYOUT_BATTERY_REFRESH_MS) { return; }
        }
        mBatteryLastRefreshMs = now;
        mBatteryText = "--";
        mBatteryPct = null;
        var systemStats = System.getSystemStats();
        if (systemStats != null && systemStats.battery != null) {
            var battery = systemStats.battery.toFloat();
            if (battery >= 0.0 && battery <= 100.0) {
                mBatteryPct = battery.toNumber();
                mBatteryText = mBatteryPct.format("%d") + "%";
            }
        }
    }

    // 小数区间 → 胶囊文字：截断（不四舍五入）到 1 位小数，上限 6.0；无心率或 <= 0 显示 "-.-"。
    function zoneCapsuleText(zoneValue) {
        if (zoneValue == null) {
            return "-.-";
        }
        var v = zoneValue.toFloat();
        if (v <= 0.0) {
            return "-.-";
        }
        if (v > 6.0) {
            v = 6.0;
        }
        return ((v * 10).toNumber() / 10.0).format("%.1f");
    }

    // 数值 → 整数文字或 "--"。
    function valueOrDash(value) {
        if (value == null) { return "--"; }
        return value.toNumber().format("%d");
    }

    // ═══════════════════════════════════════════════════════════
    //  单圈与活动生命周期
    // ═══════════════════════════════════════════════════════════

    // 从当前活动快照建立单圈基线。
    function resetLapBaselineFromActivity() {
        var info = Activity.getActivityInfo();
        mLapStartDistanceM = info.elapsedDistance;
        mLapStartTimerMs = info.timerTime;
    }

    function clearActivityState() {
        mHr = null;
        mAvgHr = null;
        mCadence = null;
        mAvgCadence = null;
        mCurrentSpeed = null;
        mAverageSpeed = null;
        mDistanceM = null;
        mTimerMs = null;
        mElapsedMs = null;
        mLapStartDistanceM = null;
        mLapStartTimerMs = null;
        mPaused = false;
    }

    function onTimerStart() {
        mPaused = false;
    }

    function onTimerPause() {
        mPaused = true;
    }

    function onTimerResume() {
        mPaused = false;
    }

    function onTimerStop() {
        mPaused = true;
    }

    function onTimerReset() {
        clearActivityState();
    }

    // SDK 5.2.2+ 新版计圈回调（返回 true 阻止旧版重复触发）。
    function onTimerLap2(trigger) {
        resetLapBaselineFromActivity();
        return true;
    }

    // 兼容旧版 SDK 的计圈回调。
    function onTimerLap() {
        resetLapBaselineFromActivity();
    }
}
