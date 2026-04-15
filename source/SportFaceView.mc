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
    var mHeartIconLg    as BitmapResource?;

    // ── Settings ─────────────────────────────────────────────────────────────
    var mTimeStyle  as Number = 0;  // 0=24h  1=12h
    var mDistUnit   as Number = 0;  // 0=km   1=mi
    var mSlotTop    as Number = 0;  // top arm  (default: Weather)
    var mSlotLeft   as Number = 3;  // left arm (default: Distance)
    var mSlotRight  as Number = 2;  // right arm (default: Steps)
    var mAodColor   as Number = 0;  // 0=Blue  1=White

    // ── State ────────────────────────────────────────────────────────────────
    var mWeatherCondition as Number = -1;
    var mSleeping         as Boolean = false;

    // ── Flux palette ─────────────────────────────────────────────────────────
    var C_BG       as Number = 0x000000;
    var C_TIME     as Number = 0xFFFFFF;
    var C_FLUX     as Number = 0x00BBFF;
    var C_FLUX_DIM as Number = 0x003355;
    var C_AMBER    as Number = 0xFFCC00;
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
        v = Properties.getValue("slot_top");    if (v != null) { mSlotTop   = v as Number; }
        v = Properties.getValue("slot_left");   if (v != null) { mSlotLeft  = v as Number; }
        v = Properties.getValue("slot_right");  if (v != null) { mSlotRight = v as Number; }
        v = Properties.getValue("aod_color");   if (v != null) { mAodColor  = v as Number; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  MAIN UPDATE
    // ─────────────────────────────────────────────────────────────────────────
    function onUpdate(dc as Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var lg = (w >= 390);

        // Load icons on first frame
        if (mWeatherIcons.size() == 0) { loadWeatherIcons(lg); }
        if (mHeartIcon == null) {
            try { mHeartIcon = WatchUi.loadResource(Rez.Drawables.ic_heart) as BitmapResource; } catch (ex) {}
        }
        if (lg && mHeartIconLg == null) {
            try { mHeartIconLg = WatchUi.loadResource(Rez.Drawables.ic_heart_lg) as BitmapResource; } catch (ex) {}
        }

        if (mSleeping) {
            drawSleepScreen(dc, w, h, cx);
            return;
        }

        // ── Background + Bezel ───────────────────────────────────────────────
        drawBackground(dc, w, h, cx);
        drawBezel(dc, w, h, cx);

        // ── Layout constants ─────────────────────────────────────────────────
        var clockTime = System.getClockTime();
        var timeStr   = buildTimeString(clockTime);
        var tinyH     = 12;
        try { tinyH = (dc.getTextDimensions("M", Graphics.FONT_XTINY))[1] as Number; } catch (ex) {}
        var timeH     = 40;
        try { timeH = (dc.getTextDimensions("0", Graphics.FONT_NUMBER_MILD))[1] as Number; } catch (ex) {}

        // ── Y-Logo geometry ──────────────────────────────────────────────────
        // Center of Y: 42% down, arm spans 18% of width
        var arm    = w * 18 / 100;
        var cyFlux = h * 42 / 100;

        // Tip positions (Garmin: 0°=up, x=cx+arm*sin, y=cy-arm*cos)
        var tipTopX = cx;
        var tipTopY = cyFlux - arm;
        var tipRX   = cx + (arm * 0.86603f).toNumber();   // lower-right (120°)
        var tipRY   = cyFlux + (arm * 0.5f).toNumber();
        var tipLX   = cx - (arm * 0.86603f).toNumber();   // lower-left  (240°)
        var tipLY   = tipRY;

        var dotR    = mathMax(4, arm / 8);

        // ── Data at arm tips ─────────────────────────────────────────────────
        // Draw before flux so dots render on top
        drawTipData(dc, tipTopX, tipTopY, dotR, mSlotTop,   0, tinyH);
        drawTipData(dc, tipLX,   tipLY,   dotR, mSlotLeft,  1, tinyH);
        drawTipData(dc, tipRX,   tipRY,   dotR, mSlotRight, 2, tinyH);

        // ── Flux Capacitor (Y) ───────────────────────────────────────────────
        drawFluxCapacitor(dc, cx, cyFlux, arm);

        // ── Time: Stunden fett+hell, Minuten regulär Flux-Blau ───────────────
        var yTime    = cyFlux + arm / 2 + dotR + h * 2 / 100;
        var colonIdx = timeStr.find(":");
        if (colonIdx != null) {
            var ci   = colonIdx as Number;
            var hStr = timeStr.substring(0, ci) as String;
            var mStr = timeStr.substring(ci, timeStr.length()) as String;
            var hW   = (dc.getTextDimensions(hStr, Graphics.FONT_NUMBER_MILD))[0] as Number;
            var mW   = (dc.getTextDimensions(mStr, Graphics.FONT_NUMBER_MILD))[0] as Number;
            var xH   = cx - (hW + mW) / 2;
            var xM   = xH + hW;

            // Glow-Schatten (dunkelblau, versetzt)
            dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xH + 1, yTime + 1, Graphics.FONT_NUMBER_MILD, hStr, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(xM + 1, yTime + 1, Graphics.FONT_NUMBER_MILD, mStr, Graphics.TEXT_JUSTIFY_LEFT);

            // Stunden: fake-bold (3 Passes, fast Weiß-Blau)
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xH - 1, yTime, Graphics.FONT_NUMBER_MILD, hStr, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(xH + 1, yTime, Graphics.FONT_NUMBER_MILD, hStr, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(xH,     yTime, Graphics.FONT_NUMBER_MILD, hStr, Graphics.TEXT_JUSTIFY_LEFT);

            // Minuten + Doppelpunkt: Flux-Blau, einfacher Pass
            dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xM, yTime, Graphics.FONT_NUMBER_MILD, mStr, Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 1, yTime + 1, Graphics.FONT_NUMBER_MILD, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yTime, Graphics.FONT_NUMBER_MILD, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Wochentag + Datum in 3D-Box ──────────────────────────────────────
        var now      = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days     = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Array<String>;
        var dow      = 0;
        try { dow = now.day_of_week as Number; } catch (ex) {}
        var dayAbbr  = (dow >= 1 && dow <= 7) ? days[dow - 1] : "";
        var dateStr  = now.day.format("%02d") + "." + now.month.format("%02d") + "." + (now.year % 100).format("%02d");
        var ampmStr  = (mTimeStyle == 1) ? ((clockTime.hour < 12) ? "  AM" : "  PM") : "";
        var fullDate = dayAbbr + "  " + dateStr + ampmStr;

        // Untere Zeilen von unten ankern
        var yInfo   = h * 87 / 100;
        var boxPadX = w * 4 / 100;
        var boxPadY = 4;
        var boxW    = (dc.getTextDimensions(fullDate, Graphics.FONT_XTINY))[0] as Number + 2 * boxPadX;
        var boxH    = tinyH + 2 * boxPadY;
        var yDate   = yInfo - boxH - 6;
        var boxX    = cx - boxW / 2;
        var boxY    = yDate;

        // 3D-Box: dunkle Füllung
        dc.setColor(0x060E18, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(boxX, boxY, boxW, boxH, 3);
        // Highlight: oben + links (Lichtquelle oben-links)
        dc.setColor(0x1E3248, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(boxX + 3, boxY,          boxX + boxW - 4, boxY);
        dc.drawLine(boxX,     boxY + 1,      boxX,            boxY + boxH - 2);
        // Schatten: unten + rechts
        dc.setColor(0x010406, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(boxX + 3, boxY + boxH - 1, boxX + boxW - 4, boxY + boxH - 1);
        dc.drawLine(boxX + boxW - 1, boxY + 1, boxX + boxW - 1, boxY + boxH - 2);
        // Datum-Text
        dc.setColor(0x6688AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, boxY + boxPadY, Graphics.FONT_XTINY, fullDate, Graphics.TEXT_JUSTIFY_CENTER);

        // ── HR + Akku ────────────────────────────────────────────────────────
        drawInfoStrip(dc, cx, w, yInfo, tinyH, lg);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  DATA AT TIP
    //  side: 0=top (above dot, centered)  1=left (right-justify)  2=right (left-justify)
    // ─────────────────────────────────────────────────────────────────────────
    function drawTipData(dc as Dc, tx as Number, ty as Number, dotR as Number,
                         slot as Number, side as Number, tinyH as Number) as Void {
        var data  = getSlotData(slot);
        var val   = data[0] as String;
        var lbl   = data[1] as String;
        var color = (data.size() > 2 && data[2] != null) ? data[2] as Number : C_PRIMARY;
        var gap   = 4;

        if (side == 0) {
            // Above the top dot, centered on cx
            var yVal = ty - dotR - gap - tinyH;
            var yLbl = yVal - tinyH - 2;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tx, yVal, Graphics.FONT_XTINY, val, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tx, yLbl, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (side == 1) {
            // Left of left dot, right-justified
            var xEdge = tx - dotR - gap;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xEdge, ty - tinyH - 1, Graphics.FONT_XTINY, val, Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xEdge, ty + 2, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_RIGHT);
        } else {
            // Right of right dot, left-justified
            var xEdge = tx + dotR + gap;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xEdge, ty - tinyH - 1, Graphics.FONT_XTINY, val, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xEdge, ty + 2, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  BACKGROUND  — Deep-Space radiale Vignette
    // ─────────────────────────────────────────────────────────────────────────
    function drawBackground(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        var cy = h / 2;
        var r  = cx;

        // Reines Schwarz als Basis
        dc.setColor(0x000000, 0x000000);
        dc.clear();

        // Radiale Vignette: jede kleinere Kreisfüllung überschreibt das Zentrum →
        // Ränder behalten die äußere Farbe (tiefes Weltraum-Blau), Mitte = reines Schwarz
        dc.setColor(0x001828, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 88 / 100);
        dc.setColor(0x001020, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 74 / 100);
        dc.setColor(0x000C18, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 60 / 100);
        dc.setColor(0x000810, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 46 / 100);
        dc.setColor(0x000408, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 32 / 100);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 18 / 100);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  BEZEL  — 3D Premium-Metallring + verfeinerte Ticks
    // ─────────────────────────────────────────────────────────────────────────
    function drawBezel(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        var cy = h / 2;
        var r  = cx;

        // ── Bezel-Körper: dunkler Metallring ──────────────────────────────────
        dc.setColor(0x141416, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w * 5 / 100);
        dc.drawArc(cx, cy, r - w * 25 / 1000, Graphics.ARC_CLOCKWISE, 0, 360);

        // ── Bevel-Highlight oben/links (Lichtquelle 11 Uhr) ──────────────────
        // Garmin: 0°=Ost, 90°=Nord(oben), ARC_COUNTER_CLOCKWISE 0→180 = obere Hälfte
        dc.setColor(0x505058, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(cx, cy, r - 1, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.setColor(0x2C2C34, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(cx, cy, r - 3, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);

        // ── Bevel-Schatten unten/rechts ───────────────────────────────────────
        dc.setColor(0x050506, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(cx, cy, r - 1, Graphics.ARC_CLOCKWISE, 0, 180);

        // ── Kardinalstriche — 3D (Schatten + Körper + Spekularhighlight) ──────
        var te = w * 1 / 100;
        var tl = w * 8 / 100;
        var tm = w * 5 / 100;

        // Schatten (1px versetzt, dunkelblau)
        dc.setColor(0x002244, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(cx + 1, te + 1,     cx + 1, tl + 1);
        dc.drawLine(cx + 1, h - tl - 1, cx + 1, h - te - 1);
        dc.drawLine(te + 1, cy + 1,     tl + 1, cy + 1);
        dc.drawLine(w - tl - 1, cy + 1, w - te - 1, cy + 1);

        // Haupt-Tick (Flux-Blau)
        dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx, te,     cx, tl);
        dc.drawLine(cx, h - tl, cx, h - te);
        dc.drawLine(te, cy,     tl, cy);
        dc.drawLine(w - tl, cy, w - te, cy);

        // Spekularhighlight (weißblau, nur nahe der Außenkante)
        dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx, te, cx, tm);
        dc.drawLine(cx, h - tm, cx, h - te);
        dc.drawLine(te, cy, tm, cy);
        dc.drawLine(w - tm, cy, w - te, cy);

        // ── Nebenstriche — zweifarbig ─────────────────────────────────────────
        var r1 = r - w * 2 / 100;    // Außen (im Bezel-Körper)
        var r2 = r - w * 7 / 100;    // Innen (Zifferblatt)
        var rm = r - w * 45 / 1000;  // Übergang zwischen dim/bright

        for (var angle = 30; angle < 360; angle += 30) {
            if (angle == 90 || angle == 180 || angle == 270 || angle == 0) { continue; }
            var rad  = angle * 0.01745329f;
            var sinA = Math.sin(rad).toFloat();
            var cosA = Math.cos(rad).toFloat();

            // Äußerer Teil (im Bezel, gedimmt)
            dc.setColor(0x18182A, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(
                cx + (r1 * sinA).toNumber(), cy - (r1 * cosA).toNumber(),
                cx + (rm * sinA).toNumber(), cy - (rm * cosA).toNumber()
            );
            // Innerer Teil (sichtbar, heller)
            dc.setColor(C_LABEL, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(
                cx + (rm * sinA).toNumber(), cy - (rm * cosA).toNumber(),
                cx + (r2 * sinA).toNumber(), cy - (r2 * cosA).toNumber()
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  FLUX CAPACITOR (Y-shape) — sizes scale with armLen
    // ─────────────────────────────────────────────────────────────────────────
    function drawFluxCapacitor(dc as Dc, cx as Number, cy as Number, armLen as Number) as Void {
        var dotR  = mathMax(4, armLen / 8);
        var ctrR  = mathMax(3, armLen / 10);
        var glowW = mathMax(5, armLen / 9);
        var coreW = mathMax(2, armLen / 18);

        var endX = new Array<Number>[3];
        var endY = new Array<Number>[3];
        var angles = [0, 120, 240] as Array<Number>;

        for (var i = 0; i < 3; i++) {
            var rad  = angles[i] * 0.01745329f;
            endX[i]  = cx + (armLen * Math.sin(rad).toFloat()).toNumber();
            endY[i]  = cy - (armLen * Math.cos(rad).toFloat()).toNumber();
        }

        // Äußerster Deep-Space-Glow (sehr breit, sehr dunkel — Energiefeld)
        dc.setColor(0x001020, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(glowW * 3);
        for (var i = 0; i < 3; i++) { dc.drawLine(cx, cy, endX[i], endY[i]); }

        // Mittlerer Glow-Halo
        dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(glowW);
        for (var i = 0; i < 3; i++) { dc.drawLine(cx, cy, endX[i], endY[i]); }

        // Kern-Linie (Flux-Blau)
        dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(coreW);
        for (var i = 0; i < 3; i++) { dc.drawLine(cx, cy, endX[i], endY[i]); }

        // Weißglühender Hochglanz-Kern
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(mathMax(1, coreW / 2));
        for (var i = 0; i < 3; i++) { dc.drawLine(cx, cy, endX[i], endY[i]); }

        // Endpoint dots: glow → amber → white hot
        dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) { dc.fillCircle(endX[i], endY[i], dotR + 3); }
        dc.setColor(C_AMBER, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) { dc.fillCircle(endX[i], endY[i], dotR); }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) { dc.fillCircle(endX[i], endY[i], mathMax(1, dotR / 3)); }

        // Center junction
        dc.setColor(C_FLUX_DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ctrR + 3);
        dc.setColor(C_FLUX, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ctrR);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, mathMax(1, ctrR / 2));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  INFO STRIP  (Date | HR | Battery) — compact, bottom of screen
    // ─────────────────────────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    //  INFO STRIP  (HR | Battery) — Datum ist separat oberhalb
    // ─────────────────────────────────────────────────────────────────────────
    function drawInfoStrip(dc as Dc, cx as Number, w as Number, y as Number,
                           tinyH as Number, lg as Boolean) as Void {
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

        var heartIconW = lg ? 24 : 18;
        var gap        = w * 3 / 100;
        var batBarW    = w * 5 / 100;
        var bpmStr     = hrVal + " bpm";
        var batStr     = batPct.format("%d") + "%";

        var bpmW    = (dc.getTextDimensions(bpmStr, Graphics.FONT_XTINY))[0] as Number;
        var batStrW = (dc.getTextDimensions(batStr,  Graphics.FONT_XTINY))[0] as Number;
        var totalW  = heartIconW + 2 + bpmW + gap + batBarW + 4 + gap + batStrW;
        var x       = cx - totalW / 2;

        // Heart icon + bpm
        var hIcon = (lg && mHeartIconLg != null) ? mHeartIconLg : mHeartIcon;
        if (hIcon != null) { dc.drawBitmap(x, y + 1, hIcon as BitmapResource); }
        x += heartIconW + 2;
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
        dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, batStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  SLEEP SCREEN (AOD)  — small Y above, time below center
    // ─────────────────────────────────────────────────────────────────────────
    function drawSleepScreen(dc as Dc, w as Number, h as Number, cx as Number) as Void {
        dc.setColor(C_BG, C_BG);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeStr   = buildTimeString(clockTime);
        var yTime     = h * 58 / 100;

        // Glow + time
        dc.setColor(0x001133, Graphics.COLOR_TRANSPARENT);
        for (var dx = -1; dx <= 1; dx++) {
            for (var dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0) { continue; }
                dc.drawText(cx + dx, yTime + dy, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        var aodFill = (mAodColor == 1) ? 0xFFFFFF : C_FLUX;
        dc.setColor(aodFill, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yTime, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Small Y above time
        drawFluxCapacitor(dc, cx, h * 32 / 100, w * 10 / 100);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  SLOT DATA
    //  Returns [valueStr, labelStr] or [valueStr, labelStr, goalColor]
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
                var cm = act.distance as Number;
                if (mDistUnit == 1) {
                    distStr = (cm / 160934.0f).format("%.2f");
                } else {
                    distStr = (cm / 100000.0f).format("%.2f");
                }
            }
            return [distStr, (mDistUnit == 1) ? "MI" : "KM"] as Array;
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
        if (condition == Weather.CONDITION_PARTLY_CLOUDY) { return "Cloudy"; }
        if (condition == Weather.CONDITION_CLOUDY)        { return "Overcast"; }
        if (condition == Weather.CONDITION_RAIN)          { return "Rain"; }
        if (condition == Weather.CONDITION_SNOW)          { return "Snow"; }
        if (condition == Weather.CONDITION_FOG)           { return "Fog"; }
        if ((Weather has :CONDITION_THUNDERSTORM) && condition == Weather.CONDITION_THUNDERSTORM) { return "Storm"; }
        return "---";
    }

    function mathMax(a as Number, b as Number) as Number {
        return (a > b) ? a : b;
    }

    function onEnterSleep() as Void { mSleeping = true;  WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { mSleeping = false; WatchUi.requestUpdate(); }
}
