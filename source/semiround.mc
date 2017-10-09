using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.UserProfile as UserProfile;


//! @author Indrik myneur -  Many thanks to Roelof Koelewijn for a hr gauge code
class RunningTrends extends App.AppBase {
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

    // metrics
    hidden var avgPace = 0;
    hidden var lapAvgPace = 0;
    hidden var lastLapStartTimer = 0;
    hidden var lastLapStartDistance = 0;
    hidden var currentPace = 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;

    // heart rate zones
    var zoneMaxLimits = [113, 139, 155, 165, 174, 200];
    hidden var zoneColor = [
        Graphics.COLOR_TRANSPARENT,
        Graphics.COLOR_LT_GRAY,
        Graphics.COLOR_BLUE,
        Graphics.COLOR_GREEN,
        Graphics.COLOR_ORANGE,
        Graphics.COLOR_RED,
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
        }
    }

    function onLayout(dc) {
        setColors();
        onUpdate(dc);
    }

    function onUpdate(dc) {
        dc.setColor(backgroundColor, backgroundColor);
        dc.clear();

        drawPaceDiff(dc, 105, 65, 50);
        drawPaceChart(dc, 15, 65, 50);
        drawZoneBarsArcs(dc);

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
        var label_font = Graphics.FONT_XTINY;
        var value_font = Graphics.FONT_NUMBER_HOT;
        dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(195, 58, label_font, lapPaceStr, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(107 + dc.getTextWidthInPixels(presentedDistance, value_font) >> 1 + 5, 39, label_font, distanceString, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawValues(dc, presentedDistance) {
        var value_font = Graphics.FONT_NUMBER_HOT;

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(197, 67, value_font, displayPace(lapAvgPace), Graphics.TEXT_JUSTIFY_RIGHT);

        dc.drawText(107, 5, value_font, presentedDistance, Graphics.TEXT_JUSTIFY_CENTER);
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
        dc.drawText(107, 120, value_font, d, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawPaceDiff(dc, x, y, height) {
        if (currentPace <= 0) {
            dc.fillRectangle(x, y + height >> 1, 8, 8);
        } else {
            var pitch = 10;
            var step = -1;

            // how many times does current pace differ by 15s (1/4 min) from the average pace?
            var diff = (currentPace - lapAvgPace) / 15;
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

    function drawPaceChart(dc, x, y, height) {
        var h;
        var i;
        y += height;

        // max pace for chart scale
        var max = paceChartData.max();
        var min = paceChartData.min();
        if (max == null || max <= 0) {
            return;
        }

        max = max < lapAvgPace ? lapAvgPace : max;
        min = min > lapAvgPace ? lapAvgPace : min;
        max = max < avgPace ? avgPace : max;
        min = min > avgPace ? avgPace : min;

        if (min == max) { // all the numbers are the same
            dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y - height / 2, x + 90, y - height / 2);
            return;
        }
        var scale = height.toFloat() / (max - min);
        dc.setPenWidth(1);
        dc.setColor(lightColor, Graphics.COLOR_TRANSPARENT);
        if (scale > 1) { // do not zoom-in the diffe without limit
            scale = 1;
        }
        // avg pace
        var yL;
        var baseline = height / 2;
        if (max - min < height) {
            if (baseline + max - avgPace > height) {
                baseline = height - (max - avgPace);
            } else if (baseline - (avgPace - min) < 0) {
                baseline = avgPace - min;
            }
        } else {
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
        // current pace bar
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);

        // pace history bar chart
        i = 0;
        var pace = lapAvgPace;
        while (pace) {
            h = ((pace - avgPace) * scale).toNumber();
            if (h > 0) {
                dc.fillRectangle(x + 75 - i * 15, y - baseline - h, 13, h); // last laps paces
            } else {
                dc.fillRectangle(x + 75 - i * 15, y - baseline, 13, -h); // last laps paces
            }
            pace = paceChartData.prev(i);
            i++;
        }
        // avg pace line
        dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y - baseline, x + 90, y - baseline);
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
    function drawZoneBarsArcs(dc) {
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
