# SPDX-License-Identifier: MIT
import hashlib,json,pathlib,plistlib,subprocess
root=pathlib.Path(__file__).resolve().parent.parent
version=json.loads((root/'package.json').read_text())['version'];out=root/f'release/ios-{version}'
app=root/'ios/build/Vyrax-unsigned.xcarchive/Products/Applications/Vyrax.app'
ext=app/'PlugIns/VyraxTunnel.appex'
for bundle in [app,ext]:
    info=plistlib.loads((bundle/'Info.plist').read_bytes())
    assert info['CFBundleShortVersionString']==version
    arch=subprocess.check_output(['lipo','-archs',str(bundle/info['CFBundleExecutable'])],text=True).strip()
    assert arch=='arm64',arch
    assert not (bundle/'embedded.mobileprovision').exists()
assert plistlib.loads((ext/'Info.plist').read_bytes())['NSExtension']['NSExtensionPointIdentifier']=='com.apple.networkextension.packet-tunnel'
assert (app/'ui/index.html').exists() and (app/'licenses/core').exists()
assert len(list((app/'licenses/core').glob('*')))>15
report={'version':version,'deviceArchitecture':'arm64','minimumIOS':'16.0','deviceArchiveCompiled':True,'signing':'unsigned; NOT installable','realDeviceVPNTested':False,'simulatorVPNAvailable':False,'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()}
(out/'BUILD-VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n')
print('Device app + VPN extension, version, architecture and licenses verified; signing remains required')
