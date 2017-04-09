# Heart Pace Runner

![HeartRateRunner Screenshot Bright](/doc/cover.png) 

# Heart rate zones are hardcoded so far, because it is under testing and there are no permissions to read it from profile when installed manually. 
# Average split pace is under testing now. 

DataField designed to show all running metrics at one page. 
It shows heart rate and pace with trends and hr zones. 

* Current heart rate zone indicator (zones from a watch profile)
* Heart rate trend for up to 30 mins
* Average pace trend chart for last 5 laps and current lap average
* Pace difference indicator of how the current pace differes from the lap average
* Pace in km/min or mi/min based on system settings
* Distance elapsed distance in km or miles based on system settings.
* Duration of the activity in [hh:]mm:ss
* use bright or dark color scheme based on the background color setting of the app (Settings/Apps/Run/Background Color).
  needs at least a firmware with SDK 1.2 compatibility (otherwise bright scheme is always used).

===============================================

## Special thanks
* To Roelof Koelewijn
* Thank you for sharing your code showing hr zones as open source on https://github.com/roelofk/HeartRateRunner [Garmin App Store](https://apps.garmin.com/nl-NL/apps/cb7742e6-1914-490f-b581-fa41ad863b72) as a base for this app

===============================================

## Install Instructions
A Data Field needs to be set up within the settings for a given activity (like Run)

* Long Press UP
* Settings
* Apps
* Run
* Data Screens
* Screen N
* Layout
* Select single field
* Field 1
* Select ConnectIQ Fields
* Select HeartRateRunner
* Long Press Down to go back to watch face

===============================================

## Usage
Start Run activity.
Hopefully you see the HeartRateRunner datafield and can read the values.

===============================================