#!/bin/sh
# Real local ActivityKit calls on an owned fresh simulator, never a user's device.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DERIVED_DATA=${SCRIPTWIDGET_ACTIVITYKIT_DERIVED_DATA:-/tmp/scriptwidget-activitykit-smoke}
RUNTIME=${SCRIPTWIDGET_ACTIVITYKIT_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}
DEVICE_TYPE=${SCRIPTWIDGET_ACTIVITYKIT_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17}
mkdir -p "$ROOT/__Release/capabilities/live-activity"
OUTPUT=$(mktemp -d "$ROOT/__Release/capabilities/live-activity/sdk-run.XXXXXX")
SMOKE_DEVICE=""
cleanup() {
  if [ -n "$SMOKE_DEVICE" ]; then
    if [ "${SCRIPTWIDGET_ACTIVITYKIT_KEEP_SIMULATOR:-0}" = "1" ]; then
      echo "Retained private simulator: $SMOKE_DEVICE"
    else
      xcrun simctl shutdown "$SMOKE_DEVICE" >/dev/null 2>&1 || true
      xcrun simctl delete "$SMOKE_DEVICE" >/dev/null 2>&1 || true
    fi
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
SMOKE_DEVICE=$(xcrun simctl create "ScriptWidget ActivityKit QA $(date +%Y%m%d-%H%M%S)" "$DEVICE_TYPE" "$RUNTIME")
printf '%s\n' "$SMOKE_DEVICE" > "$OUTPUT/simulator-udid.txt"
xcrun simctl boot "$SMOKE_DEVICE"
xcrun simctl bootstatus "$SMOKE_DEVICE" -b
cd "$ROOT"
RUN_ID=$(uuidgen)
# Repetitions relaunch the host without reinstalling its app. Two independent
# xcodebuild invocations reinstall on Simulator; UseDestinationArtifacts is
# device-only. See the installed xcodebuild -help / xcodebuild.xctestrun(5).
TEST_RUNNER_SCRIPTWIDGET_ACTIVITYKIT_SMOKE=1 \
TEST_RUNNER_SCRIPTWIDGET_ACTIVITYKIT_SMOKE_UDID="$SMOKE_DEVICE" \
TEST_RUNNER_SCRIPTWIDGET_ACTIVITYKIT_PHASE=relaunch \
TEST_RUNNER_SCRIPTWIDGET_ACTIVITYKIT_RUN_ID="$RUN_ID" \
TEST_RUNNER_SCRIPTWIDGET_ACTIVITYKIT_CAPTURE="${SCRIPTWIDGET_ACTIVITYKIT_CAPTURE:-0}" \
xcodebuild -quiet test -project iOS/ScriptWidget.xcodeproj -scheme ScriptWidgetRuntimeTests \
  -destination "platform=iOS Simulator,id=$SMOKE_DEVICE" -derivedDataPath "$DERIVED_DATA" \
  -test-iterations 2 -test-repetition-relaunch-enabled YES \
  -collect-test-diagnostics never -resultBundlePath "$OUTPUT/lifecycle.xcresult" \
  -only-testing:ScriptWidgetRuntimeTests/ScriptWidgetActivityKitIntegrationTests
DATA=$(xcrun simctl get_app_container "$SMOKE_DEVICE" com.everettjf.scriptwidget data)
cp "$DATA/Documents/activitykit-created.json" "$OUTPUT/create-report.json"
cp "$DATA/Documents/activitykit-smoke.json" "$OUTPUT/activitykit-smoke.json"
xcrun xcresulttool get test-results summary --path "$OUTPUT/lifecycle.xcresult" > "$OUTPUT/summary.json"
xcrun xcresulttool get test-results tests --path "$OUTPUT/lifecycle.xcresult" > "$OUTPUT/tests.json"
python3 - "$OUTPUT" "$SMOKE_DEVICE" "$RUN_ID" <<'PYREPORT'
import json,sys
from pathlib import Path
root=Path(sys.argv[1]);summary=json.loads((root/'summary.json').read_text())
assert summary['result']=='Passed' and summary['passedTests']>=1 and summary['failedTests']==0 and summary['skippedTests']==0, summary
def repetitions(nodes):
 result=[]
 for node in nodes:
  if node.get('nodeType')=='Repetition':result.append(node)
  result.extend(repetitions(node.get('children',[])))
 return result
repeats=repetitions(json.loads((root/'tests.json').read_text())['testNodes'])
assert len(repeats)==2 and all(r['result']=='Passed' for r in repeats),repeats
created=json.loads((root/'create-report.json').read_text());ended=json.loads((root/'activitykit-smoke.json').read_text())
assert created['phase']=='created' and ended['phase']=='ended', (created,ended)
assert ended['simulator']==sys.argv[2] and ended['runID']==sys.argv[3], ended
assert ended['restoredFromSystemList'] is True and ended['writerProcessWasGone'] is True, ended
assert ended['pid']!=ended['readerPID'], ended
assert json.loads(ended['lastState'])['progress']==5,ended
for key in ['activityID','binding','profile','simulator','runID','pid','name','state']:
 assert created[key]==ended[key],key
print('✓ Real ActivityKit create / terminate app process / relaunch restore / update / end passed')
print('Evidence:',root)
print('This does not establish physical lock-screen or Dynamic Island visual acceptance.')
PYREPORT
