# Copyright 2018 Florian Bruhin (The Compiler) <mail@qutebrowser.org>
#
# This file is part of qutebrowser.
#
# qutebrowser is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# qutebrowser is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with qutebrowser.  If not, see <http://www.gnu.org/licenses/>.

# NSIS installer header. Uses NsisMultiUser plugin and contains portions of
# its demo code, copyright 2017 Richard Drizin, Alex Mitev.


;Languages (first is default language) - must be inserted after all pages
!insertmacro MUI_LANGUAGE "English"
!insertmacro MULTIUSER_LANGUAGE_INIT

; Reserve files
!insertmacro MUI_RESERVEFILE_LANGDLL

!macro MSI32_STACK
  Push "${MSI32_010}"
  Push "${MSI32_011}"
  Push "${MSI32_012}"
  Push "${MSI32_013}"
  Push "${MSI32_014}"
  Push "${MSI32_020}"
  Push "${MSI32_021}"
  Push "${MSI32_030}"
  Push "${MSI32_040}"
  Push "${MSI32_041}"
  Push "${MSI32_050}"
  Push "${MSI32_051}"
  Push "${MSI32_060}"
  Push "${MSI32_061}"
  Push "${MSI32_062}"
  Push "${MSI32_070}"
  Push "${MSI32_080}"
  Push "${MSI32_081}"
  Push "${MSI32_082}"
  Push "${MSI32_084}"
  Push "${MSI32_090}"
  Push "${MSI32_091}"
  Push "${MSI32_100}"
  Push "${MSI32_101}"
!macroend

!macro MSI64_STACK
  Push "${MSI64_010}"
  Push "${MSI64_011}"
  Push "${MSI64_012}"
  Push "${MSI64_013}"
  Push "${MSI64_014}"
  Push "${MSI64_020}"
  Push "${MSI64_021}"
  Push "${MSI64_030}"
  Push "${MSI64_040}"
  Push "${MSI64_041}"
  Push "${MSI64_050}"
  Push "${MSI64_051}"
  Push "${MSI64_060}"
  Push "${MSI64_061}"
  Push "${MSI64_062}"
  Push "${MSI64_070}"
  Push "${MSI64_080}"
  Push "${MSI64_081}"
  Push "${MSI64_082}"
  Push "${MSI64_084}"
  Push "${MSI64_090}"
  Push "${MSI64_091}"
  Push "${MSI64_100}"
  Push "${MSI64_101}"
!macroend

!macro CheckMSI
  ${foreach} $9 ${MSI_COUNT} 1 - 1
    Pop $R1
    ReadRegStr $0 HKLM "${REG_UN}\$R1" "DisplayName"
    ${if} $0 == "${PRODUCT_NAME}"
      ${exitfor}
    ${else}
      StrCpy $R1 ""
    ${endif}
  ${next}
!macroend

!macro CheckOldNSIS
  ReadRegStr $R0 HKLM "${REG_UN}\${PRODUCT_NAME}" "QuietUninstallString"
  ${if} $R0 != ""
    ReadRegStr $R0 HKLM "${REG_UN}\${PRODUCT_NAME}" "UninstallString"
    ${if} $R0 != ""
      System::Call 'Shlwapi::PathUnquoteSpaces(t r10r10)'
      IfFileExists $R0 +3 0
      DeleteRegKey HKLM "${REG_UN}\${PRODUCT_NAME}"
      StrCpy $R0 ""
    ${endif}
  ${endif}
!macroend

!macro RemoveOld UninstCmd
  ClearErrors
  ExecWait "${UninstCmd}"
  ${if} ${errors}
    MessageBox MB_ICONSTOP \
      "The uninstaller has failed to complete.$\r$\n\
      Please restart Windows and try again." \
      /SD IDOK
    Abort
  ${endif}
!macroend

; Sections
InstType "Full"
InstType "Typical"
InstType "Minimal"

Section "Core Files (required)" SectionCoreFiles
  SectionIn 1 2 3 RO

  ; if there's an installed version, uninstall it first (I chose not to start
  ; the uninstaller silently, so that user sees what failed)
  ; if both per-user and per-machine versions are installed, unistall the one
  ; that matches $MultiUser.InstallMode
  StrCpy $0 ""
  ${if} $HasCurrentModeInstallation = 1
    StrCpy $0 "$MultiUser.InstallMode"
  ${else}
    !if ${MULTIUSER_INSTALLMODE_ALLOW_BOTH_INSTALLATIONS} = 0
      ${if} $HasPerMachineInstallation = 1
        ; if there's no per-user installation, but there's per-machine installation, uninstall it
        StrCpy $0 "AllUsers"
      ${elseif} $HasPerUserInstallation = 1
        ; if there's no per-machine installation, but there's per-user installation, uninstall it
        StrCpy $0 "CurrentUser"
      ${endif}
    !endif
  ${endif}

  ${if} "$0" != ""
    ${if} $0 == "AllUsers"
      StrCpy $1 "$PerMachineUninstallString"
      StrCpy $3 "$PerMachineInstallationFolder"
    ${else}
      StrCpy $1 "$PerUserUninstallString"
      StrCpy $3 "$PerUserInstallationFolder"
    ${endif}
    ${if} ${silent}
      StrCpy $2 "/S"
    ${else}
      StrCpy $2 ""
    ${endif}

    HideWindow
    ClearErrors
    StrCpy $0 0
    ; $1 is quoted in registry; the _? param stops the uninstaller from copying
    ; itself to the temporary directory, which is the only way for ExecWait to work
    ExecWait '$1 /SS $2 _?=$3' $0

    ${if} ${errors} ; stay in installer
      SetErrorLevel 2 ; Installation aborted by script
      BringToFront
      Abort "Error executing uninstaller."
    ${else}
      ${Switch} $0
        ${Case} 0 ; uninstaller completed successfully - continue with installation
          BringToFront
          ${Break}
        ${Case} 1 ; Installation aborted by user (cancel button)
        ${Case} 2 ; Installation aborted by script
          SetErrorLevel $0
          Quit ; uninstaller was started, but completed with errors - Quit installer
        ${Default} ; all other error codes - uninstaller could not start, elevate, etc. - Abort installer
          SetErrorLevel $0
          BringToFront
          Abort "Error executing uninstaller."
      ${EndSwitch}
    ${endif}

    ; the uninstaller doesn't delete itself when not copied to the temp directory
    !insertmacro DeleteRetryAbort "$3\${UNINSTALL_FILENAME}"
    RMDir "$3"
  ${endif}

  ; Remove the old uninstaller if it's leftover
  IfFileExists "$INSTDIR\uninst.exe" 0 +2
  Delete "$INSTDIR\uninst.exe"

  SetOutPath $INSTDIR
  ; Write uninstaller and registry uninstall info as the first step,
  ; so that the user has the option to run the uninstaller if something goes wrong
  WriteUninstaller "${UNINSTALL_FILENAME}"
  ; or this if you're using signing:
  ; File "${UNINSTALL_FILENAME}"
  !insertmacro MULTIUSER_RegistryAddInstallInfo ; add registry keys
  ${if} ${silent} ; MUI doesn't write language in silent mode
    WriteRegStr "${MUI_LANGDLL_REGISTRY_ROOT}" "${MUI_LANGDLL_REGISTRY_KEY}" \
      "${MUI_LANGDLL_REGISTRY_VALUENAME}" $LANGUAGE
  ${endif}

  File /r "${DIST_DIR}\*.*"
SectionEnd

SectionGroup /e "System Integration" SectionGroupIntegration

Section "Register with Windows" SectionWindowsRegister
  SectionIn 1 2

  ; No HKCU support for Windows versions earlier than Win8
  ${if} $MultiUser.InstallMode == "AllUsers"
  ${orif} ${AtLeastWin8}
    ;StartMenuInternet
    StrCpy $0 "$INSTDIR\${PROGEXE}"
    System::Call 'kernel32::GetLongPathNameW(t r0, t .r1, i ${NSIS_MAX_STRLEN}) i .r2'

    StrCpy $0 "SOFTWARE\Clients\StartMenuInternet\${PRODUCT_NAME}"

    WriteRegStr SHCTX "$0" "" "${PRODUCT_NAME}"

    WriteRegStr SHCTX "$0\DefaultIcon" "" "$1,0"

    WriteRegDWORD SHCTX "$0\InstallInfo" "IconsVisible" 1

    WriteRegStr SHCTX "$0\shell\open\command" "" "$\"$1$\""

    WriteRegStr SHCTX "$0\shell\properties" "" "${PRODUCT_NAME} settings"
    WriteRegStr SHCTX "$0\shell\properties\command" "" "$\"$1$\" ${SHELL_PROPERTIES}"

    WriteRegStr SHCTX "$0\shell\safemode" "" "${PRODUCT_NAME} safe mode"
    WriteRegStr SHCTX "$0\shell\safemode\command" "" "$\"$1$\" ${SHELL_SAFEMODE}"

    WriteRegStr SHCTX "$0\Capabilities" "ApplicationDescription" "${COMMENTS}"
    WriteRegStr SHCTX "$0\Capabilities" "ApplicationIcon" "$1,0"
    WriteRegStr SHCTX "$0\Capabilities" "ApplicationName" "${PRODUCT_NAME}"

    WriteRegStr SHCTX "$0\Capabilities\FileAssociations" ".htm" "${PRODUCT_NAME}HTML"
    WriteRegStr SHCTX "$0\Capabilities\FileAssociations" ".html" "${PRODUCT_NAME}HTML"
    WriteRegStr SHCTX "$0\Capabilities\FileAssociations" ".shtml" "${PRODUCT_NAME}HTML"
    WriteRegStr SHCTX "$0\Capabilities\FileAssociations" ".svg" "${PRODUCT_NAME}HTML"
    WriteRegStr SHCTX "$0\Capabilities\FileAssociations" ".xht" "${PRODUCT_NAME}HTML"
    WriteRegStr SHCTX "$0\Capabilities\FileAssociations" ".xhtml" "${PRODUCT_NAME}HTML"
    WriteRegStr SHCTX "$0\Capabilities\FileAssociations" ".webp" "${PRODUCT_NAME}HTML"

    WriteRegStr SHCTX "$0\Capabilities\StartMenu" "StartMenuInternet" "${PRODUCT_NAME}"

    WriteRegStr SHCTX "$0\Capabilities\URLAssociations" "ftp" "${PRODUCT_NAME}URL"
    WriteRegStr SHCTX "$0\Capabilities\URLAssociations" "http" "${PRODUCT_NAME}URL"
    WriteRegStr SHCTX "$0\Capabilities\URLAssociations" "https" "${PRODUCT_NAME}URL"

    ; Register Application
    WriteRegStr SHCTX "SOFTWARE\RegisteredApplications" "${PRODUCT_NAME}" "$0\Capabilities"

    ; Associate file types
    WriteRegStr SHCTX "SOFTWARE\Classes\.htm\OpenWithProgids" "${PRODUCT_NAME}HTML" ""
    WriteRegStr SHCTX "SOFTWARE\Classes\.html\OpenWithProgids" "${PRODUCT_NAME}HTML" ""
    WriteRegStr SHCTX "SOFTWARE\Classes\.shtml\OpenWithProgids" "${PRODUCT_NAME}HTML" ""
    WriteRegStr SHCTX "SOFTWARE\Classes\.svg\OpenWithProgids" "${PRODUCT_NAME}HTML" ""
    WriteRegStr SHCTX "SOFTWARE\Classes\.xht\OpenWithProgids" "${PRODUCT_NAME}HTML" ""
    WriteRegStr SHCTX "SOFTWARE\Classes\.xhtml\OpenWithProgids" "${PRODUCT_NAME}HTML" ""
    WriteRegStr SHCTX "SOFTWARE\Classes\.webp\OpenWithProgids" "${PRODUCT_NAME}HTML" ""

    ; HTML and URL handlers
    StrCpy $2 "${PRODUCT_NAME}HTML"
    StrCpy $3 "${PRODUCT_NAME} HTML Document"
    WriteRegHandler:
    WriteRegStr SHCTX "SOFTWARE\Classes\$2" "" "$3"
    WriteRegStr SHCTX "SOFTWARE\Classes\$2" "FriendlyTypeName" "$3"
    WriteRegDWord SHCTX "SOFTWARE\Classes\$2" "EditFlags" 0x00000002
    WriteRegStr SHCTX "SOFTWARE\Classes\$2\DefaultIcon" "" "$1,0"
    WriteRegStr SHCTX "SOFTWARE\Classes\$2\shell" "" "open"
    WriteRegStr SHCTX "SOFTWARE\Classes\$2\shell\open\command" "" "$\"$1$\" $\"%1$\""
    WriteRegStr SHCTX "SOFTWARE\Classes\$2\shell\open\ddeexec" "" ""
    StrCmp "$2" "${PRODUCT_NAME}HTML" 0 +4
    StrCpy $2 "${PRODUCT_NAME}URL"
    StrCpy $3 "${PRODUCT_NAME} URL"
    Goto WriteRegHandler
    WriteRegStr SHCTX "SOFTWARE\Classes\$2" "URL Protocol" ""
  ${endif}
SectionEnd

Section /o "Set as default browser" SectionDefaultBrowser
  SectionIn 1

  ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" "ProgId"
  ReadRegStr $1 HKCU "SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" "ProgId"
  ReadRegStr $2 HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.htm\UserChoice" "ProgId"
  ReadRegStr $3 HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice" "ProgId"
  ${ifnot} $0 == "${PRODUCT_NAME}URL"
  ${orifnot} $1 == "${PRODUCT_NAME}URL"
  ${orifnot} $2 == "${PRODUCT_NAME}HTML"
  ${orifnot} $3 == "${PRODUCT_NAME}HTML"
    ${if} ${AtLeastWin10}
      ExecShell "open" "ms-settings:defaultapps"
    ${elseif} ${AtLeastWin8}
      ExecShell "open" "control.exe" "/name Microsoft.DefaultPrograms /page \
        pageDefaultProgram\pageAdvancedSettings?pszAppName=${PRODUCT_NAME}"
    ${else}
      StrCmp $0 "${PRODUCT_NAME}URL" +2 0
      WriteRegStr HKCU "SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" \
        "ProgId" "${PRODUCT_NAME}URL"
      StrCmp $1 "${PRODUCT_NAME}URL" +2 0
      WriteRegStr HKCU "SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" \
        "ProgId" "${PRODUCT_NAME}URL"
      StrCmp $2 "${PRODUCT_NAME}HTML" +3 0
      DeleteRegKey HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.htm\UserChoice"
      WriteRegStr HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.htm\UserChoice" \
        "ProgId" "${PRODUCT_NAME}HTML"
      StrCmp $3 "${PRODUCT_NAME}HTML" +3 0
      DeleteRegKey HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice"
      WriteRegStr HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice" \
        "ProgId" "${PRODUCT_NAME}HTML"
    ${endif}
  ${endif}
SectionEnd

SectionGroupEnd

SectionGroup "Shortcuts" SectionGroupShortcuts

Section "Dektop Icon" SectionDesktopIcon
  SectionIn 1 2

  !insertmacro MULTIUSER_GetCurrentUserString $0
  CreateShortCut "$DESKTOP\${PRODUCT_NAME}$0.lnk" "$INSTDIR\${PROGEXE}"
SectionEnd

Section "Start Menu Icon" SectionStartMenuIcon
  SectionIn 1 2

  !insertmacro MULTIUSER_GetCurrentUserString $0
  CreateShortCut "$STARTMENU\${PRODUCT_NAME}$0.lnk" "$INSTDIR\${PROGEXE}"
SectionEnd

SectionGroupEnd

Section "-Write Install Info" ; hidden section, write install info as the final step
  !insertmacro MULTIUSER_RegistryAddInstallSizeInfo
  !insertmacro MULTIUSER_GetCurrentUserString $0
  WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY_PATH}$0" "HelpLink" "${HELP_LINK}"
  WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY_PATH}$0" "URLInfoAbout" "${URL_ABOUT}"
  WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY_PATH}$0" "URLUpdateInfo" "${URL_UPDATE}"
  WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY_PATH}$0" "Comments" "${COMMENTS}"
  WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY_PATH}$0" "Contact" "${CONTACT}"

  ; Add InstallDate String
  System::Call /NOUNLOAD '*(&i2,&i2,&i2,&i2,&i2,&i2,&i2,&i2) i .r9'
  System::Call /NOUNLOAD 'kernel32::GetLocalTime(i)i(r9)'
  System::Call /NOUNLOAD '*$9(&i2,&i2,&i2,&i2,&i2,&i2,&i2,&i2)i(.r1,.r2,.r3,.r4,.r5,.r6,.r7,)'
  System::Free $9
  IntCmp $2 9 0 0 +2
  StrCpy $2 '0$2'
  IntCmp $4 9 0 0 +2
  StrCpy $4 '0$4'
  WriteRegStr SHCTX "${MULTIUSER_INSTALLMODE_UNINSTALL_REGISTRY_KEY_PATH}$0" "InstallDate" "$1$2$4"

  ; Refresh Shell Icons
  System::Call "shell32::SHChangeNotify(i 0x08000000, i 0, i 0, i 0)"
SectionEnd

; Modern install component descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionCoreFiles} \
    "Core files required to run ${PRODUCT_NAME}."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionGroupIntegration} \
    "Integrate ${PRODUCT_NAME} with the Operating System."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionWindowsRegister} \
    "Register protocols and file extensions with ${PRODUCT_NAME}."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionDefaultBrowser} \
    "Set ${PRODUCT_NAME} as the default Web browser."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionGroupShortcuts} \
    "Create shortcut icons to run ${PRODUCT_NAME}."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionDesktopIcon} \
    "Create ${PRODUCT_NAME} icon on the Desktop."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionStartMenuIcon} \
    "Create ${PRODUCT_NAME} icon in the Start Menu."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; Callbacks
Function .onInit
  !insertmacro CheckPlatform ${PLATFORM}
  !insertmacro CheckMinWinVer ${MIN_WIN_VER}
  ${ifnot} ${UAC_IsInnerInstance}
    !insertmacro CheckSingleInstance "Setup" "Global" "${SETUP_MUTEX}"
    !insertmacro CheckSingleInstance "Application" "Local" "${APP_MUTEX}"
  ${endif}

  ; Detect existing setup from previous installers
  !insertmacro CheckOldNSIS
  !insertmacro MSI32_STACK
  !insertmacro CheckMSI
  ${if} $R1 == ""
  ${andif} ${RunningX64}
    SetRegView 64 ; Will be set again by MULTIUSER_INIT
    !insertmacro MSI64_STACK
    !insertmacro CheckMSI
  ${endif}
  ${if} $R0 != ""
  ${orif} $R1 != ""
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
      "An older version of ${PRODUCT_NAME} is already installed.$\r$\n$\r$\n\
      Click `OK` to remove the previous version and continue,$\r$\n\
      or `Cancel` to cancel this upgrade." \
      IDOK +2
    Abort
    ${if} $R0 != ""
      ${GetParent} $R0 $0
      ${GetFileName} $R0 $1
      ; Using cmd.exe for elevation to work
      !insertmacro RemoveOld "cmd.exe /c start /wait /d $\"$0$\" $1 /S _?=$0"
    ${endif}
    ${if} $R1 != ""
      !insertmacro RemoveOld "msiexec.exe /X$R1 /passive /promptrestart"
    ${endif}
  ${endif}

  !insertmacro MULTIUSER_INIT

  ${if} $IsInnerInstance = 0
    !insertmacro MUI_LANGDLL_DISPLAY
  ${endif}
FunctionEnd

Function .onSelChange
  ${if} ${SectionIsSelected} ${SectionDefaultBrowser}
    !insertmacro SetSectionFlag ${SectionWindowsRegister} ${SF_RO}
    !insertmacro SelectSection ${SectionWindowsRegister}
  ${else}
    !insertmacro ClearSectionFlag ${SectionWindowsRegister} ${SF_RO}
  ${endif}
FunctionEnd

Function PageWelcomeLicensePre
  ${if} $InstallShowPagesBeforeComponents = 0
    Abort ; don't display the Welcome and License pages for the inner instance
  ${endif}
FunctionEnd

Function PageInstallModeChangeMode
  ; Disable integration for single user install on Win7 and older, as it's not supported
  ${if} $MultiUser.InstallMode == "CurrentUser"
  ${andif} ${AtMostWin7}
    SectionSetText ${SectionGroupIntegration} "System Integration (not supported)"
    IntOP $0 ${SF_RO} & ${SECTION_OFF}
    SectionSetFlags ${SectionWindowsRegister} $0
    SectionSetFlags ${SectionDefaultBrowser} $0
    !insertmacro SetSectionFlag ${SectionGroupIntegration} ${SF_RO}
    !insertmacro ClearSectionFlag ${SectionGroupIntegration} ${SF_EXPAND}
  ${else}
    ; This is necessary because if the installer started under Win7/Vista as Administrator with UAC disabled,
    ; going back to All users after first selecting Single user, the integration component would still be disabled
    SectionSetText ${SectionGroupIntegration} "System Integration"
    !insertmacro ClearSectionFlag ${SectionWindowsRegister} ${SF_RO}
    !insertmacro ClearSectionFlag ${SectionDefaultBrowser} ${SF_RO}
    !insertmacro ClearSectionFlag ${SectionGroupIntegration} ${SF_RO}
    !insertmacro SetSectionFlag ${SectionGroupIntegration} ${SF_EXPAND}
    !insertmacro SelectSection ${SectionWindowsRegister}

    ; Select 'Default browser' if already set in registry
    ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" "ProgId"
    ${if} $0 == "${PRODUCT_NAME}URL"
      !insertmacro SetSectionFlag ${SectionWindowsRegister} ${SF_RO}
      !insertmacro SelectSection ${SectionDefaultBrowser}
    ${else}
      !insertmacro UnselectSection ${SectionDefaultBrowser}
    ${endif}
  ${endif}
FunctionEnd

Function PageDirectoryPre
  GetDlgItem $0 $HWNDPARENT 1
    SendMessage $0 ${WM_SETTEXT} 0 "STR:$(^InstallBtn)" ; this is the last page before installing
FunctionEnd

Function PageDirectoryShow
  ${if} $CmdLineDir != ""
    FindWindow $R1 "#32770" "" $HWNDPARENT

    GetDlgItem $0 $R1 1019 ; Directory edit
    SendMessage $0 ${EM_SETREADONLY} 1 0 ; read-only is better than disabled, as user can copy contents

    GetDlgItem $0 $R1 1001 ; Browse button
    EnableWindow $0 0
  ${endif}
FunctionEnd

Function PageFinishRun
  ; the installer might exit too soon before the application starts and it loses
  ; the right to be the foreground window and starts in the background
  ; however, if there's no active window when the application starts, it will
  ; become the active window, so we hide the installer
  HideWindow
  ; the installer will show itself again quickly before closing (w/o Taskbar button), we move it offscreen
  !define SWP_NOSIZE 0x0001
  !define SWP_NOZORDER 0x0004
  System::Call "User32::SetWindowPos(i, i, i, i, i, i, i) b \
    ($HWNDPARENT, 0, -1000, -1000, 0, 0, ${SWP_NOZORDER}|${SWP_NOSIZE})"

  !insertmacro UAC_AsUser_ExecShell "open" "$INSTDIR\${PROGEXE}" "" "$INSTDIR" ""
FunctionEnd

Function .onInstFailed
  MessageBox MB_ICONSTOP \
    "${PRODUCT_NAME} ${VERSION} could not be fully installed.$\r$\n\
    Please, restart Windows and run the setup program again." \
    /SD IDOK
FunctionEnd
