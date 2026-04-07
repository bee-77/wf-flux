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

class SportFaceView extends WatchUi.WatchFace {

    var mBgBlack     as BitmapResource?;
    var mBgLight     as BitmapResource?;
    var mBgLoaded    as Boolean = false;
    var mWeatherIcons   as Dictionary = {};
    var mWeatherIconsLg as Dictionary = {};
    var mHeartIcon      as BitmapResource?;
    var mStepsIcon      as BitmapResource?;
    var mHeartIconLg    as BitmapResource?;
    var mStepsIconLg    as BitmapResource?;

    var mTheme       as Number = 0;  // 0=Black, 1=Light
    var mWeatherCondition as Number = -1;
    var mTimeStyle   as Number = 1;  // 0=12h, 1=Military (24h)
    var mTopLeft     as Number = 0;  // 0=Wetter, 1=Kalorien, 2=Schritte, 3=Stockwerke, 4=Aktivitätszeit
    var mTopRight    as Number = 2;

    var mSleeping    as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        loadSettings();
    }

    function loadSettings() as Void {
        var prevTheme = mTheme;
        var theme = Properties.getValue("bg_theme");
        if (theme != null) { mTheme = theme as Number; }
        var ts = Properties.getValue("time_style"); if (ts != null) { mTimeStyle = ts as Number; }
        var tl = Properties.getValue("top_left");   if (tl != null) { mTopLeft = tl as Number; }
        var tr = Properties.getValue("top_right");  if (tr != null) { mTopRight = tr as Number; }
        // Theme gewechselt → anderen Background nachladen
        if (mTheme != prevTheme) {
            mBgLoaded = false;
            mBgBlack  = null;
            mBgLight  = null;
        }
    }

    function getThemeColors() as Dictionary {
        if (mTheme == 1) {
            // Orange-Hintergrund: alle Texte/Icons weiß
            return {
                "time"     => 0xFFFFFF, "primary"  => 0xFFFFFF,
                "secondary"=> 0xFFE0CC, "divider"  => 0xFFFFFF,
                "slogan"   => 0xFFFFFF, "muted"    => 0xDDDDDD,
                "divider2" => 0xFF9944, "label"    => 0xFFFFFF
            };
        } else {
            return {
                "time"     => 0xFFFFFF, "primary"  => 0xFFFFFF,
                "secondary"=> 0xFFE0CC, "divider"  => 0xFF6600,
                "slogan"   => 0xFF6600, "muted"    => 0xDDDDDD,
                "divider2" => 0x333333, "label"    => 0xFFFFFF
            };
        }
    }

    function onUpdate(dc as Dc) as Void {
        var w  = dc.getWidth();
        var dh = dc.getHeight();
        var cx = w / 2;
        var cy = dh / 2;

        // Nur den aktiven Theme-Background laden (gerätespezifisch via monkey.jungle)
        if (!mBgLoaded) {
            mBgLoaded = true;
            if (mTheme == 1) {
                try { mBgLight = WatchUi.loadResource(Rez.Drawables.bg_light) as BitmapResource; } catch (ex) {}
            } else {
                try { mBgBlack = WatchUi.loadResource(Rez.Drawables.bg_black) as BitmapResource; } catch (ex) {}
            }
        }
        var useLarge = (w >= 390);
        if (mWeatherIcons.size() == 0) { loadWeatherIcons(useLarge); }
        if (mHeartIcon == null) { try { mHeartIcon = WatchUi.loadResource(Rez.Drawables.ic_heart) as BitmapResource; } catch (ex) {} }
        if (mStepsIcon == null) { try { mStepsIcon = WatchUi.loadResource(Rez.Drawables.ic_steps) as BitmapResource; } catch (ex) {} }
        if (useLarge) {
            if (mHeartIconLg == null) { try { mHeartIconLg = WatchUi.loadResource(Rez.Drawables.ic_heart_lg) as BitmapResource; } catch (ex) {} }
            if (mStepsIconLg == null) { try { mStepsIconLg = WatchUi.loadResource(Rez.Drawables.ic_steps_lg) as BitmapResource; } catch (ex) {} }
        }

        var colors = getThemeColors();

        if (mSleeping) {
            drawSleepScreen(dc, cx, dh);
            return;
        }

        // Hintergrundfarbe solide füllen
        if (mTheme == 1) {
            dc.setColor(0xFF6600, 0xFF6600);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        }
        dc.clear();

        // Logo-Bitmap zeichnen
        var bg = (mTheme == 1) ? mBgLight : mBgBlack;
        if (bg != null) {
            dc.drawBitmap(0, 0, bg);
        }

        // === Dekorative Lünette (äußerer Ring) ===
        var bezelColor = (mTheme == 1) ? 0xCC5500 : 0x332200;
        dc.setColor(bezelColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(cx, cy, cx - w * 2 / 100, Graphics.ARC_CLOCKWISE, 0, 360);
        var innerRing = (mTheme == 1) ? 0xFF8833 : 0x553300;
        dc.setColor(innerRing, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(cx, cy, cx - w * 3 / 100, Graphics.ARC_CLOCKWISE, 0, 360);

        // === Tick-Marks ===
        var tickColor = (mTheme == 1) ? 0xFFFFFF : 0xFF6600;
        dc.setColor(tickColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var te = w * 1 / 100;
        var tl = w * 4 / 100;
        dc.drawLine(cx, te, cx, tl);
        dc.drawLine(cx, w - tl, cx, w - te);
        dc.drawLine(te, cy, tl, cy);
        dc.drawLine(w - tl, cy, w - te, cy);
        dc.setPenWidth(1);
        var r1 = cx - w * 2 / 100;
        var r2 = cx - w * 4 / 100;
        for (var angle = 30; angle < 360; angle += 30) {
            if (angle == 90 || angle == 180 || angle == 270 || angle == 0) { continue; }
            var rad = angle * 0.01745329f;
            var sinA = Toybox.Math.sin(rad);
            var cosA = Toybox.Math.cos(rad);
            var x1 = cx + (r1 * sinA).toNumber();
            var y1 = cy - (r1 * cosA).toNumber();
            var x2 = cx + (r2 * sinA).toNumber();
            var y2 = cy - (r2 * cosA).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }

        // ── LAYOUT ──────────────────────────────────────────────────────────────
        // 1. Wetter/Schritte (Slots)  2. Uhrzeit (zentral)  3. Datum+HR  4. Slogan
        var clockTime = System.getClockTime();
        var timeStr = "";
        if (mTimeStyle == 0) {
            var hr = clockTime.hour % 12;
            if (hr == 0) { hr = 12; }
            timeStr = hr.format("%d") + ":" + clockTime.min.format("%02d");
        } else {
            timeStr = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
        }
        var tinyH = 14;
        var timeH = 60;
        try { tinyH = (dc.getTextDimensions("Mi", Graphics.FONT_XTINY))[1]         as Number; } catch (ex) {}
        try { timeH = (dc.getTextDimensions(timeStr, Graphics.FONT_NUMBER_HOT))[1] as Number; } catch (ex) {}
        var pad   = dh * 2 / 100;

        // Uhrzeit vertikal zentrieren (leicht nach oben versetzt)
        var yTime    = cy - timeH / 2 - dh * 4 / 100;
        var yTopSlot = yTime - tinyH * 2 - pad * 3;
        var lblOff   = tinyH + pad;
        var yDateHr  = yTime + timeH + pad;
        var ySlog1   = dh * 82 / 100;
        var ySlog2   = ySlog1 + tinyH;
        var dotY     = ySlog1 - pad;

        // Top-Slots (Wetter + Schritte)
        drawTopSlots(dc, cx, colors, w, yTopSlot, lblOff);

        // Uhrzeit (mit Glow — auf Orange-Theme dunkler Schatten)
        var glowColor = (mTheme == 1) ? 0x552200 : 0xFF6600;
        dc.setColor(glowColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, yTime + 1, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx - 1, yTime + 1, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx,     yTime - 1, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(colors["time"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yTime, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        if (mTimeStyle == 0) {
            var ampm = (clockTime.hour < 12) ? "AM" : "PM";
            dc.setColor(colors["secondary"] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yTime + timeH + pad / 2, Graphics.FONT_XTINY, ampm, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Datum + Herzfrequenz + Akku — als Block zentriert
        var now      = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr  = now.day.format("%02d") + "." + now.month.format("%02d") + "." + (now.year % 100).format("%02d");
        var hrVal    = "--";
        try {
            var hrInfo = Activity.getActivityInfo();
            if (hrInfo != null && (hrInfo has :currentHeartRate) && hrInfo.currentHeartRate != null && (hrInfo.currentHeartRate as Number) > 0) {
                hrVal = (hrInfo.currentHeartRate as Number).toString();
            }
        } catch (ex) {}
        var batPct   = 0;
        try { batPct = System.getSystemStats().battery.toNumber(); } catch (ex) {}

        var heartW   = (w >= 390) ? 24 : 18;
        var batBarW  = w * 5 / 100;
        var iGap     = w * 2 / 100;  // innerer Abstand zwischen Elementen
        var bpmStr   = hrVal + " bpm";
        var batPctStr = batPct.format("%d") + "%";

        // Gesamtbreite messen → Block zentrieren
        var dateW    = (dc.getTextDimensions(dateStr,   Graphics.FONT_XTINY))[0] as Number;
        var bpmW     = (dc.getTextDimensions(bpmStr,    Graphics.FONT_XTINY))[0] as Number;
        var batPctW  = (dc.getTextDimensions(batPctStr, Graphics.FONT_XTINY))[0] as Number;
        var totalW   = dateW + iGap + heartW + 2 + bpmW + iGap + batBarW + 2 + iGap + batPctW;
        var startX   = cx - totalW / 2;

        // Positionen
        var xDate    = startX;
        var xHeart   = xDate  + dateW + iGap;
        var xBpm     = xHeart + heartW + 2;
        var xBatBar  = xBpm   + bpmW  + iGap;
        var xBatPct  = xBatBar + batBarW + 2 + iGap;
        var batY     = yDateHr + (tinyH - 8) / 2;

        // Datum
        dc.setColor(colors["muted"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xDate, yDateHr, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT);

        // Herzfrequenz
        var heartIcon = (w >= 390 && mHeartIconLg != null) ? mHeartIconLg : mHeartIcon;
        if (heartIcon != null) { dc.drawBitmap(xHeart, yDateHr + 1, heartIcon as BitmapResource); }
        dc.setColor(colors["muted"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xBpm, yDateHr, Graphics.FONT_XTINY, bpmStr, Graphics.TEXT_JUSTIFY_LEFT);

        // Akkubalken
        var batColor = (batPct > 50) ? 0x00AA00 : ((batPct > 20) ? 0xFF9900 : 0xCC0000);
        var fillW    = batBarW * batPct / 100;
        dc.setColor(colors["muted"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(xBatBar, batY, batBarW, 8);
        dc.fillRectangle(xBatBar + batBarW, batY + 2, 2, 4);
        dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
        if (fillW > 0) { dc.fillRectangle(xBatBar + 1, batY + 1, fillW - 1, 6); }
        dc.setColor(colors["muted"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xBatPct, yDateHr, Graphics.FONT_XTINY, batPctStr, Graphics.TEXT_JUSTIFY_LEFT);

        // Slogan
        dc.setColor(colors["divider"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - w * 21 / 100, dotY, 2);
        dc.fillCircle(cx + w * 21 / 100, dotY, 2);
        dc.setColor(colors["slogan"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ySlog1, Graphics.FONT_XTINY, "ALLES KANN.",  Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, ySlog2, Graphics.FONT_XTINY, "NICHTS MUSS!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function getTopSlotData(slot as Number) as Array {
        if (slot == 0) {
            var tempStr = "--"; var condStr = "";
            mWeatherCondition = -1;
            try {
                var cond = Weather.getCurrentConditions();
                if (cond != null) {
                    if (cond.temperature != null) { tempStr = cond.temperature.format("%d") + "C"; }
                    if (cond.condition  != null)  {
                        mWeatherCondition = cond.condition as Number;
                        condStr = weatherLabel(mWeatherCondition);
                    }
                }
            } catch (ex) {}
            return [tempStr, condStr] as Array;
        }
        var actInfo = ActivityMonitor.getInfo();
        if (slot == 1) {
            var calStr = "--";
            if (actInfo has :calories && actInfo.calories != null) { calStr = actInfo.calories.toString(); }
            return [calStr, "KCAL"] as Array;
        } else if (slot == 2) {
            var stepStr = "--";
            var steps = 0;
            if (actInfo has :steps && actInfo.steps != null) {
                steps = actInfo.steps as Number;
                stepStr = steps.toString();
            }
            var goalStr = "";
            var goalColor = null;
            if (actInfo has :stepGoal && actInfo.stepGoal != null) {
                var goal = actInfo.stepGoal as Number;
                goalStr = "/ " + goal.toString();
                if (steps > 0 && steps >= goal) { goalColor = 0x00AA00; }
            }
            return [stepStr, goalStr, goalColor] as Array;
        } else if (slot == 3) {
            var floorStr = "--";
            if (actInfo has :floorsClimbed && actInfo.floorsClimbed != null) { floorStr = actInfo.floorsClimbed.toString(); }
            return [floorStr, "FLOORS"] as Array;
        } else {
            var minStr = "--";
            if (actInfo has :activeMinutesDay && actInfo.activeMinutesDay != null) {
                var amd = actInfo.activeMinutesDay;
                if (amd has :total && amd.total != null) { minStr = amd.total.toString(); }
            }
            return [minStr, "ACT.MIN"] as Array;
        }
    }

    function drawTopSlots(dc as Dc, cx as Number, colors as Dictionary, sw as Number, yTop as Number, lblOff as Number) as Void {
        var leftData  = getTopSlotData(mTopLeft);
        var rightData = getTopSlotData(mTopRight);
        var xOff = sw * 22 / 100;

        // Linker Slot (rechtsbündig zur Trennlinie)
        var lMargin = sw * 4 / 100;
        var goalReachedL = (leftData.size() > 2 && leftData[2] != null);
        var leftColor = goalReachedL ? leftData[2] as Number : colors["time"] as Number;
        dc.setColor(leftColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - lMargin, yTop, Graphics.FONT_XTINY, leftData[0] as String, Graphics.TEXT_JUSTIFY_RIGHT);
        var lLabel = leftData[1] as String;
        dc.setColor(colors["muted"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - lMargin, yTop + lblOff, Graphics.FONT_XTINY, lLabel, Graphics.TEXT_JUSTIFY_RIGHT);
        if (goalReachedL && !lLabel.equals("")) {
            var dims = dc.getTextDimensions(lLabel, Graphics.FONT_XTINY);
            var ly = yTop + lblOff + (dims[1] as Number) / 2;
            dc.setPenWidth(1);
            dc.drawLine(cx - lMargin - (dims[0] as Number), ly, cx - lMargin, ly);
        }
        // Icon links vor dem Text
        drawSlotIcon(dc, mTopLeft, cx - xOff, yTop + 2);

        // Trennlinie
        dc.setColor(colors["divider2"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx, yTop - 2, cx, yTop + lblOff + 16);

        // Rechter Slot
        var rOff = sw * 8 / 100;
        var iconW2 = drawSlotIcon(dc, mTopRight, cx + rOff, yTop + 2);
        var goalReachedR = (rightData.size() > 2 && rightData[2] != null);
        var rightColor = goalReachedR ? rightData[2] as Number : colors["time"] as Number;
        dc.setColor(rightColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + rOff + iconW2, yTop, Graphics.FONT_XTINY, rightData[0] as String, Graphics.TEXT_JUSTIFY_LEFT);
        var rLabel = rightData[1] as String;
        dc.setColor(colors["muted"] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + rOff + iconW2, yTop + lblOff, Graphics.FONT_XTINY, rLabel, Graphics.TEXT_JUSTIFY_LEFT);
        if (goalReachedR && !rLabel.equals("")) {
            var dims = dc.getTextDimensions(rLabel, Graphics.FONT_XTINY);
            var ry = yTop + lblOff + (dims[1] as Number) / 2;
            dc.setPenWidth(1);
            dc.drawLine(cx + rOff + iconW2, ry, cx + rOff + iconW2 + (dims[0] as Number), ry);
        }
    }

    function drawSlotIcon(dc as Dc, slot as Number, x as Number, y as Number) as Number {
        var large = (dc.getWidth() >= 390);
        if (slot == 0 && mWeatherCondition >= 0) {
            var wIcon = large ? getWeatherIconLg(mWeatherCondition) : getWeatherIcon(mWeatherCondition);
            if (wIcon == null) { wIcon = getWeatherIcon(mWeatherCondition); }
            if (wIcon != null) {
                dc.drawBitmap(x, y, wIcon as BitmapResource);
                return large ? 30 : 20;
            }
        } else if (slot == 2) {
            var icon = large ? mStepsIconLg : mStepsIcon;
            if (icon != null) {
                dc.drawBitmap(x, y + 2, icon as BitmapResource);
                return large ? 24 : 16;
            }
        }
        return 0;
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
        if (mWeatherIcons.hasKey(condition)) {
            return mWeatherIcons[condition] as BitmapResource;
        }
        return null;
    }

    function getWeatherIconLg(condition as Number) as BitmapResource? {
        if (mWeatherIconsLg.hasKey(condition)) {
            return mWeatherIconsLg[condition] as BitmapResource;
        }
        return null;
    }

    function weatherLabel(condition as Number) as String {
        if (condition == Weather.CONDITION_CLEAR)         { return "Klar"; }
        if (condition == Weather.CONDITION_PARTLY_CLOUDY) { return "Wolkig"; }
        if (condition == Weather.CONDITION_CLOUDY)        { return "Bedeckt"; }
        if (condition == Weather.CONDITION_RAIN)          { return "Regen"; }
        if (condition == Weather.CONDITION_SNOW)          { return "Schnee"; }
        if (condition == Weather.CONDITION_FOG)           { return "Nebel"; }
        if ((Weather has :CONDITION_THUNDERSTORM) && condition == Weather.CONDITION_THUNDERSTORM) { return "Gewitter"; }
        return "---";
    }

    function drawSleepScreen(dc as Dc, cx as Number, h as Number) as Void {
        // Schwarzer Hintergrund
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Uhrzeit zentriert
        var clockTime = System.getClockTime();
        var timeStr = "";
        if (mTimeStyle == 0) {
            var hr = clockTime.hour % 12;
            if (hr == 0) { hr = 12; }
            timeStr = hr.format("%d") + ":" + clockTime.min.format("%02d");
        } else {
            timeStr = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
        }
        dc.setColor(0x552200, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 35 / 100, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Slogan unten
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 82 / 100, Graphics.FONT_XTINY, "ALLES KANN.",  Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 87 / 100, Graphics.FONT_XTINY, "NICHTS MUSS!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onEnterSleep() as Void { mSleeping = true;  WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { mSleeping = false; WatchUi.requestUpdate(); }
}
