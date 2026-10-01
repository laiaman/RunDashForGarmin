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
    hidden var LAYOUT_TEXT_COLOR = Graphics.COLOR_WHITE;
    hidden var LAYOUT_MUTED_COLOR = 0x8A8A8A;   // 预留弱色
    hidden var LAYOUT_ACCENT_COLOR = 0x00D060;   // 预留强调色
    hidden var LAYOUT_LINE_COLOR = 0x006B3C;     // 分隔线深绿
    hidden var LAYOUT_LINE_WIDTH = 2;            // 所有分隔线共用线宽（像素）
    hidden var LAYOUT_LABEL_COLOR = 0xB0B0B0; // 标签略灰，数据仍用白色

    // ─── 字体分组（字号仍用这些常量；字重见 ensureFonts）───
    // 标签组：HR / Cad / T / D / L / C / A / lap（保持系统字体，不加粗）
    hidden var LAYOUT_FONT_LABEL = Graphics.FONT_XTINY;
    // 累计时间 + 总距离数值组（字号来源；绘制用 Condensed Bold）
    hidden var LAYOUT_FONT_ELAPSED_DISTANCE = Graphics.FONT_NUMBER_MILD;
    // 时钟 / 区间 / 电量（字号来源；绘制用 Condensed Regular）
    hidden var LAYOUT_FONT_CLOCK = Graphics.FONT_XTINY;
    hidden var LAYOUT_FONT_ZONE = Graphics.FONT_XTINY;
    hidden var LAYOUT_FONT_BATTERY = Graphics.FONT_XTINY;
    // 其他数据数值组（字号来源；绘制用 Condensed Bold）
    hidden var LAYOUT_FONT_VALUE = Graphics.FONT_MEDIUM;

    // ═══════════════════════════════════════════════════════════
    //  分隔线（共用 LAYOUT_LINE_COLOR / LAYOUT_LINE_WIDTH；每条线端点全部独立）
    // ═══════════════════════════════════════════════════════════
    // 横线 1
    hidden var LAYOUT_HLINE_1_LEFT = 66;
    hidden var LAYOUT_HLINE_1_RIGHT = 388;
    hidden var LAYOUT_HLINE_1_Y = 42;
    // 横线 2
    hidden var LAYOUT_HLINE_2_LEFT = 285;
    hidden var LAYOUT_HLINE_2_RIGHT = 454;
    hidden var LAYOUT_HLINE_2_Y = 190;
    // 横线 3
    hidden var LAYOUT_HLINE_3_LEFT = 0;
    hidden var LAYOUT_HLINE_3_RIGHT = 285;
    hidden var LAYOUT_HLINE_3_Y = 232;
    // 横线 4（新增）
    hidden var LAYOUT_HLINE_4_LEFT = 285;
    hidden var LAYOUT_HLINE_4_RIGHT = 454;
    hidden var LAYOUT_HLINE_4_Y = 270;
    // 横线 5（新增）
    hidden var LAYOUT_HLINE_5_LEFT = 0;
    hidden var LAYOUT_HLINE_5_RIGHT = 454;
    hidden var LAYOUT_HLINE_5_Y = 349;
    // 竖线 1
    hidden var LAYOUT_VLINE_1_X = 285;
    hidden var LAYOUT_VLINE_1_TOP = 120;
    hidden var LAYOUT_VLINE_1_BOTTOM = 349;
    // 竖线 2
    hidden var LAYOUT_VLINE_2_X = 227;
    hidden var LAYOUT_VLINE_2_TOP = 349;
    hidden var LAYOUT_VLINE_2_BOTTOM = 410;

    // ═══════════════════════════════════════════════════════════
    //  按字段分区布局（从屏幕顶部到底部）
    // ═══════════════════════════════════════════════════════════

    // ─── 时钟 (Clock) ───
    hidden var LAYOUT_TIME_Y = 21;              // 上移，避免盖住横线 1

    // ─── HR（心率）───
    hidden var LAYOUT_HR_CAD_LABEL_Y = 82;       // 仅 HR / Cad 标签共用 Y（不与数值、Zone 共用）
    hidden var LAYOUT_HR_LABEL_X = 84;          // "HR" 标签 X
    hidden var LAYOUT_HR_VALUE_X = 154;          // 心率数值 X
    hidden var LAYOUT_HR_VALUE_Y = 73;           // 心率数值 Y（独立）

    // ─── Zone（心率区间圆圈 + 彩条）───
    hidden var LAYOUT_ZONE_CIRCLE_X = 227;
    hidden var LAYOUT_ZONE_CIRCLE_Y = 75;
    hidden var LAYOUT_ZONE_CIRCLE_PAD = 2;       // 圆比文字框四角再多出的空隙（含描边）
    hidden var LAYOUT_ZONE_CIRCLE_COLOR = 0x006B3C; // 与分隔线同色，不随区间变
    hidden var LAYOUT_ZONE_BAR_X = 35;
    hidden var LAYOUT_ZONE_BAR_Y = 105;
    hidden var LAYOUT_ZONE_BAR_WIDTH = 390;
    hidden var LAYOUT_ZONE_BAR_HEIGHT = 12;
    hidden var LAYOUT_ZONE_COLOR_1 = 0x39FF14;   // Z1 绿
    hidden var LAYOUT_ZONE_COLOR_2 = 0x00C8FF;   // Z2 蓝
    hidden var LAYOUT_ZONE_COLOR_3 = 0xFFB000;   // Z3 黄
    hidden var LAYOUT_ZONE_COLOR_4 = 0xFF6A00;   // Z4 橙
    hidden var LAYOUT_ZONE_COLOR_5 = 0xFF1010;   // Z5 红
    hidden var LAYOUT_ZONE_COLOR_IDLE = 0x333333; // 未到达区间（暗色，随心率点亮）

    // ─── Cad（步频）───
    hidden var LAYOUT_CAD_LABEL_X = 370;         // "Cad" 标签 X
    hidden var LAYOUT_CAD_VALUE_X = 300;         // 步频数值 X
    hidden var LAYOUT_CAD_VALUE_Y = 73;          // 步频数值 Y（独立）

    // ─── T / D 标签共用 X，并与横线 3 等距（只改间隙，上下一起动）───
    hidden var LAYOUT_TD_LABEL_X = 20;
    hidden var LAYOUT_TD_LABEL_LINE_GAP = 26;    // 标签中心到横线 3 描边的距离

    // ─── T（累计时间）───
    hidden var LAYOUT_ELAPSED_VALUE_Y = 175;     // 时间数值 Y（独立）
    hidden var LAYOUT_ELAPSED_VALUE_RIGHT = 285; // 与总距离共用的右边缘；超过竖线 1 左侧 6px 时会被截断
    // 模拟数据总开关。看完布局改 false，再装手表。
    hidden var LAYOUT_PREVIEW_DATA = false;

    // ─── D（总距离）───
    // 总距离水平位置与累计时间共用右边缘，不再单独设中心 X
    hidden var LAYOUT_DISTANCE_VALUE_Y = 290;    // 距离数值 Y（独立）

    // ─── L（单圈配速）───
    hidden var LAYOUT_LAP_PACE_LABEL_X = 418;    // "L" 标签 X
    hidden var LAYOUT_LAP_PACE_LABEL_Y = 136;    // 区间条 Y（105）+ 30
    hidden var LAYOUT_LAP_PACE_VALUE_X = 345;    // 配速数值 X
    hidden var LAYOUT_LAP_PACE_VALUE_Y = 150;    // 配速数值 Y（独立）

    // ─── C（当前配速）───
    hidden var LAYOUT_CURRENT_PACE_LABEL_X = 418; // "C" 标签 X
    hidden var LAYOUT_CURRENT_PACE_LABEL_Y = 215; // 横线 2（185）+ 30，与 L、A 的间距一致
    hidden var LAYOUT_CURRENT_PACE_VALUE_X = 345;  // 配速数值 X
    hidden var LAYOUT_CURRENT_PACE_VALUE_Y = 230;  // 配速数值 Y（独立）

    // ─── A（平均配速）───
    hidden var LAYOUT_AVERAGE_PACE_LABEL_X = 418; // "A" 标签 X
    hidden var LAYOUT_AVERAGE_PACE_LABEL_Y = 295; // 横线 4（265）+ 30
    hidden var LAYOUT_AVERAGE_PACE_VALUE_X = 345;  // 配速数值 X
    hidden var LAYOUT_AVERAGE_PACE_VALUE_Y = 310;  // 配速数值 Y（独立）

    // ─── Lap Info（单圈信息合并行：T 时间 lap 距离 D）───
    hidden var LAYOUT_LAP_INFO_Y = 380;          // 单圈时间/距离数值共用 Y
    hidden var LAYOUT_LAP_INFO_T_X = 70;          // 左侧 "T" X
    hidden var LAYOUT_LAP_INFO_T_Y = 370;         // 左侧 "T" Y（独立）
    hidden var LAYOUT_LAP_INFO_TIME_X = 143;     // 时间数值 X
    hidden var LAYOUT_LAP_INFO_LAP_X = 227;      // "lap" 文字 X
    hidden var LAYOUT_LAP_INFO_LAP_Y = 370;      // "lap" 文字 Y（独立）
    hidden var LAYOUT_LAP_INFO_DIST_X = 311;     // 距离数值 X
    hidden var LAYOUT_LAP_INFO_D_X = 384;        // 右侧 "D" X
    hidden var LAYOUT_LAP_INFO_D_Y = 370;        // 右侧 "D" Y（独立）

    // ─── Battery（电量椭圆 + 文字，结构同 Zone）───
    hidden var LAYOUT_BATTERY_CIRCLE_X = 227;     // 椭圆心 / 文字中心 X
    hidden var LAYOUT_BATTERY_CIRCLE_Y = 425;     // 椭圆心 / 文字中心 Y
    hidden var LAYOUT_BATTERY_ELLIPSE_A_MIN = 22; // 水平半径下限
    hidden var LAYOUT_BATTERY_ELLIPSE_B_MIN = 10; // 垂直半径下限（上下更窄）
    hidden var LAYOUT_BATTERY_ELLIPSE_PAD_X = 6;  // 文字半宽之外的水平边距
    hidden var LAYOUT_BATTERY_ELLIPSE_PAD_Y = 2;  // 文字半高之外的垂直边距（贴合数字高度）
    hidden var LAYOUT_BATTERY_REFRESH_MS = 60000; // 刷新间隔 ms
    // 电量字体变色：>= HIGH 深绿，>= MID 黄，否则红；圆圈与分隔线同色
    hidden var LAYOUT_BATTERY_HIGH_PCT = 50;
    hidden var LAYOUT_BATTERY_MID_PCT = 20;
    hidden var LAYOUT_BATTERY_COLOR_HIGH = 0x004E28; // 比分隔线 0x006B3C 更深，避免同色
    hidden var LAYOUT_BATTERY_COLOR_MID = 0xFFB000;
    hidden var LAYOUT_BATTERY_COLOR_LOW = 0xFF1010;
    hidden var LAYOUT_BATTERY_COLOR_UNKNOWN = Graphics.COLOR_WHITE;

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
        var zoneText = zoneShortText(zoneValue);

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
            lapTimeText = "5.12";
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

        // 图形层：分隔线 → Zone bar → Zone 圆圈 → Battery 圆圈
        drawSeparators(dc);
        drawHrZoneBar(dc, LAYOUT_ZONE_BAR_X, LAYOUT_ZONE_BAR_Y,
            LAYOUT_ZONE_BAR_WIDTH, LAYOUT_ZONE_BAR_HEIGHT, zone);
        drawZoneCircle(dc, zoneText);
        drawBatteryEllipse(dc);

        // ── 时钟 (Clock) ── Condensed Regular，字号沿用 FONT_XTINY
        drawTextAt(dc, LAYOUT_CENTER_X, LAYOUT_TIME_Y, timeText, LAYOUT_TEXT_COLOR, mFontClock);

        // ── HR（心率）── 标签用 LABEL_Y，数值用 VALUE_Y
        drawLabel(dc, LAYOUT_HR_LABEL_X, LAYOUT_HR_CAD_LABEL_Y, "HR");
        drawValue(dc, LAYOUT_HR_VALUE_X, LAYOUT_HR_VALUE_Y, hrValue);

        // ── Zone（心率区间）── Condensed Regular，字号沿用 FONT_XTINY
        drawTextAt(dc, LAYOUT_ZONE_CIRCLE_X, LAYOUT_ZONE_CIRCLE_Y, zoneText, LAYOUT_TEXT_COLOR, mFontZone);

        // ── Cad（步频）── 标签与 HR 标签共用 LABEL_Y，数值独立
        drawLabel(dc, LAYOUT_CAD_LABEL_X, LAYOUT_HR_CAD_LABEL_Y, "Cad");
        drawValue(dc, LAYOUT_CAD_VALUE_X, LAYOUT_CAD_VALUE_Y, cadValue);

        // ── T（累计时间）── 先画数值，再画标签，避免长计时盖住 T
        drawElapsedValue(dc, timerText);
        drawLabel(dc, LAYOUT_TD_LABEL_X, tdLabelY(true), "T");

        // ── D（总距离）── 与 T 共用 LAYOUT_TD_LABEL_X
        drawTextAt(dc, centerForSharedRight(dc, distanceText, mFontElapsed), LAYOUT_DISTANCE_VALUE_Y, distanceText, LAYOUT_TEXT_COLOR, mFontElapsed);
        drawLabel(dc, LAYOUT_TD_LABEL_X, tdLabelY(false), "D");

        // ── L（单圈配速）──
        drawLabel(dc, LAYOUT_LAP_PACE_LABEL_X, LAYOUT_LAP_PACE_LABEL_Y, "L");
        drawValue(dc, LAYOUT_LAP_PACE_VALUE_X, LAYOUT_LAP_PACE_VALUE_Y, lapPaceText);

        // ── C（当前配速）──
        drawLabel(dc, LAYOUT_CURRENT_PACE_LABEL_X, LAYOUT_CURRENT_PACE_LABEL_Y, "C");
        drawValue(dc, LAYOUT_CURRENT_PACE_VALUE_X, LAYOUT_CURRENT_PACE_VALUE_Y, paceText);

        // ── A（平均配速）──
        drawLabel(dc, LAYOUT_AVERAGE_PACE_LABEL_X, LAYOUT_AVERAGE_PACE_LABEL_Y, "A");
        drawValue(dc, LAYOUT_AVERAGE_PACE_VALUE_X, LAYOUT_AVERAGE_PACE_VALUE_Y, averagePaceText);

        // ── Lap Info（单圈信息合并行）── T / lap / D 标签 Y 各自独立
        drawLabel(dc, LAYOUT_LAP_INFO_T_X, LAYOUT_LAP_INFO_T_Y, "T");
        drawValue(dc, LAYOUT_LAP_INFO_TIME_X, LAYOUT_LAP_INFO_Y, lapTimeText);
        drawLabel(dc, LAYOUT_LAP_INFO_LAP_X, LAYOUT_LAP_INFO_LAP_Y, "lap");
        drawValue(dc, LAYOUT_LAP_INFO_DIST_X, LAYOUT_LAP_INFO_Y, lapDistanceText);
        drawLabel(dc, LAYOUT_LAP_INFO_D_X, LAYOUT_LAP_INFO_D_Y, "D");

        // ── Battery（电量）：椭圆已在图形层绘制；文字居中在椭圆内 ──
        drawTextAt(dc, LAYOUT_BATTERY_CIRCLE_X, LAYOUT_BATTERY_CIRCLE_Y, mBatteryText, batteryColor(), mFontBattery);
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
        mFontBattery = vectorFont(["RobotoCondensedRegular", "RobotoRegular"], LAYOUT_FONT_BATTERY);
        mFontElapsed = vectorFont(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_FONT_ELAPSED_DISTANCE);
        mFontValue = vectorFont(["RobotoCondensedBold", "RobotoCondensedRegular"], LAYOUT_FONT_VALUE);
    }

    function vectorFont(faces, systemFont) {
        var sized = Graphics.getVectorFont({
            :face => faces,
            :size => Graphics.getFontHeight(systemFont)
        });
        if (sized != null) {
            return sized;
        }
        return systemFont;
    }

    // 指定字体绘制文字，调试模式自动显示边界框。
    function drawTextAt(dc, x, y, text, color, font) {
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(x, y, font, text, LAYOUT_TEXT_JUSTIFY);
        if (DEBUG_LAYOUT) {
            drawDebugBox(dc, x, y, text, font);
        }
    }

    // 累计时间与总距离共用右边缘：4 位（MM:SS）和 5 位数字（H:MM:SS）都对齐到竖线 1 左侧。
    function sharedValueRight() {
        var rightMax = LAYOUT_ELAPSED_VALUE_RIGHT;
        if (rightMax > LAYOUT_VLINE_1_X - 6) {
            rightMax = LAYOUT_VLINE_1_X - 6;
        }
        return rightMax;
    }

    function centerForSharedRight(dc, text, font) {
        var dim = dc.getTextDimensions(text, font) as Array<Number>;
        return sharedValueRight() - (dim[0] / 2);
    }

    function drawElapsedValue(dc, text) {
        drawTextAt(dc, centerForSharedRight(dc, text, mFontElapsed), LAYOUT_ELAPSED_VALUE_Y, text, LAYOUT_TEXT_COLOR, mFontElapsed);
    }
    function drawLabel(dc, x, y, text) {
        drawTextAt(dc, x, y, text, LAYOUT_LABEL_COLOR, LAYOUT_FONT_LABEL);
    }

    // T 在横线 3 上方、D 在下方，到描边的中心距相同。
    function tdLabelY(above) {
        var offset = (LAYOUT_LINE_WIDTH / 2) + LAYOUT_TD_LABEL_LINE_GAP;
        if (above) {
            return LAYOUT_HLINE_3_Y - offset;
        }
        return LAYOUT_HLINE_3_Y + offset;
    }

    // 其他数据数值组字体（LAYOUT_FONT_VALUE）。
    function drawValue(dc, x, y, text) {
        drawTextAt(dc, x, y, text, LAYOUT_TEXT_COLOR, mFontValue);
    }

    // 调试边界框 + 中心十字。
    function drawDebugBox(dc, centerX, centerY, text, font) {
        var dim = dc.getTextDimensions(text, font) as Array<Number>;
        dc.setColor(DEBUG_COLOR, Graphics.COLOR_BLACK);
        dc.drawRectangle(centerX - (dim[0] / 2), centerY - (dim[1] / 2), dim[0], dim[1]);
        dc.drawLine(centerX - 3, centerY, centerX + 3, centerY);
        dc.drawLine(centerX, centerY - 3, centerX, centerY + 3);
    }

    // 五条横线 + 两条竖线；颜色/线宽统一，端点各自独立。
    function drawSeparators(dc) {
        dc.setColor(LAYOUT_LINE_COLOR, Graphics.COLOR_BLACK);
        dc.setPenWidth(LAYOUT_LINE_WIDTH);
        dc.drawLine(LAYOUT_HLINE_1_LEFT, LAYOUT_HLINE_1_Y, LAYOUT_HLINE_1_RIGHT, LAYOUT_HLINE_1_Y);
        dc.drawLine(LAYOUT_HLINE_2_LEFT, LAYOUT_HLINE_2_Y, LAYOUT_HLINE_2_RIGHT, LAYOUT_HLINE_2_Y);
        dc.drawLine(LAYOUT_HLINE_3_LEFT, LAYOUT_HLINE_3_Y, LAYOUT_HLINE_3_RIGHT, LAYOUT_HLINE_3_Y);
        dc.drawLine(LAYOUT_HLINE_4_LEFT, LAYOUT_HLINE_4_Y, LAYOUT_HLINE_4_RIGHT, LAYOUT_HLINE_4_Y);
        dc.drawLine(LAYOUT_HLINE_5_LEFT, LAYOUT_HLINE_5_Y, LAYOUT_HLINE_5_RIGHT, LAYOUT_HLINE_5_Y);
        dc.drawLine(LAYOUT_VLINE_1_X, LAYOUT_VLINE_1_TOP, LAYOUT_VLINE_1_X, LAYOUT_VLINE_1_BOTTOM);
        dc.drawLine(LAYOUT_VLINE_2_X, LAYOUT_VLINE_2_TOP, LAYOUT_VLINE_2_X, LAYOUT_VLINE_2_BOTTOM);
        dc.setPenWidth(1);
    }

    // 五段心率区间彩条：已到达区间用对应色，未到达为暗色。
    function drawHrZoneBar(dc, x, y, width, height, currentZone) {
        var segmentWidth = (width / 5).toNumber();
        if (segmentWidth <= 0) { return; }

        for (var i = 0; i < 5; i += 1) {
            var zoneNum = i + 1;
            var color = LAYOUT_ZONE_COLOR_IDLE;
            if (currentZone != null && currentZone >= zoneNum) {
                color = zoneColor(zoneNum);
            }
            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.fillRectangle(x + i * segmentWidth, y, segmentWidth, height);
        }

        if (currentZone != null && currentZone > 0) {
            var markerX = x + ((currentZone - 1) * segmentWidth) + (segmentWidth / 2).toNumber();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawLine(markerX, y - 4, markerX, y + height + 4);
        }
    }

    // 当前区间颜色；无效区间用暗色。
    function zoneColor(zone) {
        if (zone == 1) { return LAYOUT_ZONE_COLOR_1; }
        if (zone == 2) { return LAYOUT_ZONE_COLOR_2; }
        if (zone == 3) { return LAYOUT_ZONE_COLOR_3; }
        if (zone == 4) { return LAYOUT_ZONE_COLOR_4; }
        if (zone == 5) { return LAYOUT_ZONE_COLOR_5; }
        return LAYOUT_ZONE_COLOR_IDLE;
    }

    // 心率区间圆圈刚好包住 0.0 文字，颜色与分隔线一致。
    function drawZoneCircle(dc, text) {
        var dim = dc.getTextDimensions(text, mFontZone) as Array<Number>;
        var halfW = dim[0] / 2.0;
        var halfH = dim[1] / 2.0;
        var radius = Math.sqrt(halfW * halfW + halfH * halfH).toNumber() + LAYOUT_ZONE_CIRCLE_PAD;
        dc.setColor(LAYOUT_LINE_COLOR, Graphics.COLOR_BLACK);
        dc.setPenWidth(2);
        dc.drawCircle(LAYOUT_ZONE_CIRCLE_X, LAYOUT_ZONE_CIRCLE_Y, radius);
        dc.setPenWidth(1);
    }

    // 电量椭圆：水平按 "100%" 预留固定宽度；垂直贴合当前文字高度（上下更窄）。
    function drawBatteryEllipse(dc) {
        var widthDim = dc.getTextDimensions("100%", mFontBattery) as Array<Number>;
        var heightDim = dc.getTextDimensions(mBatteryText, mFontBattery) as Array<Number>;
        var a = (widthDim[0] / 2) + LAYOUT_BATTERY_ELLIPSE_PAD_X;
        var b = (heightDim[1] / 2) + LAYOUT_BATTERY_ELLIPSE_PAD_Y;
        if (a < LAYOUT_BATTERY_ELLIPSE_A_MIN) {
            a = LAYOUT_BATTERY_ELLIPSE_A_MIN;
        }
        if (b < LAYOUT_BATTERY_ELLIPSE_B_MIN) {
            b = LAYOUT_BATTERY_ELLIPSE_B_MIN;
        }
        dc.setColor(LAYOUT_LINE_COLOR, Graphics.COLOR_BLACK);
        dc.setPenWidth(2);
        dc.drawEllipse(LAYOUT_BATTERY_CIRCLE_X, LAYOUT_BATTERY_CIRCLE_Y, a, b);
        dc.setPenWidth(1);
    }

    // 按电量百分比选择文字/圆颜色。
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
        dc.drawText(cx, cy + 38, Graphics.FONT_TINY, "RunDash 970 · use 1-field layout",
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

    // 小数区间 → 一位小数文本；无数据保持同宽 0.0。
    function zoneShortText(zoneValue) {
        if (zoneValue != null && zoneValue.toFloat() > 0.0) {
            return zoneValue.toFloat().format("%.1f");
        }
        return "0.0";
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
