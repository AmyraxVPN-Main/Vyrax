# SPDX-License-Identifier: MIT
import json, pathlib, shutil, subprocess
root=pathlib.Path(__file__).resolve().parent.parent
res=root/'ios/Resources';res.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'dist',res/'ui',dirs_exist_ok=True)
index=res/'ui/index.html'
html=index.read_text()
html=html.replace('<head>','<head><meta http-equiv="Content-Security-Policy" content="default-src \'self\' vyrax:; script-src \'self\' vyrax:; style-src \'self\' vyrax: \'unsafe-inline\'; img-src \'self\' vyrax: data:; font-src \'self\' vyrax:; connect-src \'none\'; object-src \'none\'; base-uri \'none\'">')
index.write_text(html)
shutil.copyfile(root/'native/geo.bin',res/'geo.bin')
notices=res/'licenses';notices.mkdir(exist_ok=True)
for name in ['LICENSE','THIRD_PARTY_NOTICES.md','third_party/FoxyVPN-MIT.txt','docs/ios.md','vendor/ios-versions.json']:
    shutil.copyfile(root/name,notices/pathlib.Path(name).name)
shutil.copytree(root/'vendor/npm-licenses',notices/'npm',dirs_exist_ok=True)
assets=res/'Assets.xcassets';icon=assets/'AppIcon.appiconset';icon.mkdir(parents=True,exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'info':{'version':1,'author':'xcode'}}))
# iOS requires an opaque 1024px app icon; flatten our existing artwork.
subprocess.run(['python3','-c',"from PIL import Image;import sys;im=Image.open(sys.argv[1]).convert('RGBA');bg=Image.new('RGBA',im.size,(10,16,18,255));bg.alpha_composite(im);bg.convert('RGB').resize((1024,1024),Image.Resampling.LANCZOS).save(sys.argv[2])",str(root/'public/vyrax-icon.png'),str(icon/'icon.png')],check=True)
(icon/'Contents.json').write_text(json.dumps({'images':[{'idiom':'universal','platform':'ios','size':'1024x1024','filename':'icon.png'}],'info':{'version':1,'author':'xcode'}}))
color=assets/'LaunchBackground.colorset';color.mkdir(exist_ok=True)
(color/'Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'0.039','green':'0.063','blue':'0.071','alpha':'1.000'}}}],'info':{'version':1,'author':'xcode'}}))
