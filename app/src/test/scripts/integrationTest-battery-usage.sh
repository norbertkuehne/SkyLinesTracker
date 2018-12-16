#!/bin/bash
#
EMULATOR_DIR="/home/andreas/opt/android-sdk-linux/tools"
DEVICE="emulator-5554"
PROJECT_DIR="/home/andreas/IdeaProjects/SkyLinesTracker"
TEST_DIR="/home/andreas/IdeaProjects/SkyLinesTracker/Tests"
IP=$(hostname -I | awk '{print $1}')
INT=1
QUEUE_FIXES=${1:-true}
KEY="ABCD1234"

cd ${TEST_DIR}/scripts
rm -rf sim-test*.out
rm -rf rcv-test*.out
pkill -f UDP-Receiver.jar

trap "pkill -f UDP-Receiver.jar; exit" INT TERM EXIT

${EMULATOR_DIR}/emulator -avd Device -netspeed full -netdelay none -no-boot-anim -gpu swiftshader &
sleep 30

python preference_file.py ${KEY} ${INT}  false  true ${IP} ${QUEUE_FIXES} 1800

adb -s ${DEVICE} push ch.luethi.skylinestracker_preferences.xml /data/data/ch.luethi.skylinestracker/shared_prefs/
adb -s ${DEVICE} install -r  ${PROJECT_DIR}/out/SkyLinesTracker.apk
adb -s ${DEVICE} shell dumpsys batterystats --reset
adb -s ${DEVICE} shell dumpsys battery set ac 0
adb -s ${DEVICE} shell dumpsys battery set level 80
adb -s ${DEVICE} shell dumpsys power ac off
adb -s ${DEVICE} shell dumpsys battery

adb -s ${DEVICE} shell am start -W -n ch.luethi.skylinestracker/ch.luethi.skylinestracker.MainActivity -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -e ISTESTING true -e TESTING_IP ${IP}

sh clickLiveTracking.sh ${DEVICE}

adb -s ${DEVICE} shell ls -l  /data/data/ch.luethi.skylinestracker/shared_prefs/ch.luethi.skylinestracker_preferences.xml
adb -s ${DEVICE} shell setprop persist.sys.timezone UTC

echo "### $(date +"%T") GPS simmluation, with Internet connection"
adb -s ${DEVICE} shell svc data enable
java -jar ${TEST_DIR}/UDP-Receiver.jar -br > rcv-test.out &
python gps_simulator.py 127.0.0.1 1200 ${KEY} > sim-test.out &
sleep 60

echo "### $(date +"%T") Simulate PositionService restart"
adb -s ${DEVICE} shell am stopservice ch.luethi.skylinestracker/.PositionService
adb -s ${DEVICE} shell am startservice ch.luethi.skylinestracker/.PositionService

echo "### $(date +"%T") Simulate network connection loss"
adb -s ${DEVICE} shell svc data disable
sleep 180
adb -s ${DEVICE} shell svc data enable
sleep 30

echo "### $(date +"%T") Simulate network connection loss with PositionService restart"
adb -s ${DEVICE} shell svc data disable
sleep 260
adb -s ${DEVICE} shell am stopservice ch.luethi.skylinestracker/.PositionService
adb -s ${DEVICE} shell am startservice ch.luethi.skylinestracker/.PositionService
adb -s ${DEVICE} shell svc data enable

leep 1200

pkill -f UDP-Receiver.jar
pkill -f gps_simulator.py

echo "#### $(date +"%T") Bugreport and dumpsys batterystats"
adb -s ${DEVICE} shell dumpsys battery
adb -s ${DEVICE} shell bugreport > bugreport-${QUEUE_FIXES}.txt
adb -s ${DEVICE} shell dumpsys batterystats > batterystats-${QUEUE_FIXES}.txt


echo "#### $(date +"%T") Shuting down everting....................."
adb -s ${DEVICE} shell am force-stop ch.luethi.skylinestracker
adb -s ${DEVICE} emu kill
sh stopEmulator.sh

echo "#### $(date +"%T") Create batterystats-html"
sh create-batterystats-html.sh ${QUEUE_FIXES}