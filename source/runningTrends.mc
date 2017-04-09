using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
//using Toybox.Math as Math;
//using Toybox.ActivityRecording as Activity;

//! @author Indrik myneur -  Many thanks to Roelof Koelewijn for a hr gauge code
class RunningTrends extends App.AppBase {

    function getInitialView() {
        var view = new RunningTrendsView();
        return [ view ];
    }
}

//! skeleton by @author Konrad Paumann, HeartRateZones by @author Roelof Koelewijn
//! design, charts and layout by Indrik myneur
class RunningTrendsView extends Ui.DataField {

    hidden const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden const LEFT = Graphics.TEXT_JUSTIFY_LEFT;
    hidden const LABEL_FONT = Graphics.FONT_XTINY;
    hidden const VALUE_FONT = Graphics.FONT_NUMBER_MEDIUM;
    hidden var fontBigNumbers = VALUE_FONT;
    hidden var fontMidNumbers = VALUE_FONT;

    hidden const ZERO_TIME = "0:00";
    hidden const ZERO_DISTANCE = "0.00";
    hidden const ZERO_HR = "-";
    //hidden var paceStr, avgPaceStr, hrStr, distanceStr, durationStr;

    hidden const PACE_BAR_WIDTH = 13;
    hidden const PACE_BAR_PITCH = 15;
    
    hidden var kmOrMileInMeters = 1000;
    hidden var kmOrMileStr = "km";
    hidden var distanceUnits = System.UNIT_METRIC;

    //hidden var inverseBackgroundColor = Graphics.COLOR_BLACK;
    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var inverseTextColor = Graphics.COLOR_WHITE;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var darkColor = Graphics.COLOR_DK_GRAY;
    hidden var lightColor = Graphics.COLOR_LT_GRAY;
    hidden var hasBackgroundColorOption = false;
    
    // data for charts and averages
    hidden var paceChartData = new DataQueue(5);
    hidden var hrChartData = new DataQueue(60);
    hidden var lastHrData = new DataQueue(30);
    //hidden var lastLapPace = new DataQueue(10); // averaging pace

    // metrics
    hidden var avgSpeed = 0;
    hidden var lapAvgSpeed = 0;
    hidden var lastLapStartTimer = 0;
    hidden var lastLapStartDistance = 0;
    hidden var currentSpeed = 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;

    // heart rate zones
    hidden var zoneId = 0;
    hidden var maxHr = 200;
    hidden var zoneLowerBound = [113, 139, 155, 165, 174];
    hidden var zoneColor = [Graphics.COLOR_TRANSPARENT, Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLUE, Graphics.COLOR_GREEN, Graphics.COLOR_ORANGE, Graphics.COLOR_RED];
    
    hidden var width = 218;
    hidden var height = 218;
    hidden var centerX = 109;
    hidden var centerY = 109;
    //hidden var fontMiniText;
    
    function initialize() {
        // WTF! who the hell designd this idiotic language. It can not deal with nulls and can not even raise an exception, so it really must be as ugly as below ! 
        // WTF2!! if you want to run it in a simulator, comment out all next ifs of reading info from profile or it will run out of the memory! WTF! WTF!!!! WTF!!!!!!! Dafuq!!
        if(Application.getApp().getProperty("maxHr") != null) { maxHr = Application.getApp().getProperty("maxHr");}
        if(Application.getApp().getProperty("zone1") != null) { zoneLowerBound[0] = Application.getApp().getProperty("zone1");}
        if(Application.getApp().getProperty("zone2") != null) { zoneLowerBound[1] = Application.getApp().getProperty("zone2");}
        if(Application.getApp().getProperty("zone3") != null) { zoneLowerBound[2] = Application.getApp().getProperty("zone3");}
        if(Application.getApp().getProperty("zone4") != null) { zoneLowerBound[3] = Application.getApp().getProperty("zone4");}
        if(Application.getApp().getProperty("zone5") != null) { zoneLowerBound[4] = Application.getApp().getProperty("zone5");}
        setDeviceSettingsDependentVariables();
        DataField.initialize();
	}

    //! The given info object contains all the current workout
    function compute(info) {
        //lastLapPace.add(info.currentSpeed); // everaging speed, because Garmin's current speed is shitty on GPS inaccuracy 
        
        if(lastHrData.add(info.currentHeartRate)==0){   // when we filled full length of cirucular buffer
            hrChartData.add(lastHrData.average());
        }        
        avgSpeed = info.averageSpeed != null ? info.averageSpeed : 0;
        currentSpeed = info.currentSpeed != null ? info.currentSpeed : 0;
        elapsedTime = info.timerTime != null ? info.timerTime : 0;   
        hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
        distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
        //altitude = info.altitude != null ? info.altitude : 0;
        //cadence = info.currentCadence != null ? info.currentCadence : 0;
        if(lastLapStartTimer!=elapsedTime){
            lapAvgSpeed = (distance-lastLapStartDistance)/(elapsedTime-lastLapStartTimer)*1000;
        }
        if (hr != null) {
			zoneId = getZoneIdForHr(hr) - 1;
			/*if(zoneId >= 0){
				secondsInZone[zoneId] += 1;
			}*/
		}
	}
	
	function getZoneIdForHr(hr) {
		var i;	
		for (i = 0; i < zoneLowerBound.size() && hr > zoneLowerBound[i]; ++i) { }
		return i;
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
        onUpdate(dc);
    }
    
    function onUpdate(dc) {
        setColors();
        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle(0, 0, width, height);
        
        drawValues(dc);
    }

    function onTimerLap(){
        paceChartData.add(lapAvgSpeed);
        lastLapStartTimer = elapsedTime;    
        lastLapStartDistance = distance;
    }

    function setDeviceSettingsDependentVariables() {
        hasBackgroundColorOption = (self has :getBackgroundColor);
        
        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits != System.UNIT_METRIC) {
            kmOrMileInMeters = 1610;
            kmOrMileStr = "mi";
        }
        //is24Hour = System.getDeviceSettings().is24Hour;
        
        /*paceStr = Ui.loadResource(Rez.Strings.pace);
        avgPaceStr = Ui.loadResource(Rez.Strings.avgpace);
        hrStr = Ui.loadResource(Rez.Strings.hr);
        distanceStr = Ui.loadResource(Rez.Strings.distance);
        durationStr = Ui.loadResource(Rez.Strings.duration);*/
    }
    
    function setColors() {
        if (hasBackgroundColorOption) {
            backgroundColor = getBackgroundColor();
            textColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            inverseTextColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_WHITE;
            //inverseBackgroundColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_DK_GRAY: Graphics.COLOR_BLACK;
            darkColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY: Graphics.COLOR_DK_GRAY;
            lightColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_DK_GRAY: Graphics.COLOR_LT_GRAY;
        }
    }
        
    function drawValues(dc) {
        
        //hr
        drawHrChart(dc, 10, centerY-51, 50);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width-55, centerY-31, fontBigNumbers, hr>0 ? hr.format("%d") : ZERO_HR, CENTER); 
        
        //pace
        dc.drawText(width-55, centerY+30, fontBigNumbers, getMinutesPerKmOrMile(lapAvgSpeed), CENTER);
            
        drawPaceDiff(dc, 115, centerY+1, 50);
        drawPaceChart(dc, 20, centerY+1, 50);
        
        dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
        //dc.drawText(width-55, centerY+2, LABEL_FONT, "pace " + getMinutesPerKmOrMile(currentSpeed) , CENTER);
        dc.drawText(width-55, centerY+2, LABEL_FONT, "lap pace"  , CENTER);

        
        if(height>200){

            //distance
            var distStr;
            if (distance > 0) {
                var distanceKmOrMiles = distance / kmOrMileInMeters;
                distStr = (distanceKmOrMiles < 100) ? distanceKmOrMiles.format("%.2f") : distanceKmOrMiles.format("%.1f");
            } else {
                distStr = ZERO_DISTANCE;
            }

            dc.drawText(centerX + dc.getTextWidthInPixels(distStr, fontMidNumbers)>>1+5, 40, LABEL_FONT, kmOrMileStr, LEFT);
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX , 33, fontMidNumbers, distStr, CENTER);
            
            //duration
            var duration;
            if (elapsedTime != null && elapsedTime > 0) {
                var hours = null;
                var minutes = elapsedTime / 1000 / 60;
                var seconds = elapsedTime / 1000 % 60;
                
                if (minutes >= 60) {
                    hours = minutes / 60;
                    minutes = minutes % 60;
                }
                
                if (hours == null) {
                    duration = minutes.format("%d") + ":" + seconds.format("%02d");
                } else {
                    duration = hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
                }
            } else {
                duration = ZERO_TIME;
            } 
            dc.drawText(centerX, height-33, fontMidNumbers, duration, CENTER);
        
            // hr zone arcs
    		var zone = drawZoneBarsArcs(dc, centerY+1, centerX, centerY, hr); //radius, center x, center y
        }

    }

    function drawPaceDiff(dc, x, y, height){
        if(lapAvgSpeed != null){
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            if(currentSpeed<.2){
                dc.fillRectangle(x, y+height>>1, 8, 8);
            } else if((currentSpeed-lapAvgSpeed).abs()>0){
                var pitch = 10; var step = -1;
                var avg = lapAvgSpeed>0 ? kmOrMileInMeters/lapAvgSpeed : 0.0;
                
                // how many times does current pace differ by 15s (1/4 min) from the average pace? 
                var diff = (kmOrMileInMeters/currentSpeed-avg)/15;
                if(diff<0){ // slower than average = avg pace < pace
                    y += height -8;
                    step = -step;
                    pitch = -pitch;
                    dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
                } else {
                    y +=8;
                }

                var i = diff.abs();
                if(i>3){i=3;}
                if(i>0.2){
                    while(i>0){    
                        dc.fillPolygon([[x,y],[x+8, y],[x+4,y+8*step]]);
                        y+=pitch;
                        i--;
                    }
                }
                return diff;
            }
        }
        return 0;
    }

    function drawPaceChart(dc, x, y, height){
        var data = paceChartData.getData();
        var position = paceChartData.lastPosition(); var max = data.size();
        var h; var i; 
        var lapAvgPace = getPace(lapAvgSpeed);
        y += height;
        
        // max pace for chart scale
        var maxPace = lapAvgPace;
        for(i = 0; i < data.size(); i++){   // find max space in array with speeds
            if(data[i]!=null){
                if(data[i]!=0){
                    h = getPace(data[i]);
                    if(maxPace == null || h>maxPace){ 
                        maxPace = h;
                    }
                }
            }
        }
        var avgPace = getPace(avgSpeed);
        if(avgPace>maxPace){ maxPace=avgPace;}
        
        if(maxPace>0){
            // avg pace line
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT); 
            h = (avgPace/maxPace*height).toNumber();
            dc.setPenWidth(1);
            dc.drawLine(x, y-h, x+PACE_BAR_PITCH*6, y-h);
            // current pace bar
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT); 
            h = (lapAvgPace/maxPace*height).toNumber();
            dc.fillRectangle(x+5*PACE_BAR_PITCH, y-h, PACE_BAR_WIDTH, h);   // current lap pace
            // pace history bar chart
            var speed = 0;
            for(i = max-1; i>=0; i--){
                speed = data[position];
                if(speed != null){
                    if(maxPace > 0){
                        h = (getPace(speed)/maxPace*height).toNumber();
                        dc.fillRectangle(x+i*PACE_BAR_PITCH, y-h, PACE_BAR_WIDTH, h);   // last laps paces
                    } 
                }
                position--;
                if(position<0){
                    position = max-1;
                }
            }
        }
    }

    function drawHrChart(dc, x, y, height){        
        // chart alignment and crop
        var maxHr = hrChartData.max(); 
        if(maxHr != null){  // no data, no chart
            var h; var offset=50; var last = null;
            y += height; // y should be at top

            var minHr = hrChartData.min();
            h = lastHrData.average();
            
            if(h==null){h=0;} 
            if(h<minHr){ minHr = h;}
            if(h>maxHr){ maxHr = h;}

            // scale
            maxHr = maxHr.toNumber() >> 1;
            minHr = minHr.toNumber() >> 1;
            h = h.toNumber() >> 1;
        
            // cut offset which will not fit into an area
            if(maxHr-minHr>height){
                offset = maxHr-height; // put max to the top of the chart
                if(h<offset && h>0){
                    offset = h-10; // make sure current hr is shown
                }
            } else {
                offset = (((minHr+maxHr)-height)/2).toNumber(); // put it in the middle of the chart
            }          
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);

            // draw hr history
            var data = hrChartData.getData();
            var position = hrChartData.lastPosition(); var size = data.size();
            var colorLineStart; var colorLineEnd; var midPoint = null;

            // set current hr to be drawn and draw it            
            if(h > 0){
                dc.drawPoint(x+size*2, y-h+offset);
                last = h;
            }

            for(var i = size-1; i>=0; i--){
                h = data[position];
                if(h != null){
                    h = h.toNumber() >> 1;

                    // line can have two colors if it crossses a chart boundary
                    colorLineStart = (h>=offset && h<= offset+height) ? Graphics.COLOR_DK_RED : lightColor; 
                    dc.setColor(colorLineStart, Graphics.COLOR_TRANSPARENT);
                    if(last != null){
                        colorLineEnd = (last >= offset && last <= offset+height) ? Graphics.COLOR_DK_RED : lightColor;  
                        
                        // when line crosses boundary
                        if(colorLineStart != colorLineEnd){
                            if(colorLineStart == Graphics.COLOR_DK_RED){   // h (left value) is within boundaries
                                midPoint = (last<offset) ? y : y-height;  
                                dc.setColor(colorLineEnd, Graphics.COLOR_TRANSPARENT);
                                dc.drawLine(x+i*2+1, midPoint, x+i*2+2, y-last+offset); 
                                dc.setColor(colorLineStart, Graphics.COLOR_TRANSPARENT);
                                dc.drawLine(x+i*2, y-h+offset, x+i*2+1, midPoint);  
                            } else {    // h (left value) is out of boundaries
                                midPoint = (h<offset) ? y : y-height;
                                dc.setColor(colorLineStart, Graphics.COLOR_TRANSPARENT);
                                dc.drawLine(x+i*2, y-h+offset, x+i*2+1, midPoint); 
                                dc.setColor(colorLineEnd, Graphics.COLOR_TRANSPARENT);
                                dc.drawLine(x+i*2+1, midPoint, x+i*2+2, y-last+offset);  
                            }
                        } else {
                            dc.drawLine(x+i*2, y-h+offset, x+i*2+2, y-last+offset);    
                        }
                    } else {
                        dc.drawPoint(x+i*2, y-h+offset);
                    }
                }
                last = h; // value to continue from in the next iteration
                position--;
                if(position<0){
                    position = size-1;
                }
            }
        }
    }
    
    function getMinutesPerKmOrMile(speedMetersPerSecond) {
        if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
            var metersPerMinute = speedMetersPerSecond * 60.0;
            var minutesPerKmOrMilesDecimal = kmOrMileInMeters / metersPerMinute;
            var minutesPerKmOrMilesFloor = minutesPerKmOrMilesDecimal.toNumber();
            var seconds = (minutesPerKmOrMilesDecimal - minutesPerKmOrMilesFloor) * 60;
            return minutesPerKmOrMilesDecimal.format("%2d") + ":" + seconds.format("%02d");
        }
        return ZERO_TIME;
    }

    function getPace(speed) {
        if (speed != null && speed > 0.2) {
            return kmOrMileInMeters / speed;
        } 
        return 0;
    }
    
    //! @author Roelof Koelewijn
	function drawZoneBarsArcs(dc, radius, centerX, centerY, hr){
        var degrees = [[0,0],[220, 166],[166, 112],[112, 58],[58, 4],[4, 320]];
        dc.setPenWidth(8);
		
		var i;	
		for (i = 0; i < zoneLowerBound.size() && hr >= zoneLowerBound[i]; ++i) { }
        var zonedegree = 58 / (zoneLowerBound[1] - zoneLowerBound[0]);
		if(i >= 0){
            dc.setColor(zoneColor[i], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(centerX, centerY, radius - 4, 1, degrees[i][0], degrees[i][1]);	
		}
		
		if(hr >= zoneLowerBound[0] && hr < zoneLowerBound[1]){
			zonedegree = (58 / (zoneLowerBound[1] - zoneLowerBound[0])) * (zoneLowerBound[1]-hr);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 166 + zonedegree - 3, 166 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 166 + zonedegree - 2, 166 + zonedegree);
		}else if(hr >= zoneLowerBound[1] && hr < zoneLowerBound[2]){
			zonedegree = (58 / (zoneLowerBound[2] - zoneLowerBound[1])) * (zoneLowerBound[2]-hr);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 112 + zonedegree - 3, 112 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 112 + zonedegree -2, 112 + zonedegree);
		}else if(hr >= zoneLowerBound[2] && hr < zoneLowerBound[3]){
			zonedegree = (58 / (zoneLowerBound[3] - zoneLowerBound[2])) * (zoneLowerBound[3]-hr);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 58 + zonedegree - 3, 58 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 58 + zonedegree - 2, 58 + zonedegree);
		}else if(hr >= zoneLowerBound[3] && hr < zoneLowerBound[4]){
			zonedegree = (58 / (zoneLowerBound[4] - zoneLowerBound[3])) * (zoneLowerBound[4]-hr);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 4 + zonedegree - 3, 4 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 4 + zonedegree - 2, 4 + zonedegree);
		}else if(hr >= zoneLowerBound[4] && hr < maxHr){
			zonedegree = (58 / (maxHr - zoneLowerBound[4])) * (maxHr-hr);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			if((320 + zonedegree) < 360){
				dc.drawArc(centerX, centerY, radius - 8, 0, 320 + zonedegree - 3, 320 + zonedegree + 1);
			}else{
				dc.drawArc(centerX, centerY, radius - 8, 0, -50 + zonedegree - 3 , -50 + zonedegree + 1);
			}
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			if((320 + zonedegree) < 360){
				dc.drawArc(centerX, centerY, radius - 8, 0, 320 + zonedegree - 2, 320 + zonedegree);
			}else{
				dc.drawArc(centerX, centerY, radius - 8, 0, -50 + zonedegree -2 , -50 + zonedegree);
			}
		}
		
		return i;
	}
}

//! A circular queue core by @author Konrad Paumann, math methods by Indrik myneur
class DataQueue {

    //! the data array.
    hidden var data;
    hidden var maxSize = 0;
    hidden var pos = 0;

    //! precondition: size has to be >= 2
    function initialize(arraySize) {
        data = new[arraySize];
        maxSize = arraySize;
    }
    
    //! Add an element to the queue.
    function add(element) {
        data[pos] = element;
        pos = (pos + 1) % maxSize;
        return pos;
    }

    function average(){
        var sum = 0;
        var size = 0;
        for(var i = 0; i < data.size(); i++){
            if(data[i] != null){
                sum = sum + data[i];
                size++;
            }
        }
        if(size == 0) {
            return null;
        } else {
            return (sum.toFloat()/size.toFloat());
        }
    }
    
    //! Reset the queue to its initial state.
    function reset() {
        for (var i = 0; i < data.size(); i++) {
            data[i] = null;
        }
        pos = 0;
    }

    function max(){
        var max = null;
        for(var i = 0; i < data.size(); i++){
            if(data[i] != null){
                if(max == null || data[i]>max){ 
                    max = data[i];
                }
            }
        }
        return max;
    }

    function min(){
        var min = null;
        for(var i = 0; i < data.size(); i++){
            if(data[i] != null){
                if(min == null || data[i]<min){ 
                    min = data[i];
                }
            }
        }
        return min;
    }
    
    //! Get the underlying data array.
    function getData() {
        return data;
    }

    function lastPosition(){
        var i = pos-1;
        return i<0 ? maxSize-1 : i;
    }

}