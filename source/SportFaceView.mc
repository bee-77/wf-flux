import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;
import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Weather;
import Toybox.Math;

// ─── Slot constants ──────────────────────────────────────────────────────────
// 0=Weather  1=Calories  2=Steps  3=Distance  4=Active Min  5=Floors  6=Body Battery

class FluxView extends WatchUi.WatchFace {

    // ── Icons ────────────────────────────────────────────────────────────────
    var mWeatherIcons   as Dictionary = {};
    var mWeatherIconsLg as Dictionary = {};
    var mHeartIcon      as BitmapResource?;
    var mStepsIcon      as BitmapResource?;
    var mHeartIconLg    as BitmapResource?;
    var mStepsIconLg    as BitmapResource?;

    // ── Settings ─────────────────────────────────────────────────────────────
    var mTimeStyle   as Number = 0;  // 0=24h  1=12h
    var mDistUnit    as Number = 0;  // 0=km   1=mi
    var mSlotTL      as Number = 0;  // top-left metric
    var mSlotTR      as Number = 2;  // top-right metric
    var mSlotBL      as Number = 3;  // bottom-left metric
    var mSlotBR      as Number = 1;  // bottom-right metric
    var mAodColor    as Number = 0;  // 0=Blue  1=White

    // ── State ────────────────────────────────────────────────────────────────
    var mWeatherCondition as Number = -1;
    var mSleeping         as Boolean = false;

    // ── Flux palette ─────────────────────────────────────────────────────────
    // Electric blue / cyan on pure black — inspired by the Flux Capacitor
    var C_BG       as Number = 0x000000;
    var C_TIME     as Number = 0xFFFFFF;
    var C_FLUX     as Number = 0x00BBFF;  // electric blue
    var C_FLUX_DIM as Number = 0x003355;  // dark glow
    var C_AMBER    as Number = 0xFFCC00;  // capacitor dot glow
    var C_PRIMARY  as Number = 0x00BBFF;
    var C_MUTED    as Number = 0x778899;
    var C_LABEL    as Number = 0x4466AA;
    var C_DIVIDER  as Number = 0x1A3355;
    var C_BAT_OK   as Number = 0x00CC66;
    var C_BAT_MID  as Number = 0xFFAA00;
    var C_BAT_LOW  as Number = 0xFF3333;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        loadSettings();
    }

    function loadSettings() as Void {
        var v;
        v = Properties.getValue("time_style");  if (v != null) { mTimeStyle = v as Number; }
        v = Properties.getValue("dist_unit");   if (v != null) { mDistUnit  = v as Number; }
        v = Properties.getValue("slot_tl");     if (v != null) { mSlotTL   = v as Number; }
        v = Properties.getValue("slot_tr");     if (v != null) { mSlotTR   = v as Number; }
        v = Properties.getValue("slot_bl");     if (v != null) { mSlotBL   = v as Number; }
        v = Properties.getValue("slot_br");     if (v != null) { mSlotBR   = v as Number; }
        v = Properties.getValue("aod_color");   if (v != null) { mAodColor = v as Number; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  MAIN UPDATE
    // ─────────────────────────────────────────────────────────────────────────
    function onUpdate(dc as Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var lg = (w >= 390);

        // Load icons on first frame
        if (mWeatherIcons.size() == 0) { loadWeatherIcons(lg); }
        if (mHeartIcon == null) {
            try { mHeartIcon = WatchUi.loadResource(Rez.Drawables.ic_heart) as BitmapResource; } catch (ex) {}
        }
        if (mStepsIcon == null) {
            try { mStepsIcon = WatchUi.loadResource(Rez.Drawables.ic_steps) as BitmapResource; } catch (ex) {}
        }
        if (lg) {
            if (mHeartIconLg == null) {
                try { mHeartIconLg = WatchUi.loadResource(Rez.Drawables.ic_heart_lg) as BitmapResource; } catch (ex) {}
            }
            if (mStepsIconLg == null) {
                try { mStepsIconLg = WatchUi.loadResource(Rez.Drawables.ic_steps_lg) as BitmapResource; } catch (ex) {}
            }
        }

        if (mSleeping) {
            drawSleepScreen(dc, w, h, cx, cy);
            return;
        }

        // ── Background ───────────────────────────────────────────────────────
        dc.setColor(C_BG, C_BG);
        dc.clear();

        // ── Bezel ────────────────────────────────────────────────────────────
        drawBezel(dc, w, h, cx, cy);

        // ── Compute vertical layout ──────────────────────────────────────────
        var clockTime = System.getClockTime();
        var timeStr   = buildTimeString(clockTime);
        var tinyH     = 14;
        var timeH     = 60;
        try { tinyH = (dc.getTextDimensions("M", Graphics.FONT_XTINY))[1] as Number; } catch (ex) {}
        try { timeH = (dc.getTextDimensions(timeStr, Graphics.FONT_NUMBER_HOT))[1] as Number; } catch (ex) {}
        var pad = h * 2 / 100;

        // Time: slightly above center
        var yTime    = cy - timeH / 2 - h * 3 / 100;
        var yTopSlot = yTime - tinyH * 2 - pad * 2;
        var lblOff   = tinyH + pad;
        var yInfoRow = yTime + timeH + pad;
        var yFlux    = yInfoRow + tinyH + pad * 3;
        var yBotSlot = h * 76 / 100;

        // ── Top slots ────────────────────────────────────────────────────────
        drawSlotPair(dc, cx, w, yTopSlot, lblOff, mSlotTL, mSlotTR);

        // ── Time (with blue glow) ────────────────────────────────────────────
        dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, yTime + 1, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx - 1, yTime + 1, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx,     yTime - 1, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(C_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yTime, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        if (mTimeStyle == 1) {
            var ampm = (clockTime.hour < 12) ? "AM" : "PM";
            dc.setColor(C_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yTime + timeH + 2, Graphics.FONT_XTINY, ampm, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Info row: Date | HR | Battery ───────────────────────────────────
        drawInfoRow(dc, cx, w, yInfoRow, tinyH, lg);

        // ── Flux Capacitor decoration ────────────────────────────────────────
        drawFluxCapacitor(dc, cx, yFlux, w * 9 / 100);

        // ── Bottom slots ─────────────────────────────────────────────────────
        drawSlotPair(dc, cx, w, yBotSlot, lblOff, mSlotBL, mSlotBR);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  BEZEL
    // ─────────────────────────────────────────────────────────────────────────
    function drawBezel(dc as Dc, w as Number, h as Number, cx as Number, cy as Number) as Void {
        // Outer ring
        dc.setColor(C_DIVIDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(cx, cy, cx - w * 2 / 100, Graphics.ARC_CLOCKWISE, 0, 360);
        dc.setPenWidth(1);
        dc.drawArc(cx, cy, cx - w * 3 / 100, Graphics.ARC_CLOCKWISE, 0, 360);

        // Cardinal tick marks (12, 3, 6, 9 o'clock)
        dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var te = w * 1 / 100;
        var tl = w * 4 / 100;
        dc.drawLine(cx, te,     cx, tl);
        dc.drawLine(cx, h - tl, cx, h - te);
        dc.drawLine(te, cy,     tl, cy);
        dc.drawLine(w - tl, cy, w - te, cy);

        // Minor tick marks
        dc.setPenWidth(1);
        dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
        var r1 = cx - w * 2 / 100;
        var r2 = cx - w * 4 / 100;
        for (var angle = 30; angle < 360; angle += 30) {
            if (angle == 90 || angle == 180 || angle == 270 || angle == 0) { continue; }
            var rad  = angle * 0.01745329f;
            var sinA = Math.sin(rad).toFloat();
            var cosA = Math.cos(rad).toFloat();
            dc.drawLine(
                cx + (r1 * sinA).toNumber(), cy - (r1 * cosA).toNumber(),
                cx + (r2 * sinA).toNumber(), cy - (r2 * cosA).toNumber()
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  FLUX CAPACITOR (Y-shape)
    // ─────────────────────────────────────────────────────────────────────────
    function drawFluxCapacitor(dc as Dc, cx as Number, cy as Number, armLen as Number) as Void {
        // Three arms at 0° (up), 120° (lower-right), 240° (lower-left)
        // Garmin convention: angle 0 = 12 o'clock, clockwise
        // x = cx + armLen * sin(rad)
        // y = cy - armLen * cos(rad)
        var angles = [0, 120, 240] as Array<Number>;
        var endX   = new Array<Number>[3];
        var endY   = new Array<Number>[3];

        for (var i = 0; i < 3; i++) {
            var rad  = angles[i] * 0.01745329f;
            var sinA = Math.sin(rad).toFloat();
            var cosA = Math.cos(rad).toFloat();
            endX[i]  = cx + (armLen * sinA).toNumber();
            endY[i]  = cy - (armLen * cosA).toNumber();
        }

        // Glow halo (thick, dark blue)
        dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        for (var i = 0; i < 3; i++) {
            dc.drawLine(cx, cy, endX[i], endY[i]);
        }

        // Core line (thin, bright blue)
        dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < 3; i++) {
            dc.drawLine(cx, cy, endX[i], endY[i]);
        }

        // Endpoint glow dots (amber — capacitor charge points)
        dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            dc.fillCircle(endX[i], endY[i], 5);
        }
        dc.setColor(C_AMBER, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            dc.fillCircle(endX[i], endY[i], 3);
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            dc.fillCircle(endX[i], endY[i], 1);
        }

        // Center glow
        dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 6);
        dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  INFO ROW  (Date | Heart | Battery)
    // ─────────────────────────────────────────────────────────────────────────
    function drawInfoRow(dc as Dc, cx as Number, w as Number, y as Number, tinyH as Number, lg as Boolean) as Void {
        var now     = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = now.day.format("%02d") + "." + now.month.format("%02d") + "." + (now.year % 100).format("%02d");

        var hrVal = "--";
        try {
            var hrInfo = Activity.getActivityInfo();
            if (hrInfo != null && (hrInfo has :currentHeartRate) && hrInfo.currentHeartRate != null) {
                var hr = hrInfo.currentHeartRate as Number;
                if (hr > 0) { hrVal = hr.toString(); }
            }
        } catch (ex) {}

        var batPct = 0;
        try { batPct = System.getSystemStats().battery.toNumber(); } catch (ex) {}

        var heartW   = lg ? 24 : 18;
        var batBarW  = w * 5 / 100;
        var gap      = w * 2 / 100;
        var bpmStr   = hrVal + " bpm";
        var batStr   = batPct.format("%d") + "%";

        var dateW   = (dc.getTextDimensions(dateStr, Graphics.FONT_XTINY))[0] as Number;
        var bpmW    = (dc.getTextDimensions(bpmStr,  Graphics.FONT_XTINY))[0] as Number;
        var batW    = (dc.getTextDimensions(batStr,  Graphics.FONT_XTINY))[0] as Number;
        var totalW  = dateW + gap + heartW + 2 + bpmW + gap + batBarW + 4 + gap + batW;
        var x       = cx - totalW / 2;

        // Date
        dc.setColor(C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT);
        x += dateW + gap;

        // Heart icon + bpm
        var hIcon = (lg && mHeartIconLg != null) ? mHeartIconLg : mHeartIcon;
        if (hIcon != null) { dc.drawBitmap(x, y + 1, hIcon as BitmapResource); }
        x += heartW + 2;
        dc.setColor(C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, bpmStr, Graphics.TEXT_JUSTIFY_LEFT);
        x += bpmW + gap;

        // Battery bar
        var batColor = (batPct > 50) ? C_BAT_OK : ((batPct > 20) ? C_BAT_MID : C_BAT_LOW);
        var batY     = y + (tinyH - 8) / 2;
        var fillW    = batBarW * batPct / 100;
        dc.setColor(C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x, batY, batBarW, 8);
        dc.fillRectangle(x + batBarW, batY + 2, 2, 4);
        if (fillW > 0) {
            dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 1, batY + 1, fillW - 1, 6);
        }
        x += batBarW + 4 + gap;

        // Battery %
        dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, batStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  SLOT PAIR (left + right, with divider)
    // ─────────────────────────────────────────────────────────────────────────
    function drawSlotPair(dc as Dc, cx as Number, sw as Number, yTop as Number,
                          lblOff as Number, slotL as Number, slotR as Number) as Void {
        var dataL = getSlotData(slotL);
        var dataR = getSlotData(slotR);
        var margin = sw * 4 / 100;
        var iconOff = sw * 20 / 100;

        // Divider line
        dc.setColor(C_DIVIDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx, yTop - 2, cx, yTop + lblOff + 16);

        // Left slot (right-aligned to divider)
        var lGoalColor = (dataL.size() > 2 && dataL[2] != null) ? dataL[2] as Number : -1;
        var lColor     = (lGoalColor != -1) ? lGoalColor : C_PRIMARY;
        dc.setColor(lColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - margin, yTop, Graphics.FONT_XTINY, dataL[0] as String, Graphics.TEXT_JUSTIFY_RIGHT);
        var lLbl = dataL[1] as String;
        dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - margin, yTop + lblOff, Graphics.FONT_XTINY, lLbl, Graphics.TEXT_JUSTIFY_RIGHT);
        // Strike-through label if goal reached
        if (lGoalColor != -1 && !lLbl.equals("")) {
            var d = dc.getTextDimensions(lLbl, Graphics.FONT_XTINY);
            var ly = yTop + lblOff + (d[1] as Number) / 2;
            dc.setPenWidth(1);
            dc.drawLine(cx - margin - (d[0] as Number), ly, cx - margin, ly);
        }
        // Icon left of value
        drawSlotIcon(dc, slotL, cx - iconOff, yTop + 2);

        // Right slot (left-aligned from divider)
        var rIconW    = drawSlotIcon(dc, slotR, cx + margin, yTop + 2);
        var rGoalColor = (dataR.size() > 2 && dataR[2] != null) ? dataR[2] as Number : -1;
        var rColor     = (rGoalColor != -1) ? rGoalColor : C_PRIMARY;
        dc.setColor(rColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + margin + rIconW, yTop, Graphics.FONT_XTINY, dataR[0] as String, Graphics.TEXT_JUSTIFY_LEFT);
        var rLbl = dataR[1] as String;
        dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + margin + rIconW, yTop + lblOff, Graphics.FONT_XTINY, rLbl, Graphics.TEXT_JUSTIFY_LEFT);
        if (rGoalColor != -1 && !rLbl.equals("")) {
            var d = dc.getTextDimensions(rLbl, Graphics.FONT_XTINY);
            var ry = yTop + lblOff + (d[1] as Number) / 2;
            dc.setPenWidth(1);
            dc.drawLine(cx + margin + rIconW, ry, cx + margin + rIconW + (d[0] as Number), ry);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  SLOT DATA
    //  Returns Array: [valueStr, labelStr] or [valueStr, labelStr, goalColor?]
    // ─────────────────────────────────────────────────────────────────────────
    function getSlotData(slot as Number) as Array {
        // 0 — Weather
        if (slot == 0) {
            var tempStr = "--";
            var condStr = "";
            mWeatherCondition = -1;
            try {
                var cond = Weather.getCurrentConditions();
                if (cond != null) {
                    if (cond.temperature != null) {
                        tempStr = (cond.temperature as Number).format("%d") + "°";
                    }
                    if (cond.condition != null) {
                        mWeatherCondition = cond.condition as Number;
                        condStr = weatherLabel(mWeatherCondition);
                    }
                }
            } catch (ex) {}
            return [tempStr, condStr] as Array;
        }

        var act = ActivityMonitor.getInfo();

        // 1 — Calories
        if (slot == 1) {
            var s = "--";
            if (act has :calories && act.calories != null) { s = (act.calories as Number).toString(); }
            return [s, "KCAL"] as Array;
        }

        // 2 — Steps
        if (slot == 2) {
            var steps = 0;
            var stepStr = "--";
            if (act has :steps && act.steps != null) {
                steps = act.steps as Number;
                stepStr = steps.toString();
            }
            var goalStr   = "";
            var goalColor = null;
            if (act has :stepGoal && act.stepGoal != null) {
                var goal = act.stepGoal as Number;
                goalStr = "/ " + goal.toString();
                if (steps > 0 && steps >= goal) { goalColor = C_BAT_OK; }
            }
            return [stepStr, goalStr, goalColor] as Array;
        }

        // 3 — Distance
        if (slot == 3) {
            var distStr = "--";
            if (act has :distance && act.distance != null) {
                var cm = act.distance as Number;  // centimetres
                if (mDistUnit == 1) {
                    // miles
                    var mi = cm / 160934.0f;
                    distStr = mi.format("%.2f");
                } else {
                    // km
                    var km = cm / 100000.0f;
                    distStr = km.format("%.2f");
                }
            }
            var unit = (mDistUnit == 1) ? "MI" : "KM";
            return [distStr, unit] as Array;
        }

        // 4 — Active Minutes
        if (slot == 4) {
            var s = "--";
            if (act has :activeMinutesDay && act.activeMinutesDay != null) {
                var amd = act.activeMinutesDay;
                if (amd has :total && amd.total != null) { s = (amd.total as Number).toString(); }
            }
            return [s, "ACT.MIN"] as Array;
        }

        // 5 — Floors
        if (slot == 5) {
            var s = "--";
            if (act has :floorsClimbed && act.floorsClimbed != null) {
                s = (act.floorsClimbed as Number).toString();
            }
            return [s, "FLOORS"] as Array;
        }

        // 6 — Body Battery
        if (slot == 6) {
            var s = "--";
            try {
                if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                    var hist = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1});
                    if (hist != null) {
                        var sample = hist.next();
                        if (sample != null && sample.data != null) {
                            s = (sample.data as Number).format("%d");
                        }
                    }
                }
            } catch (ex) {}
            return [s, "BODY BAT"] as Array;
        }

        return ["--", ""] as Array;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  SLOT ICON  — returns icon width so caller can offset text
    // ─────────────────────────────────────────────────────────────────────────
    function drawSlotIcon(dc as Dc, slot as Number, x as Number, y as Number) as Number {
        var lg = (dc.getWidth() >= 390);
        if (slot == 0 && mWeatherCondition >= 0) {
            var wIcon = lg ? getWeatherIconLg(mWeatherCondition) : getWeatherIcon(mWeatherCondition);
            if (wIcon == null) { wIcon = getWeatherIcon(mWeatherCondition); }
            if (wIcon != null) {
                dc.drawBitmap(x, y, wIcon as BitmapResource);
                return lg ? 30 : 20;
            }
        } else if (slot == 2) {
            var icon = (lg && mStepsIconLg != null) ? mStepsIconLg : mStepsIcon;
            if (icon != null) {
                dc.drawBitmap(x, y + 2, icon as BitmapResource);
                return lg ? 24 : 16;
            }
        }
        return 0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  SLEEP SCREEN (AOD)
    // ─────────────────────────────────────────────────────────────────────────
    function drawSleepScreen(dc as Dc, w as Number, h as Number, cx as Number, cy as Number) as Void {
        dc.setColor(C_BG, C_BG);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeStr   = buildTimeString(clockTime);
        var yTime     = h * 35 / 100;

        // Outline (1px offset, white)
        dc.setColor(0x001133, Graphics.COLOR_TRANSPARENT);
        for (var dx = -1; dx <= 1; dx++) {
            for (var dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0) { continue; }
                dc.drawText(cx + dx, yTime + dy, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Fill color
        var aodFill = (mAodColor == 1) ? 0xFFFFFF : C_FLUX;
        dc.setColor(aodFill, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yTime, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Tiny flux capacitor in AOD
        var tinyH = 14;
        try { tinyH = (dc.getTextDimensions("M", Graphics.FONT_XTINY))[1] as Number; } catch (ex) {}
        var yFlux = h * 65 / 100;
        drawFluxCapacitor(dc, cx, yFlux, w * 6 / 100);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  HELPERS
    // ─────────────────────────────────────────────────────────────────────────
    function buildTimeString(clockTime as ClockTime) as String {
        if (mTimeStyle == 1) {
            var hr = clockTime.hour % 12;
            if (hr == 0) { hr = 12; }
            return hr.format("%d") + ":" + clockTime.min.format("%02d");
        }
        return clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
    }

    function loadWeatherIcons(useLarge as Boolean) as Void {
        try {
            mWeatherIcons[Weather.CONDITION_CLEAR]         = WatchUi.loadResource(Rez.Drawables.ic_sun);
            mWeatherIcons[Weather.CONDITION_PARTLY_CLOUDY] = WatchUi.loadResource(Rez.Drawables.ic_partly_cloudy);
            mWeatherIcons[Weather.CONDITION_CLOUDY]        = WatchUi.loadResource(Rez.Drawables.ic_cloudy);
            mWeatherIcons[Weather.CONDITION_RAIN]          = WatchUi.loadResource(Rez.Drawables.ic_rain);
            mWeatherIcons[Weather.CONDITION_SNOW]          = WatchUi.loadResource(Rez.Drawables.ic_snow);
            mWeatherIcons[Weather.CONDITION_FOG]           = WatchUi.loadResource(Rez.Drawables.ic_fog);
            if (useLarge) {
                mWeatherIconsLg[Weather.CONDITION_CLEAR]         = WatchUi.loadResource(Rez.Drawables.ic_sun_lg);
                mWeatherIconsLg[Weather.CONDITION_PARTLY_CLOUDY] = WatchUi.loadResource(Rez.Drawables.ic_partly_cloudy_lg);
                mWeatherIconsLg[Weather.CONDITION_CLOUDY]        = WatchUi.loadResource(Rez.Drawables.ic_cloudy_lg);
                mWeatherIconsLg[Weather.CONDITION_RAIN]          = WatchUi.loadResource(Rez.Drawables.ic_rain_lg);
                mWeatherIconsLg[Weather.CONDITION_SNOW]          = WatchUi.loadResource(Rez.Drawables.ic_snow_lg);
                mWeatherIconsLg[Weather.CONDITION_FOG]           = WatchUi.loadResource(Rez.Drawables.ic_fog_lg);
            }
        } catch (ex) {}
        try {
            if (Weather has :CONDITION_THUNDERSTORM) {
                mWeatherIcons[Weather.CONDITION_THUNDERSTORM] = WatchUi.loadResource(Rez.Drawables.ic_storm);
                if (useLarge) {
                    mWeatherIconsLg[Weather.CONDITION_THUNDERSTORM] = WatchUi.loadResource(Rez.Drawables.ic_storm_lg);
                }
            }
        } catch (ex) {}
    }

    function getWeatherIcon(condition as Number) as BitmapResource? {
        if (mWeatherIcons.hasKey(condition)) { return mWeatherIcons[condition] as BitmapResource; }
        return null;
    }

    function getWeatherIconLg(condition as Number) as BitmapResource? {
        if (mWeatherIconsLg.hasKey(condition)) { return mWeatherIconsLg[condition] as BitmapResource; }
        return null;
    }

    function weatherLabel(condition as Number) as String {
        if (condition == Weather.CONDITION_CLEAR)         { return "Clear"; }
        if (condition == Weather.CONDITION_PARTLY_CLOUDY) { return "Partly Cloudy"; }
        if (condition == Weather.CONDITION_CLOUDY)        { return "Cloudy"; }
        if (condition == Weather.CONDITION_RAIN)          { return "Rain"; }
        if (condition == Weather.CONDITION_SNOW)          { return "Snow"; }
        if (condition == Weather.CONDITION_FOG)           { return "Fog"; }
        if ((Weather has :CONDITION_THUNDERSTORM) && condition == Weather.CONDITION_THUNDERSTORM) { return "Storm"; }
        return "---";
    }

    function onEnterSleep() as Void { mSleeping = true;  WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { mSleeping = false; WatchUi.requestUpdate(); }
}
