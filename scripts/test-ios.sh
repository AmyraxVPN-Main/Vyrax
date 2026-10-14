#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(node -p 'require("./package.json").version')
out="$PWD/release/ios-$version"
device=$(xcrun simctl list devices available -j | python3 -c 'import json,sys;d=json.load(sys.stdin);print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if x["name"].startswith("iPhone")))')
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcodebuild -project ios/Vyrax.xcodeproj -scheme Vyrax -destination "platform=iOS Simulator,id=$device" -derivedDataPath "$PWD/ios/build/DerivedData" -resultBundlePath "$PWD/ios/build/HostTests.xcresult" CODE_SIGNING_ALLOWED=NO test-without-building > "$out/host-tests.log" 2>&1 || { tail -100 "$out/host-tests.log";exit 1; }
xcrun simctl launch "$device" com.amyrax.vyrax
xcrun simctl io "$device" screenshot "$out/iphone-ui.png"
xcrun xcresulttool get test-results summary --path ios/build/HostTests.xcresult --format json > "$out/host-tests-summary.json"
xcrun xcresulttool export attachments --path ios/build/HostTests.xcresult --output-path "$out/ui-snapshots"
python3 - <<'PY'
import json,pathlib
version=json.loads(pathlib.Path('package.json').read_text())['version'];path=pathlib.Path('release')/('ios-'+version)/'BUILD-VERIFICATION.json'
report=json.loads(path.read_text());report['simulatorHostTestsPassed']=True;report['simulatorArchitecture']='arm64';report['realDeviceVPNTested']=False
path.write_text(json.dumps(report,indent=2)+'\n')
PY
