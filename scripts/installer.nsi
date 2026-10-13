; Vyrax — نصب‌کنندهٔ ویندوز (به‌ازای هر کاربر، بدون نیاز به دسترسی مدیر)
; ساخت:  makensis scripts\installer.nsi

!include "MUI2.nsh"
!include "LogicLib.nsh"

!define APPNAME    "Vyrax"
!define APPVERSION "0.1.20"
!ifndef APPDIR
!define APPDIR "..\release\Vyrax"
!endif
!define REGKEY     "Software\Microsoft\Windows\CurrentVersion\Uninstall\Vyrax"

Name "${APPNAME}"
OutFile "..\release\VyraxSetup-${APPVERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\Vyrax"
InstallDirRegKey HKCU "Software\Vyrax" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Unicode true

!define MUI_ABORTWARNING
!define MUI_ICON "..\native\Vyrax.ico"
!define MUI_UNICON "..\native\Vyrax.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\Vyrax.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Run Vyrax now"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchVyrax

VIProductVersion "0.1.20.0"
VIAddVersionKey /LANG=1033 "ProductName" "Vyrax"
VIAddVersionKey /LANG=1033 "FileDescription" "Vyrax Installer"
VIAddVersionKey /LANG=1033 "FileVersion" "0.1.20"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright (c) 2026 Amyrax"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

; ShellExecute honours the application's administrator manifest at first launch.
Function LaunchVyrax
  ExecShell "open" "$INSTDIR\Vyrax.exe"
FunctionEnd

; اگر برنامه باز است، اول بسته شود وگرنه فایل‌ها قفل می‌مانند
Function .onInit
  retry:
    FindWindow $0 "" "${APPNAME}"
    StrCmp $0 0 go
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION \
      "${APPNAME} is running. Close it, then press Retry." \
      IDRETRY retry
    Abort
  go:
FunctionEnd

Section "Vyrax" SecMain
  SetOutPath "$INSTDIR"
  ; قبل از کپی، خودِ پوشه را پاک می‌کنیم تا فایلِ کش‌ماندهٔ نسخهٔ قبلی (مثل
  ; ui/assets/index-XXXX قدیمی) روی پوشهٔ جدید سوار نشود و رابط را به قبل برنگرداند.
  RMDir /r "$INSTDIR"
  File /r "${APPDIR}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "Software\Vyrax" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${REGKEY}" "DisplayName"     "${APPNAME}"
  WriteRegStr HKCU "${REGKEY}" "DisplayVersion"  "${APPVERSION}"
  WriteRegStr HKCU "${REGKEY}" "DisplayIcon"     "$INSTDIR\Vyrax.exe"
  WriteRegStr HKCU "${REGKEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${REGKEY}" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "${REGKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${REGKEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${REGKEY}" "EstimatedSize" 120000

  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\Vyrax.exe" "" "$INSTDIR\Vyrax.exe" 0
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\Vyrax.exe" "" "$INSTDIR\Vyrax.exe" 0
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\${APPNAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APPNAME}"
  DeleteRegKey HKCU "${REGKEY}"
  DeleteRegKey HKCU "Software\Vyrax"
  ; کانفیگ‌ها و تنظیمات کاربر در %LOCALAPPDATA%\Vyrax دست‌نخورده می‌مانند
  RMDir /r "$INSTDIR"
SectionEnd
