#!/bin/bash

##################################################################################
#
# Test Runner Script 
# Copyright 2013 Deloitte Digital
# Authors: Jonathan Schooler, Russell Collins
#
# This tool is intended to facilitate JUnit-style testing of android projects. If
# you are using it on non-rooted devices, please ensure that your Android manifest
# for the main project includes android.permission.WRITE_EXTERNAL_STORAGE or you
# will be unable to store XML output, Screenshots, and Emma code coverage files
# should your test job generate them.
#
#
#                          COPYLEFT PREAMBLE
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#################################################################################


# global defines
# check that ANDROID_HOME is set
if [ -z $ANDROID_HOME ]; then
	echo ""
	echo "Error: ANDROID_HOME environment variable not set."
	echo "ANDROID_HOME should point to the full path of your Android SDK installation."
	echo ""
	exit -1
fi

PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
USAGE_SYNTAX="usage: $0 <test id> <project apk> <test apk> <device> <test suite> <test runner> <coverage enabled>"


# get arguments
TEST_ID="$1"
PROJECT_APK="$2"
TEST_APK="$3"
DEVICE="$4"
TEST_SUITE="$5"
TEST_RUNNER="$6"
COVERAGE_ENABLED="$7"
EXPECTED_ARGS=7

# check for all args
if [ $# -ne $EXPECTED_ARGS ]; then
	echo $USAGE_SYNTAX
	exit -1
fi

ADB_DEVICE_COMMAND="adb -s $DEVICE"
INPUT_DIR=$TEST_ID
OUTPUT_DIR=$INPUT_DIR
RESULTS_DIR=$OUTPUT_DIR/results/$DEVICE
SCREENSHOTS_DIR=/sdcard/Robotium-Screenshots

# using the same directory as Robotium's Screenshots for convenience
JUNIT_OUTPUT_DIR=/sdcard/Robotium-Screenshots

# dumping the coverage file into the SCREENSHOTS_DIR for convenience
COVERAGE_FILE=/sdcard/Robotium-Screenshots/coverage.ec

# check that files exist
if [ ! -e "$INPUT_DIR"/"$PROJECT_APK" ]; then
	echo ""
	echo "ERROR: $INPUT_DIR/$PROJECT_APK is missing"
	echo ""
	exit -1
fi
if [ ! -e "$INPUT_DIR"/"$TEST_APK" ]; then
	echo ""
	echo "ERROR: $INPUT_DIR/$TEST_APK is missing"
	echo ""
	exit -1
fi


# analyze apk's for package names
PROJECT_PACKAGE=`aapt dump badging "$INPUT_DIR"/"$PROJECT_APK" | grep package | sed -r "s/^.*package: name='(.*)' versionCode.*$/\1/g"`
TEST_PACKAGE=`aapt dump badging "$INPUT_DIR"/"$TEST_APK" | grep package | sed -r "s/^.*package: name='(.*)' versionCode.*$/\1/g"`


# print start message
echo ""
echo ""
echo "Build Verification Test"
echo `date`
echo ""
echo "test id        : "$TEST_ID
echo "package        : "$PROJECT_PACKAGE
echo "test package   : "$TEST_PACKAGE
echo "project apk    : "$PROJECT_APK
echo "test apk       : "$TEST_APK
echo "device         : "$DEVICE
echo "test suite     : "$TEST_SUITE
echo "test runner    : "$TEST_RUNNER
echo "EMMA enabled   : "$COVERAGE_ENABLED


# check that packages exist
if [ -z $PROJECT_PACKAGE ]; then
	echo ""
	echo "Error: cannot get package info for $PROJECT_APK"
	echo ""
	exit -1
fi
if [ -z $TEST_PACKAGE ]; then
	echo ""
	echo "Error: cannot get package info for $TEST_APK"
	echo ""
	exit -1
fi


# check whether a test suite was provided, resorting to default
if [ $TEST_SUITE = "NOSUITEPROVIDED" ]; then
	echo ""
	echo "No Suite provided. Defaulting to ALL TESTS IN $TEST_PACKAGE."
	echo ""
	
	TEST_STRING=""
	echo "my test string is $TEST_STRING"

else

	echo ""
	echo "$TEST_SUITE provided. Running tests from the suite instead.."
	echo ""
	
	# check for suitebuilder options, default to assuming a suite package was provided
	# see http://developer.android.com/reference/android/test/InstrumentationTestRunner.html for usage details
	case "$TEST_SUITE" in
		# uses only @SmallTest annotated test cases
		small) TEST_STRING="-e size small" ;;
		# uses only @MediumTest annotated test cases
		medium) TEST_STRING="-e size medium" ;;
		# uses only @LargeTest annotated test cases
		large) TEST_STRING="-e size large" ;;
		# runs all test cases that do not derive from InstrumentationTestCase and are not performance tests
		unit) TEST_STRING="-e unit true" ;;
		# runs all test cases that do derive from InstrumentationTestCase
		func) TEST_STRING="-e func true" ;;
		# assuming a string of any kind not matching the above indicates a fully-qualified suite was provided
		*) TEST_STRING="-e class $TEST_PACKAGE.$TEST_SUITE" ;;
	esac
	
	echo "My test string is $TEST_STRING"

fi


# make sure adb server is up
adb start-server

# check that the requested device is online
DEVICE_STATE=`$ADB_DEVICE_COMMAND get-state`
echo "device state   : "$DEVICE_STATE

if [ "$DEVICE_STATE" != "device" ]; then
	echo ""
	echo "ERROR: DEVICE '$DEVICE' NOT ONLINE"
	echo ""
	exit -1
fi

# store previous working directory
PWD=`pwd`

# go
echo ""
echo "------------------------------------------"
echo " Removing any existing results"
echo "------------------------------------------"
echo "results directory : "$RESULTS_DIR
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

echo ""
echo "------------------------------------------"
echo " Uninstalling previous packages"
echo "------------------------------------------"
echo -n "$PROJECT_PACKAGE: "
$ADB_DEVICE_COMMAND uninstall "$PROJECT_PACKAGE"
echo -n "$TEST_PACKAGE: "
$ADB_DEVICE_COMMAND uninstall "$TEST_PACKAGE"

echo ""
echo "------------------------------------------"
echo " Installing APKs"
echo "------------------------------------------"
echo $INPUT_DIR/$PROJECT_APK
$ADB_DEVICE_COMMAND install -r "$INPUT_DIR"/"$PROJECT_APK"
echo $INPUT_DIR/$TEST_APK
$ADB_DEVICE_COMMAND install -r "$INPUT_DIR"/"$TEST_APK"


#################################################
#
# Run the actual tests
#
#################################################


echo ""
echo ""
echo "------------------------------------------"
echo " Running tests"
echo "------------------------------------------"
RUN_COMMAND="$ADB_DEVICE_COMMAND"" shell am instrument -e coverage ""$COVERAGE_ENABLED"" -e coverageFile ""$COVERAGE_FILE"" -e junitOutputDirectory ""$JUNIT_OUTPUT_DIR"" ""$TEST_STRING"" -w ""$TEST_PACKAGE""/""$TEST_RUNNER"
echo "Run command:"
echo "$RUN_COMMAND"
echo ""
$RUN_COMMAND


echo ""
echo "------------------------------------------"
echo " Get results, screenshots, and coverage"
echo "------------------------------------------"
$ADB_DEVICE_COMMAND pull "$SCREENSHOTS_DIR" "$RESULTS_DIR"

# Repeat if SCREENSHOTS_DIR != JUNIT_OUTPUT_DIR
if [ "$SCREENSHOTS_DIR" != "$JUNIT_OUTPUT_DIR" ]; then
	$ADB_DEVICE_COMMAND pull "$JUNIT_OUTPUT_DIR" "$RESULTS_DIR"
fi


echo ""
echo "------------------------------------------"
echo " Removing any existing test output"
echo "------------------------------------------"
$ADB_DEVICE_COMMAND shell rm -R "$SCREENSHOTS_DIR"

# Repeat if SCREENSHOTS_DIR != JUNIT_OUTPUT_DIR
if [ "$SCREENSHOTS_DIR" != "$JUNIT_OUTPUT_DIR" ]; then
	$ADB_DEVICE_COMMAND shell rm -R "$JUNIT_OUTPUT_DIR"
fi



if [ "$COVERAGE_ENABLED" = "true" ]; then
echo ""
echo "------------------------------------------"
echo " Generate EMMA code coverage report "
echo "------------------------------------------"
	cd "$RESULTS_DIR"
	java -cp $ANDROID_HOME/tools/lib/emma.jar emma report -r html,xml -in ../../coverage.em -in coverage.ec
fi

echo ""
echo "------------------------------------------"
echo " DONE"
echo "------------------------------------------"
echo ""

# return to previous working directory
cd $PWD
