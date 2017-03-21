using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.Math as Math;

//! @author Roelof Koelewijn - Many thanks to Konrad Paumann for the code for the dataFields check out his awsome runningfields Datafield
class HeartRateRunner extends App.AppBase {

    function getInitialView() {
        var view = new HeartRateRunnerView();
        return [ view ];
    }
}

//! DataFields that shows some infos by @author Konrad Paumann
//!
//! HeartRateZones
//! @author Roelof Koelewijn
class HeartRateRunnerView extends Ui.DataField {

    hidden const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden const LEFT = Graphics.TEXT_JUSTIFY_LEFT;
    hidden const HEADER_FONT = Graphics.FONT_XTINY;
    hidden const VALUE_FONT = Graphics.FONT_NUMBER_MEDIUM;
    hidden const ZERO_TIME = "0:00";
    hidden const ZERO_DISTANCE = "0.00";
    
    hidden var kmOrMileInMeters = 1000;
    hidden var is24Hour = true;
    hidden var distanceUnits = System.UNIT_METRIC;
    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var inverseTextColor = Graphics.COLOR_WHITE;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var inverseBackgroundColor = Graphics.COLOR_BLACK;
    hidden var lineColor = Graphics.COLOR_RED;
    hidden var headerColor = Graphics.COLOR_DK_GRAY;
        
    hidden var paceStr, avgPaceStr, hrStr, distanceStr, durationStr;
    
    hidden var paceData = new DataQueue(5);
    //hidden var lastLapPace = new DataQueue(60);
    hidden var hrData = new DataQueue(60);
    hidden var hrLastData = new DataQueue(15);
    hidden var hrInterval = 10;
    hidden var avgSpeed = 0;
    hidden var currentSpeed = 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;
    hidden var zoneId = 0;
    hidden var secondsInZone = [0, 0, 0, 0, 0, 0];
    
    /* TODO debug return to profile reading when debugging done */
    //hidden var maxHr = Application.getApp().getProperty("maxHr");
    hidden var maxHr = 200;
	//hidden var zoneLowerBound = [Application.getApp().getProperty("zone1"), Application.getApp().getProperty("zone2"), Application.getApp().getProperty("zone3"), Application.getApp().getProperty("zone4"), Application.getApp().getProperty("zone5")];
    hidden var zoneLowerBound = [113, 139, 155, 165, 174];
    
    
    hidden var hasBackgroundColorOption = false;
    
    function initialize() {
        DataField.initialize();
	}

    //! The given info object contains all the current workout
    function compute(info) {
        if (info.currentSpeed != null) {
            paceData.add(info.currentSpeed);
        } else {
            paceData.reset();
        }
        if(hrLastData.add(info.currentHeartRate)==0){
            hrData.add(hrLastData.average());
        }
        
        
        avgSpeed = info.averageSpeed != null ? info.averageSpeed : 0;
        currentSpeed = info.currentSpeed != null ? info.currentSpeed : 0;
        elapsedTime = info.elapsedTime != null ? info.elapsedTime : 0;        
        hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
        distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
	    if (hr != null) {
			zoneId = getZoneIdForHr(hr) - 1;
			if(zoneId >= 0){
				secondsInZone[zoneId] += 1;
			}
		}
	}
	
	function getZoneIdForHr(hr) {
		var i;	
		for (i = 0; i < zoneLowerBound.size() && hr > zoneLowerBound[i]; ++i) { }
		return i;
	}
    
    function onLayout(dc) {
        setDeviceSettingsDependentVariables();
        onUpdate(dc);
    }
    
    function onUpdate(dc) {
        setColors();
        var width = dc.getWidth();
    	var height = dc.getHeight();
        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle(0, 0, width, height);
        
        drawValues(dc);
    }

    function setDeviceSettingsDependentVariables() {
        hasBackgroundColorOption = (self has :getBackgroundColor);
        
        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits == System.UNIT_METRIC) {
            kmOrMileInMeters = 1000;
        } else {
            kmOrMileInMeters = 1610;
        }
        is24Hour = System.getDeviceSettings().is24Hour;
        
        paceStr = Ui.loadResource(Rez.Strings.pace);
        avgPaceStr = Ui.loadResource(Rez.Strings.avgpace);
        hrStr = Ui.loadResource(Rez.Strings.hr);
        distanceStr = Ui.loadResource(Rez.Strings.distance);
        durationStr = Ui.loadResource(Rez.Strings.duration);
    }
    
    function setColors() {
        if (hasBackgroundColorOption) {
            backgroundColor = getBackgroundColor();
            textColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            inverseTextColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_WHITE;
            inverseBackgroundColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_DK_GRAY: Graphics.COLOR_BLACK;
            lineColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLUE : Graphics.COLOR_RED;
            headerColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY: Graphics.COLOR_DK_GRAY;
        }
    }
        
    function drawValues(dc) {
        var width = dc.getWidth();
    	var height = dc.getHeight();       

        //hr
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(155, 85, VALUE_FONT, hr.format("%d"), CENTER); // debug
        drawHrChart(dc);
                
        //apace
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(60, 140, VALUE_FONT, getMinutesPerKmOrMile(avgSpeed), CENTER);
        drawPaceDiff(dc);
        
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        
        //distance
        var distStr;
        if (distance > 0) {
            var distanceKmOrMiles = distance / kmOrMileInMeters;
            if (distanceKmOrMiles < 100) {
                distStr = distanceKmOrMiles.format("%.2f");
            } else {
                distStr = distanceKmOrMiles.format("%.1f");
            }
        } else {
            distStr = ZERO_DISTANCE;
        }
        //dc.drawText(155 , 85, VALUE_FONT, distStr, CENTER);
        dc.drawText(109 , 30, VALUE_FONT, distStr, CENTER);
        
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
        dc.drawText(155, 140, VALUE_FONT, duration, CENTER);
        


        //Arcs
		var zone = drawZoneBarsArcs(dc, (height/2)+1, width/2, height/2, hr); //radius, center x, center y

		// headers:
        dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
        //dc.drawText(60, 60, HEADER_FONT, hrStr, CENTER);
        dc.drawText(70, 172, HEADER_FONT, avgPaceStr, CENTER);
        //dc.drawText(167, 60, HEADER_FONT, distanceStr, CENTER);
        dc.drawText(155, 172, HEADER_FONT, durationStr, CENTER);
        /*if(zone != 0){
        	dc.drawText(109, 25, HEADER_FONT, hrStr + " " + zone, CENTER);
        }*/
    }



    function drawPaceDiff(dc){
        if((currentSpeed-avgSpeed).abs()>0 ){
            var x = 95; var y = 125; // coordinates of the diff indicator
            var pitch = 10; 

            var current = currentSpeed>0 ? kmOrMileInMeters/currentSpeed : 0;
            var avg = avgSpeed>0 ? kmOrMileInMeters/avgSpeed : 0;
            // how many times do we differ by 15 s from the average pace? 
            var diff = ((current-avg)/15).toNumber();
            var step = 1;
            
            
            dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            if(diff>0){ // faster = avg pace > pace
                y += 40;
                step = -step;
                pitch = -pitch;
                dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            }

            var i = diff.abs();
            if(i>2){i=2;}
            
            
            while(i>=0){    
                dc.fillPolygon([[x,y],[x+8, y],[x+4,y+8*step]]);
                y+=pitch;
                i--;
            }
        }
    }
    
/*    function computeAverageSpeed() {
        var size = 0;
        var data = paceData.getData();
        var sumOfData = 0.0;
        for (var i = 0; i < data.size(); i++) {
            if (data[i] != null) {
                sumOfData = sumOfData + data[i];
                size++;
            }
        }
        if (sumOfData > 0) {
            return sumOfData / size;
        }
        return 0.0;
    }*/

    function drawHrChart(dc){
        var data = hrData.getData();
        var position = hrData.lastPosition();
        var max = data.size();
        var x = 10; var y = 120;
        var h;
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var offset = hr-30;
        var last = null;

        if(offset<0){offset = 0;}

        for(var i = max-1; i>=0; i--){
            h = data[position];
            if(h != null){
                if(h>=offset){
                    if(last == null){
                        dc.drawPoint(x+i*2, y-h+offset);
                    } else {
                        dc.drawLine(x+i*2, y-h+offset, x+i*2+2, y-last+offset);
                    }
                    last = h;
                }
            } else {
                last = null;
            }
            position--;
            if(position<0){
                position = max-1;
            }
        }
    }
    
    function computeHour(hour) {
        if (hour < 1) {
            return hour + 12;
        }
        if (hour >  12) {
            return hour - 12;
        }
        return hour;      
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
    
    //! @author Roelof Koelewijn
    //function for arc
	function drawZoneBarsArcs(dc, radius, centerX, centerY, hr){
		
		var zoneCircleWidth = [7, 7, 7, 7, 7, 7];
		
		var i;	
		for (i = 0; i < zoneLowerBound.size() && hr >= zoneLowerBound[i]; ++i) { }
		if(i >= 0){
			zoneCircleWidth[i] = 15;
		}
		
		var zonedegree = 58 / (zoneLowerBound[1] - zoneLowerBound[0]);
		
		//zone 1
		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zoneCircleWidth[1]);
		dc.drawArc(centerX, centerY, radius - zoneCircleWidth[1]/2, 1, 220, 166);
		//zone 2
		dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zoneCircleWidth[2]);
		dc.drawArc(centerX, centerY, radius - zoneCircleWidth[2]/2, 1, 166, 112);
		//zone 3 OK
		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zoneCircleWidth[3]);
		dc.drawArc(centerX, centerY, radius - zoneCircleWidth[3]/2, 1, 112, 58);
		//zone 4
		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zoneCircleWidth[4]);
		dc.drawArc(centerX, centerY, radius - zoneCircleWidth[4]/2, 1, 58, 4);
		//zone 5
		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zoneCircleWidth[5]);
		dc.drawArc(centerX, centerY, radius - zoneCircleWidth[5]/2, 1, 4, 320);
		
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

//! A circular queue implementation.
//! @author Konrad Paumann
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
            return Math.round((sum/size).toFloat());
        }
    }
    
    //! Reset the queue to its initial state.
    function reset() {
        for (var i = 0; i < data.size(); i++) {
            data[i] = null;
        }
        pos = 0;
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