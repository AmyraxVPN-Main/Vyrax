; Catalog/UI update for an existing Vyrax 0.1.31 installation.
; Deliberately packages only the project-built UI, never an external native host.
Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"

Name "Vyrax 0.1.31 - Locations update"
OutFile "..\release\Vyrax-0.1.31-Locations-Update.exe"
InstallDir "$LOCALAPPDATA\Programs\Vyrax"
InstallDirRegKey HKCU "Software\Vyrax" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!define MUI_ICON "..\native\Vyrax.ico"
!define MUI_FINISHPAGE_TEXT "The public location catalog has been updated. Open Vyrax, go to Subscriptions, and refresh Free servers to load the complete list."
VIProductVersion "0.1.31.1"
VIAddVersionKey /LANG=1033 "ProductName" "Vyrax locations update"
VIAddVersionKey /LANG=1033 "FileDescription" "Location catalog update for an existing Vyrax 0.1.31 installation"
VIAddVersionKey /LANG=1033 "FileVersion" "0.1.31.1"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright (c) 2026 Amyrax"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "English"

Section "Locations update"
  IfFileExists "$INSTDIR\Vyrax.exe" 0 missing
  IfFileExists "$INSTDIR\ui\assets\index-DJPnzs-_.js" running
  IfFileExists "$INSTDIR\ui\vyrax-locations-update.json" running wrongVersion
  missing:
    MessageBox MB_ICONEXCLAMATION "Select the folder containing your installed Vyrax 0.1.31 application. This package updates its location catalog."
    Abort
  wrongVersion:
    MessageBox MB_ICONEXCLAMATION "This update requires the Vyrax 0.1.31 interface. Install that version first."
    Abort
  running:
    FindWindow $0 "" "Vyrax"
    StrCmp $0 0 install
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Close Vyrax completely, then click Retry to update its locations." IDRETRY running
    Abort
  install:
    SetOverwrite on
    SetOutPath "$INSTDIR\ui"
    File /r "..\dist\*.*"
    FileOpen $0 "$INSTDIR\ui\vyrax-locations-update.json" w
    FileWrite $0 '{"version":"0.1.31.1","catalog":"foxy-public-locations","updated":"2026-10-15"}$\r$\n'
    FileClose $0
SectionEnd
