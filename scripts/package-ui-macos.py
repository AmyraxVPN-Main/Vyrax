"""Overlay UI; re-sign only the outer bundle, preserving signed cores/helpers."""
import hashlib,json,pathlib,plistlib,shutil,subprocess,sys
app=pathlib.Path(sys.argv[1]);payload=pathlib.Path(sys.argv[2]);out=pathlib.Path(sys.argv[3]);arch=sys.argv[4];version='0.1.35'
res=app/'Contents/Resources';ui=res/'app/ui';out.mkdir(parents=True,exist_ok=True)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
native={str(p.relative_to(app)):digest(p) for p in app.rglob('*') if p.is_file() and not p.is_symlink() and ('/native/' in str(p) or '/Frameworks/' in str(p))}
# Keep the two native menu-bar images, which do not belong to the shared UI.
tray={p.name:p.read_bytes() for p in ui.glob('trayTemplate*.png')}
assert ui.resolve().is_relative_to(app.resolve());shutil.rmtree(ui);shutil.copytree(payload/'ui',ui)
for name,data in tray.items():(ui/name).write_bytes(data)
shutil.copytree(payload/'licenses',res/'licenses',dirs_exist_ok=True)
pkg=res/'app/package.json';data=json.loads(pkg.read_text());data['version']=version;pkg.write_text(json.dumps(data,indent=2)+'\n')
info=app/'Contents/Info.plist';data=plistlib.loads(info.read_bytes());data.update(CFBundleShortVersionString=version,CFBundleVersion=version,NSHumanReadableCopyright='Copyright (c) 2026 Amyrax; UI includes GPL-3.0 FLClash adaptations');info.write_bytes(plistlib.dumps(data))
subprocess.run(['codesign','--force','--sign','-','--options','runtime','--entitlements','macos/entitlements.plist',str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
for rel,hash_ in native.items():assert digest(app/rel)==hash_,rel
subprocess.run(['python3','scripts/verify-macos.py',str(app),arch],check=True)
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(out/f'Vyrax-{version}-macos-{arch}.zip')],check=True)
image=app.parent/'image';image.mkdir();subprocess.run(['ditto',str(app),str(image/'Vyrax.app')],check=True);(image/'Applications').symlink_to('/Applications')
subprocess.run(['hdiutil','create','-volname',f'Vyrax {version}','-srcfolder',str(image),'-ov','-format','UDZO',str(out/f'Vyrax-{version}-macos-{arch}.dmg')],check=True)
(out/'payload-verification.json').write_text(json.dumps({'version':version,'arch':arch,'nativeCoreAndFrameworkFilesUnchanged':len(native),'bundleSignatureVerified':True,'notarized':False},indent=2)+'\n')
