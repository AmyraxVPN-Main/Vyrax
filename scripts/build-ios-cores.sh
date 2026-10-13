#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ios/build vendor/ios/sources
hev_pin=$(node -p 'require("./vendor/ios-versions.json").hev.commit')
if [[ ! -d vendor/ios/hev/.git ]]; then git clone --filter=blob:none https://github.com/heiher/hev-socks5-tunnel.git vendor/ios/hev; fi
git -C vendor/ios/hev checkout --detach "$hev_pin"
git -C vendor/ios/hev submodule update --init --recursive
git -C vendor/ios/hev submodule status --recursive > vendor/ios/sources/hev-submodules.txt
git -C vendor/ios/hev archive --format=tar "$hev_pin" | gzip > vendor/ios/sources/hev-source.tar.gz
python3 - <<'PY'
import subprocess, pathlib
root=pathlib.Path('vendor/ios/hev').resolve()
for line in subprocess.check_output(['git','-C',str(root),'submodule','status','--recursive'],text=True).splitlines():
    commit,rel,*_=line.strip().split()
    with open('vendor/ios/sources/hev-'+rel.replace('/','-')+'.tar.gz','wb') as out:
        archive=subprocess.Popen(['git','-C',str(root/rel),'archive','--format=tar',commit],stdout=subprocess.PIPE)
        subprocess.run(['gzip'],stdin=archive.stdout,stdout=out,check=True)
        if archive.wait()!=0: raise RuntimeError('Source archive failed')
PY
(cd ios/Engine && go mod tidy && go mod verify && go test -race ./...)
cp ios/Engine/go.mod ios/Engine/go.sum vendor/ios/sources/
# Keep the precise module archives, including MPL source and all dependency
# notices, alongside our MIT application source. No private build data is copied.
(cd ios/Engine && go mod download -json all) > ios/build/modules.json
python3 - <<'PY'
import json,pathlib,shutil
text=pathlib.Path('ios/build/modules.json').read_text();at=0;rows=[];decoder=json.JSONDecoder()
out=pathlib.Path('vendor/ios/sources');notices=pathlib.Path('ios/Resources/licenses/core');notices.mkdir(parents=True,exist_ok=True)
while at<len(text):
    while at<len(text) and text[at].isspace():at+=1
    if at==len(text):break
    row,size=decoder.raw_decode(text[at:]);at+=size
    if 'Error' in row:raise RuntimeError('Dependency resolution failed')
    slug=row['Path'].replace('/','-')+'-'+row['Version'];source=pathlib.Path(row['Dir']) if 'Dir' in row else None
    if 'Zip' in row:shutil.copyfile(row['Zip'],out/(slug+'.zip'))
    row={key:value for key,value in row.items() if key not in ['Dir','GoMod','Zip','Info']}
    rows.append(row)
    if source:
        for file in source.iterdir():
            if file.is_file() and file.name.lower().startswith(('license','copying','notice')):shutil.copyfile(file,notices/(slug+'-'+file.name))
(out/'go-dependencies.json').write_text(json.dumps(rows,indent=2)+'\n')
shutil.copyfile('vendor/ios/hev/LICENSE',notices/'hev-MIT.txt')
for source in pathlib.Path('vendor/ios/hev/third-part').rglob('*'):
    if source.is_file() and source.name.lower().startswith(('license','copying')):
        shutil.copyfile(source,notices/('hev-'+str(source.relative_to('vendor/ios/hev')).replace('/','-')))
PY
for sdk in iphoneos iphonesimulator; do
  if [[ "$sdk" == iphoneos ]]; then target=arm64-apple-ios16.0; else target=arm64-apple-ios16.0-simulator; fi
  path="$PWD/ios/build/$sdk"
  mkdir -p "$path/core-headers" "$path/hev-headers/HevSocks5Tunnel"
  sdkpath=$(xcrun --sdk "$sdk" --show-sdk-path)
  export GOOS=ios GOARCH=arm64 CGO_ENABLED=1
  export CC="xcrun --sdk $sdk clang"
  export CGO_CFLAGS="-target $target -isysroot $sdkpath"
  export CGO_LDFLAGS="$CGO_CFLAGS"
  (cd ios/Engine && go build -trimpath -tags=ios -ldflags='-s -w' -buildmode=c-archive -o "$path/libVyraxCore.a" ./cmd)
  cp "$path/libVyraxCore.h" "$path/core-headers/"
  printf 'module VyraxCore { header "libVyraxCore.h" export * }\n' > "$path/core-headers/module.modulemap"
  (cd vendor/ios/hev && make clean && make -j3 PP="xcrun --sdk $sdk clang" CC="xcrun --sdk $sdk clang" CFLAGS="$CGO_CFLAGS -O2" LFLAGS="$CGO_LDFLAGS" static)
  libtool -static -o "$path/libHevSocks5Tunnel.a" vendor/ios/hev/bin/libhev-socks5-tunnel.a vendor/ios/hev/third-part/lwip/bin/liblwip.a vendor/ios/hev/third-part/yaml/bin/libyaml.a vendor/ios/hev/third-part/hev-task-system/bin/libhev-task-system.a
  cp vendor/ios/hev/src/hev-main.h "$path/hev-headers/HevSocks5Tunnel/"
  printf 'module HevSocks5Tunnel { header "hev-main.h" export * }\n' > "$path/hev-headers/HevSocks5Tunnel/module.modulemap"
done
unset GOOS GOARCH CGO_ENABLED CC CGO_CFLAGS CGO_LDFLAGS
xcodebuild -create-xcframework -library ios/build/iphoneos/libVyraxCore.a -headers ios/build/iphoneos/core-headers -library ios/build/iphonesimulator/libVyraxCore.a -headers ios/build/iphonesimulator/core-headers -output ios/build/VyraxCore.xcframework
xcodebuild -create-xcframework -library ios/build/iphoneos/libHevSocks5Tunnel.a -headers ios/build/iphoneos/hev-headers -library ios/build/iphonesimulator/libHevSocks5Tunnel.a -headers ios/build/iphonesimulator/hev-headers -output ios/build/HevSocks5Tunnel.xcframework
