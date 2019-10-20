using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.UserProfile as UserProfile;

//! @author Indrik myneur -  Many thanks to Roelof Koelewijn for a hr gauge code
class RunningTrends extends App.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new RunningTrendsView()];
    }
}

//! skeleton by @author Konrad Paumann, HeartRateZones by @author Roelof Koelewijn
//! design, charts and layout by Indrik myneur
class RunningTrendsView extends Ui.DataField {
    hidden var referenceDistance = 1000;
    hidden var distanceString = "km";
    hidden var lapPaceStr;
    hidden var distanceUnits = System.UNIT_METRIC;
    hidden var showLapMetrics = false;

    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var darkColor = Graphics.COLOR_DK_GRAY;
    hidden var lightColor = Graphics.COLOR_LT_GRAY;

    // data for charts and averages
    hidden var paceChartData = new DataQueue(5);
    hidden var hrChartData = new DataQueue(60);
    hidden var lastHrData = new DataQueue(30);

    // metrics
    hidden var avgPace = 0;
    hidden var lapAvgPace = 0;
    hidden var lastLapStartTimer = 0;
    hidden var lastLapStartDistance = 0;
    hidden var currentPace = 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;

    // layout
    hidden var width;
    hidden var height;
    hidden var centerX;
    hidden var centerY;
    hidden var fourthY;
    hidden var topChartY;
    hidden var bottomChartY;
    hidden var value_font = Graphics.FONT_NUMBER_MEDIUM;
    hidden var label_font = Graphics.FONT_XTINY;

    // heart rate zones
    hidden var zoneMaxLimits = [113, 139, 155, 165, 174, 200];

    hidden var zoneColor = [
        Graphics.COLOR_TRANSPARENT,
        Graphics.COLOR_LT_GRAY,
        Graphics.COLOR_BLUE,
        Graphics.COLOR_GREEN,
        Graphics.COLOR_ORANGE,
        Graphics.COLOR_DK_RED,
        Graphics.COLOR_RED
    ];

    function initialize() {
        DataField.initialize();

        if (Application.getApp().getProperty("showLapMetrics") != null) {
            showLapMetrics = Application.getApp().getProperty("showLapMetrics");
        }
        setDeviceSettingsDependentVariables();
    }

    //! The given info object contains all the current workout
    function compute(info) {
        if (lastHrData.add(info.currentHeartRate) == 0) { // when we filled full length of cirucular buffer
            hrChartData.add(lastHrData.average());
        }

        var avgSpeed = info.averageSpeed ? info.averageSpeed : 0;
        var currentSpeed = info.currentSpeed ? info.currentSpeed : 0;

        elapsedTime = info.timerTime ? info.timerTime : 0;
        hr = info.currentHeartRate ? info.currentHeartRate : 0;
        distance = info.elapsedDistance ? info.elapsedDistance : 0;

        if (avgSpeed == 0) {
            avgPace = 0;
        } else {
            avgPace = (referenceDistance / avgSpeed).toNumber();
        }
        if (currentSpeed == 0) {
            avgSpeed = 0;
        } else {
            currentPace = (referenceDistance / currentSpeed).toNumber();
        }

        if (distance != lastLapStartDistance) {
            lapAvgPace = (elapsedTime - lastLapStartTimer) * referenceDistance / 1000 / (distance - lastLapStartDistance);
            lapAvgPace = lapAvgPace.toNumber();
        } else {
            if(distance>0){
                lapAvgPace = (elapsedTime ) * referenceDistance / 1000 / (distance );
            }
        }
    }

    function onLayout(dc) {
        // WTF! If I load the fonts it runs out of memory!
        //fontMidNumbers = Ui.loadResource(Rez.Fonts.MidNumbers);
        //fontBigNumbers = Ui.loadResource(Rez.Fonts.BigNumbers);
        //fontMiniText = Ui.loadResource(Rez.Fonts.MiniText);
        
        width = dc.getWidth();
        height = dc.getHeight();
        centerX = width>>1;
        centerY = height>>1;
        
        fourthY = centerY>>2 +5;
        topChartY = fourthY + (dc.getFontAscent(value_font) - dc.getFontDescent(value_font))>>1 + 5; // fixing the inconsistency of fontHeights; some heights are exact some with padding
        bottomChartY = (centerY - topChartY - 50)>>1 + centerY;

        setColors();
        onUpdate(dc);
    }

    function onUpdate(dc) {

        dc.setColor(backgroundColor, backgroundColor);
        dc.clear();
        drawHrChart(dc, centerX, topChartY - 1, centerY-topChartY);
        drawPaceDiff(dc, 115, bottomChartY , 50);
        drawPaceChart(dc, 20, bottomChartY, 50);
        drawZoneBarsArcs(dc, centerY, centerX, centerY, hr);

        //distance
        var d = showLapMetrics ? distance - lastLapStartDistance : distance;
        if (d < 0) {
            d = 0;
        }
        var presentedDistanceValue = d / referenceDistance;
        d = (presentedDistanceValue < 100) ? presentedDistanceValue.format("%.2f") : presentedDistanceValue.format("%.1f");

        drawValues(dc, d);
        drawLabels(dc, d);
    }

    function onTimerLap() {
        paceChartData.add(lapAvgPace);
        lastLapStartTimer = elapsedTime;
        lastLapStartDistance = distance;
    }

    function setDeviceSettingsDependentVariables() {
        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits != System.UNIT_METRIC) {
            referenceDistance = 1610;
            distanceString = "mi";
        } else {
            referenceDistance = 1000;
            distanceString = "km";
        }
        lapPaceStr = Ui.loadResource(Rez.Strings.lapPace);
        if (UserProfile has :getHeartRateZones) {
            zoneMaxLimits = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_RUNNING);
            zoneMaxLimits[0] = zoneMaxLimits[0] - 1; // Garmin returns first limit as zone 1 start, so normalizing to make it comparable
        }
    }

    function setColors() {
        backgroundColor = getBackgroundColor();
        if (backgroundColor == Graphics.COLOR_BLACK) {
            textColor = Graphics.COLOR_WHITE;
            darkColor = Graphics.COLOR_LT_GRAY;
            lightColor = Graphics.COLOR_DK_GRAY;
        } else {
            textColor = Graphics.COLOR_BLACK;
            darkColor = Graphics.COLOR_DK_GRAY;
            lightColor = Graphics.COLOR_LT_GRAY;
        }
    }

    function drawLabels(dc, presentedDistance) {
        var centerOs = 2;

        //if (dc.getFontDescent(value_font) == 7) {centerOs = -4;}  // TODO fix text top padding for older watch: this tells how the gap is big

        dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);

        dc.drawText(width - 23, centerY + centerOs, label_font, lapPaceStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        if(height>200){
            dc.drawText(width / 2 + dc.getTextWidthInPixels(presentedDistance, value_font) >> 1 + 5, 40, label_font, distanceString, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawValues(dc, presentedDistance) {
        
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        var displayHr = hr > 0 ? hr.format("%d") : "-";
        dc.drawText(width - 23, centerY - fourthY, value_font, displayHr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width - 23, centerY + fourthY, value_font, displayPace(lapAvgPace), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        //if(height>200){
            dc.drawText(centerX, fourthY, value_font, presentedDistance, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            //duration
            var d = showLapMetrics ? elapsedTime - lastLapStartTimer : elapsedTime;

            var seconds = d / 1000;
            var minutes = seconds / 60;
            var hours = minutes / 60;
            seconds %= 60;
            minutes %= 60;

            if (hours > 0) {
                d = Lang.format("$1$:$2$:$3$", [hours, minutes.format("%02d"), seconds.format("%02i")]);
            } else {
                d = Lang.format("$1$:$2$", [minutes, seconds.format("%02i")]);
            }
            dc.drawText(centerX, height - fourthY, value_font, d, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        //}

    }

    function drawPaceDiff(dc, x, y, height) {
        if (currentPace <= 0) {
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y + height >> 1, 8, 8);
        } else {
            var pitch = 10;
            var step = -1;

            // how many times does current pace differ by 15s (1/4 min) from the average pace?
            var diff = (currentPace - lapAvgPace).toFloat() / 15;
            if (diff < 0) { // slower than average = avg pace < pace
                y += height - 8;
                step = -step;
                pitch = -pitch;
                diff = -diff;
                dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
            } else {
                y += 8;
                dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            }

            if (diff > 3) {
                diff = 3;
            }
            if(diff.abs()>0.2){
                while (diff > 0) {
                    dc.fillPolygon([
                        [x, y],
                        [x + 8, y],
                        [x + 4, y + 8 * step]
                    ]);
                    y += pitch;
                    diff--;
                }
            }
        }
    }

    function drawPaceChart(dc, x, y, height) {
        var h; var i;
        y += height;

        // max pace for chart scale
        var max = paceChartData.max();
        var min = paceChartData.min();
        if (max == null || max <= 0) {
            return;
        }
        if(max < lapAvgPace) { max =lapAvgPace;}
        if(min > lapAvgPace) { min = lapAvgPace;}
        if(max < avgPace) { max =avgPace;}
        if(min > avgPace) { min = avgPace;}

        // all the numbers are the same
        if (min == max) { 
            dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y - height>>1, x + 90, y - height>>1);
            return;
        }

        var scale = height.toFloat() / (max - min);
        if (scale > 1) { // do not zoom-in the diffe without limit
            scale = 1;
        }
        dc.setPenWidth(1);
        dc.setColor(lightColor, Graphics.COLOR_TRANSPARENT);

        // align chart and show scale lines
        var yL;
        var baseline = height>>1;
        if (max - min < height) {   // fits chart boundaries
            if (baseline + max - avgPace > height) {
                baseline = height - (max - avgPace);
            } else if (baseline - (avgPace - min) < 0) {
                baseline = avgPace - min;
            }
        } else {    // scaled down
            baseline = ((avgPace - min) * scale).toNumber();
            yL = (baseline + scale * height / 2).toNumber();
            if (yL < height) {
                dc.drawLine(x, y - yL, x + 90, y - yL);
            }
            yL = (baseline - scale * height / 2).toNumber();
            if (yL > 0) {
                if (yL > 0) {
                    dc.drawLine(x, y - yL, x + 90, y - yL);
                }
            }
        }

        // pace history bar chart
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        i = 0;
        var pace = lapAvgPace;
        while (pace != null) {  // TODO expect pace dropouts
            if(pace>0){
                h = ((pace - avgPace) * scale).toNumber();
                if (h > 0) {
                    dc.fillRectangle(x + 75 - i * 15, y - baseline - h, 13, h); // last laps paces
                } else {
                    dc.fillRectangle(x + 75 - i * 15, y - baseline, 13, -h); // last laps paces
                }
            }
            pace = paceChartData.prev(i);
            i++;
        }

        // avg pace line
        dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y - baseline, x + 90, y - baseline);
    }

    function drawHrChart(dc, x, y, height) {
        var maxHr = hrChartData.max();
        var h = lastHrData.average(); // the current value
        //System.println(maxHr+ " "+ h);
        /*if(h==null){
            h = hrChartData.first();
            System.println(h);
        }*/

        if (maxHr == null || h == null) {
            return;
        }
        h = h.toNumber();
        var minHr = hrChartData.min();
        
        if (maxHr < h) {
            maxHr = h;
        }
        if (minHr > h) {
            minHr = h;
        }
        var range = (maxHr - minHr).toNumber();

        // do not zoom-in
        if(range <= height){
            var padding = (height-range) / 2;
            maxHr += padding;
            minHr -= padding;
            range = height;
        } 
        var v = y + height - height*(h-minHr) / range;
        var i;
        var zoneY = new [zoneMaxLimits.size() + 1];
        var curRange = 0;
        for (i = 1; i < zoneMaxLimits.size(); i++) {
            zoneY[i] = y + height - height * (zoneMaxLimits[i] - minHr) / range;
            if (zoneY[i] > v) {
                curRange = i;
            }
        }
        zoneY[0] = 1000000;
        zoneY[zoneY.size() - 1] = 0;
        dc.setColor(zoneColor[curRange + 1], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawPoint(x, v);

        i = 0;
        h = hrChartData.prev(i);

        //System.println(maxHr+" "+ minHr+ " "+ h);
        var px = x;
        var pv = v;
        while (i<60) { // TODO expect hr dropouts
            x -= 2;
            if(h != null){
                v = y + height - height*(h-minHr) / range;
                if (v > pv) { // HR drops y goes up
                    while (v > zoneY[curRange] && curRange > 0) {
                        dc.drawLine(px, pv, x + 1, zoneY[curRange]);
                        px = x + 1;
                        pv = zoneY[curRange] + 1;
                        curRange--;
                        dc.setColor(zoneColor[curRange + 1], Graphics.COLOR_TRANSPARENT);
                    }
                } else if (v <= pv) { // HR goes up y drops
                    while (v <= zoneY[curRange + 1]) {
                        dc.drawLine(px, pv, x + 1, zoneY[curRange + 1]);
                        px = x + 1;
                        pv = zoneY[curRange + 1];
                        curRange++;
                        dc.setColor(zoneColor[curRange + 1], Graphics.COLOR_TRANSPARENT);
                    }
                }
                dc.drawLine(px, pv, x, v);
                px = x;
                pv = v;
                dc.drawPoint(x, v);
            }
            i += 1;
            h = hrChartData.prev(i);
        }
    }

    function displayPace(pace) {
        if (pace == null || pace == 0) {
            return "0:00";
        }
        var seconds = pace.toNumber();
        var minutes = seconds / 60;
        seconds %= 60;
        return Lang.format("$1$:$2$", [minutes, seconds.format("%02d")]);
    }

    //! @author Roelof Koelewijn
    function drawZoneBarsArcs(dc, radius, centerX, centerY, hr) {
        var i = 0;

        while (i < zoneMaxLimits.size() - 1 && hr > zoneMaxLimits[i]) {
            i++;
        }

        if (hr > zoneMaxLimits[i]) {
            hr = zoneMaxLimits[i];
        }
        var zonedegree = 0;
        var x = 107;
        if (i > 3) {
            x++;
        }
        if (i > 0) { // show zone arc
            dc.setColor(zoneColor[i], Graphics.COLOR_TRANSPARENT);
            if (i == 3) {
                dc.setPenWidth(8);
                dc.drawLine(52, 4, 215 - 52, 4);
                dc.setColor(backgroundColor, Graphics.COLOR_TRANSPARENT);
                zonedegree = (215 - 104) * (hr - zoneMaxLimits[2]) / (zoneMaxLimits[3] - zoneMaxLimits[2]);
                zonedegree = 52 + zonedegree;
                dc.drawLine(zonedegree, 12, zonedegree, 0);
                dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(4);
                dc.drawLine(zonedegree, 11, zonedegree, 0);
            } else {
                dc.setPenWidth(18);
                zonedegree = -60 * (hr - zoneMaxLimits[i - 1]) / (zoneMaxLimits[i] - zoneMaxLimits[i - 1]);
                var os = 300 - 60 * i;
                dc.drawArc(x, 90, 107, 1,os, os - 60);

                dc.setColor(backgroundColor, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(26);
                dc.drawArc(x, 90, 107, 0, os + zonedegree - 2, os + zonedegree + 2);
                dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(24);
                dc.drawArc(x, 90, 107, 0, os + zonedegree - 1, os + zonedegree + 1);
            }
        }
    }
}
