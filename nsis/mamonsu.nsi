;update procedure:
; check binary and config already installed, if true -> do not show directory dialog, stop service, 
; check that service is stopped, check version via registry, replace exe file, change registry key,
; start service, check that service is started

;write in registry only if installation successfull

; create uninstall procedure
; generate template and Inform User that he must import it in zabbix

; Mamonsu install Script
; Written by Postgres Professional, Postgrespro.ru
; dba@postgrespro.ru
;--------------------------------
!include "mamonsu.def.nsh"
!include Utf8Converter.nsh
!include MUI2.nsh
!include LogicLib.nsh
!include nsDialogs.nsh
!include TextFunc.nsh
!include NSISpcre.nsh
!insertmacro REMatches
;-------------------------------
;--------------------------------


Name "${NAME} ${VERSION}"
OutFile "mamonsu.exe"
InstallDir "$PROGRAMFILES32\${NAME}"
BrandingText "Postgres Professional"


;--------------------
Var StartMenuDir
;--------------------

Var Dialog
Var Label

Var pg_host
Var pg_host_input
Var pg_port
Var pg_port_input
Var pg_db
Var pg_db_input
Var pg_user
Var pg_user_input
Var pg_password
Var pg_password_input
Var pg_version
Var pg_datadir
Var pg_service

Var zb_client
Var zb_client_input
Var zb_host
Var zb_address
Var zb_address_input
Var zb_port
Var zb_port_input
Var zb_conf
Var img_path
Var hostname
Var reinstall
Var brand
Var user_password
Var user_not_exist

;----------------------------------------


;General
RequestExecutionLevel admin


!insertmacro MUI_PAGE_WELCOME ;need some some_file as argument
!insertmacro MUI_PAGE_COMPONENTS 
!define MUI_PAGE_CUSTOMFUNCTION_PRE CheckMamonsu ; Important!
!insertmacro MUI_PAGE_DIRECTORY

Page custom CheckPG ; check pre_ConfPage variables
Page custom CheckZB
Page custom DefaultConf
Page custom PG_Page InputData ;+ ConfigurationPageLeave ; we must save them
Page custom ZB_Page InputDataZB

;!insertmacro MUI_PAGE_STARTMENU Application $StartMenuDir ; we need 'Application' for desc
!insertmacro MUI_PAGE_INSTFILES
; Finish page
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_FINISHPAGE_SHOWREADME_TEXT "show config"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\agent.conf"
!insertmacro MUI_PAGE_FINISH


!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!define MUI_UNFINISHPAGE_NOAUTOCLOSE
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"
;-----------------------------------------------


;Sections 
Section "Microsoft Visual C++ 2010 Redistibutable" sectionMS ; we need section number 1 for description
 GetTempFileName $1
  File /oname=$1 vcredist\vcredist_x86_2010.exe
  ExecWait "$1  /passive /norestart" $0
  DetailPrint "Visual C++ Redistributable Packages return $0"
  Delete $1
SectionEnd

Section "${NAME} ${VERSION}" section1 ; we need section number 2 for desc
 
  ;StartMenu stuff, need to create links to start/stop service
#  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
#  CreateDirectory "$SMPROGRAMS\$StartMenuDir"
#  CreateShortcut "$SMPROGRAMS\$StartMenuDir\mamonsu.lnk" "$INSTDIR\service.exe"
#  !insertmacro MUI_STARTMENU_WRITE_END

 ;installation procedure

 ; stop service
 ${if} $reinstall == 'true'
   Call StopService
 ${endif}
 
 SetOutPath "$INSTDIR" ; install binary to directory on target machine
 File "..\win\${VERSION}\service.exe" ; pick that file and pack it to installer
 File "..\win\${VERSION}\agent.exe" 
 WriteUninstaller "$INSTDIR\Uninstall.exe"

 ;create user
 Call CreateUser
 ;create agent.conf
 Call CreateConfig
 ;create service
 Call CreateService
 ;create mamonsu registry entry 
 Call CreateReg
 ;start service
 Call StartService
SectionEnd

Section "Uninstall"
;  Call un.CheckExist
  Call un.DeleteService
  Call un.DeleteUser
  RMDir /r "$INSTDIR"
  Call un.DeleteReg 
SectionEnd

;------------------------------------------
;Functions

Function CheckMamonsu
 ; if we abort from this function, next Page will be skipped
 ;check registry
 SetRegView 64
 ReadRegStr $0 HKLM ${MAMONSU_REG_PATH} "ConfigFile"
  ${if} $0 != ''
    ReadRegStr $1 HKLM "${MAMONSU_REG_PATH}" "Version"
    ${if} ${FileExists} $0 ; if config file exist => reinstall
      StrCpy $reinstall 'true'
      MessageBox MB_YESNO  "Mamonsu version $1 is already installed. Continue?" IDYES continue IDNO quit
      continue:
      Abort
      quit:
      Quit
    ${endif}
  ${endif} 
FunctionEnd


Function CheckPG
 ; check EDB installation
 ${if} $reinstall == 'true'
 Abort
 ${endif}
SetRegView 64
EnumRegKey $1 HKLM "${EDB_REG}\Installations" 0
${If} $1 != ''
  ReadRegStr $pg_version HKLM "${EDB_REG}\Installations\$1" "Version"
  ReadRegStr $pg_datadir HKLM "${EDB_REG}\Installations\$1" "Data Directory"
  ReadRegStr $pg_service HKLM "${EDB_REG}\Installations\$1" "Service ID"
  ReadRegStr $pg_user HKLM "${EDB_REG}\Installations\$1" "Super User"
${If} $pg_version != ''
    StrCpy $brand "EDB"
    ReadRegDWORD $pg_port HKLM "${EDB_REG}\Services\$1" "Port"
    Abort
  ${EndIf}
${EndIf}

;check PostgresPro 1C
SetRegView 32
EnumRegKey $1 HKLM "${PGPRO_REG_1C}\Installations" 0
${If} $1 != ''
  ReadRegStr $pg_version HKLM "${PGPRO_REG_1C}\Installations\$1" "Version"
  ReadRegStr $pg_datadir HKLM "${PGPRO_REG_1C}\Installations\$1" "Data Directory"
  ReadRegStr $pg_service HKLM "${PGPRO_REG_1C}\Installations\$1" "Service ID"
  ReadRegStr $pg_user HKLM "${PGPRO_REG_1C}\Installations\$1" "Super User"
${If} $pg_version != ''
    StrCpy $brand "PRO-1C"
    ReadRegDWORD $pg_port HKLM "${PGPRO_REG_1C}\Services\$1" "Port"
    Abort
  ${EndIf}
${EndIf}

; check PostgresPro 32bit
SetRegView 32
EnumRegKey $1 HKLM "${PGPRO_REG_32}" 0
${If} $1 != ''
  EnumRegKey $2 HKLM "${PGPRO_REG_32}\$1\Installations" 0
  ReadRegStr $pg_version HKLM "${PGPRO_REG_32}\$1\Installations\$2" "Version"
  ReadRegStr $pg_datadir HKLM "${PGPRO_REG_32}\$1\Installations\$2" "Data Directory"
  ReadRegStr $pg_service HKLM "${PGPRO_REG_32}\$1\Installations\$2" "Service ID"
  ReadRegStr $pg_user HKLM "${PGPRO_REG_32}\$1\Installations\$2" "Super User"
${If} $pg_version != ''
    StrCpy $brand "PRO-32"
    ReadRegDWORD $pg_port HKLM "${PGPRO_REG_32}\$1\Services\$2" "Port"
    Abort
  ${EndIf}
${EndIf}

;check PostgresPro 64bit
SetRegView 32
EnumRegKey $1 HKLM "${PGPRO_REG_64}" 0
${If} $1 != ''
  EnumRegKey $2 HKLM "${PGPRO_REG_64}\$1\Installations" 0
  ReadRegStr $pg_version HKLM "${PGPRO_REG_64}\$1\Installations\$2" "Version"
  ReadRegStr $pg_datadir HKLM "${PGPRO_REG_64}\$1\Installations\$2" "Data Directory"
  ReadRegStr $pg_service HKLM "${PGPRO_REG_64}\$1\Installations\$2" "Service ID"
  ReadRegStr $pg_user HKLM "${PGPRO_REG_64}\$1\Installations\$2" "Super User"
  ${If} $pg_version != ''
    StrCpy $brand "PRO-64"
    ReadRegDWORD $pg_port HKLM "${PGPRO_REG_64}\$1\Services\$2" "Port"
    Abort
  ${EndIf}
${EndIf}
FunctionEnd


Function CheckZB
 ; check zabbix agent installation
  ${if} $reinstall == 'true'
 Abort
 ${endif}
 ReadRegStr $zb_client HKLM "System\CurrentControlSet\Control\ComputerName\ActiveComputerName" "ComputerName"
 ReadRegStr $hostname HKLM "System\CurrentControlSet\Control\ComputerName\ActiveComputerName" "ComputerName"
 ReadRegStr $img_path HKLM "System\CurrentControlSet\Services\Zabbix Agent" "ImagePath"

 ${If} $img_path == ''
   ;MessageBox MB_OK "No zabbix agent instalation found"
   Abort
 ${EndIf}

 StrCpy $0 ''
 StrCpy $1 ''
 ${RECaptureMatches} $0 '^.* --config \"(.+.conf)\"(.*)?' $img_path 1 ; 1 - partial string match
 Pop $1
 StrCpy $zb_conf $1

 StrCpy $0 ''
 StrCpy $1 ''
 StrCpy $2 ''
 ${ConfigRead} "$zb_conf" "ServerActive=" $zb_host
 ${RECaptureMatches} $0 "([a-z0-9.]+):?(\d+)?" $zb_host 0 ; 0 - full string match
 ${If} $0 == 'false'
   Abort
 ${EndIf}
 Pop $1
 Pop $2
 StrCpy $zb_address $1
 StrCpy $zb_port $2
FunctionEnd


Function DefaultConf
 ${if} $reinstall == 'true'
 Abort
 ${endif}

StrCpy $0 ''
StrCpy $1 ''
${If} $pg_datadir != ''
  ;TODO check if file EXIST 
  ${ConfigRead} "$pg_datadir\postgresql.conf" "listen_addresses = " $pg_host
  ${RECaptureMatches} $0 "^\'(.+)\'" $pg_host 1 ; match goes to $1
  Pop $1
  StrCpy $pg_host $1
;  MessageBox MB_OK "$pg_host"
${EndIf}

${If} $pg_host == 'localhost'
${OrIf} $pg_host == ''
  StrCpy $pg_host '127.0.0.1'
${EndIf}

${If} $pg_port == ''
  StrCpy $pg_port "5432"
${EndIf}
${If} $pg_user == ''
  StrCpy $pg_user "postgres"
${EndIf}

StrCpy $pg_db $pg_user

; zabbix
${If} $zb_address == 'localhost'
${OrIf} $zb_address == ''
  StrCpy $zb_address '127.0.0.1'
${EndIf}

${If} $zb_port == ''
  StrCpy $zb_port '10051'
${EndIf}
FunctionEnd


Function PG_Page
 ${if} $reinstall == 'true'
 Abort
 ${endif}

  !insertmacro MUI_HEADER_TEXT $(PG_TITLE) $(PG_SUBTITLE)
  nsDialogs::Create 1018
  Pop $Dialog

  ${If} $Dialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 2u 60u 12u "PostgreSQL host"
  Pop $Label
  ${NSD_CreateText}  65u 0 100u 12u "$pg_host"
  Pop $pg_host_input

  ${NSD_CreateLabel} 0 22u 60u 12u "PostgreSQL port"
  Pop $Label
  ${NSD_CreateText}  65u 20u 100u 12u "$pg_port"
  Pop $pg_port_input

  ${NSD_CreateLabel} 0 42u 60u 12u "PostgreSQL user"
  Pop $Label
  ${NSD_CreateText}  65u 40u 100u 12u "$pg_user"
  Pop $pg_user_input

  ${NSD_CreateLabel} 0 62u 60u 12u "PostgreSQL db"
  Pop $Label
  ${NSD_CreateText}  65u 60u 100u 12u "$pg_db"
  Pop $pg_db_input

  ${NSD_CreateLabel} 0 82u 60u 12u "Password"
  Pop $Label
  ${NSD_CreatePassword} 65u 80u 100u 12u ""
  Pop $pg_password_input


  nsDialogs::Show
FunctionEnd


Function InputData
 ${if} $reinstall == 'true'
 Abort
 ${endif}

  ${NSD_GetText} $pg_host_input $pg_host
  ${NSD_GetText} $pg_port_input $pg_port
  ${NSD_GetText} $pg_user_input $pg_user
  ${NSD_GetText} $pg_db_input $pg_db
  ${NSD_GetText} $pg_password_input $pg_password

${If} $pg_password = ''
StrCpy $pg_password 'None' 
${EndIf}  
FunctionEnd


Function ZB_Page
 ${if} $reinstall == 'true'
 Abort
 ${endif}

  !insertmacro MUI_HEADER_TEXT $(ZB_TITLE) $(ZB_SUBTITLE)
  nsDialogs::Create 1018
  Pop $Dialog

  ${If} $Dialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 2u 60u 12u "Zabbix host"
  Pop $Label
  ${NSD_CreateText}  65u 0 100u 12u "$zb_address"
  Pop $zb_address_input

  ${NSD_CreateLabel} 0 22u 60u 12u "Zabbix port"
  Pop $Label
  ${NSD_CreateText}  65u 20u 100u 12u "$zb_port"
  Pop $zb_port_input

  ${NSD_CreateLabel} 0 42u 60u 12u "Client name"
  Pop $Label
  ${NSD_CreateText}  65u 40u 100u 12u "$zb_client"
  Pop $zb_client_input

  nsDialogs::Show
FunctionEnd


Function InputDataZB
 ${if} $reinstall == 'true'
 Abort
 ${endif}

  ${NSD_GetText} $zb_address_input $zb_address
  ${NSD_GetText} $zb_port_input $zb_port
  ${NSD_GetText} $zb_client_input $zb_client
FunctionEnd


Function CreateUser
  DetailPrint "Checking user ..."  
  UserMgr::GetUserInfo "${USER}" "EXISTS"
  Pop $0
  ${If} $0 == 'OK'
    DetailPrint "Result: exist"
    ; if user exist, but service is not, we must recreate user and create service
    ; ${if}
    goto cancel
#    DetailPrint "Deleting existing user ..."
#    UserMgr::DeleteAccount "${USER}"
#    Pop $0
#    DetailPrint "Result: $0"
  ${Else}
    DetailPrint "Result: do not exist"
    ${if} $reinstall == 'true'
    StrCpy $user_not_exist 'true'
    ${endif}   
  ${EndIf}

  ; generate entropy
  pwgen::GeneratePassword 32
  Pop $0
  StrCpy $user_password $0
  
  DetailPrint "Create user ..."
  UserMgr::CreateAccountEx "${USER}" "$user_password" "${USER}" "${USER}" "${USER}" "UF_PASSWD_NOTREQD|UF_DONT_EXPIRE_PASSWD"
  Pop $0
  DetailPrint "CreateUser Result : $0"

  DetailPrint "Add privilege to user ..."
  UserMgr::AddPrivilege "${USER}" "SeServiceLogonRight"
  Pop $0
  DetailPrint "AddPrivilege Result: $0"

  DetailPrint "Add user ${USER} to Performance Logs User Group ..."
  UserMgr::AddToGroup "${USER}" "Performance Log Users" ; Performance Logs User Group to collect cpu/memory metrics
  Pop $0
  DetailPrint "AddToGroup Result: $0"
  cancel:
FunctionEnd

Function CreateConfig
 ${if} $reinstall == 'true'
 goto cancel
 ${endif}

  ${AnsiToUtf8} $pg_password $2
  GetTempFileName $1
   FileOpen $0 $1 w
   FileWrite $0 '[zabbix]$\r$\nclient = $zb_client$\r$\naddress = $zb_address$\r$\nport = $zb_port$\r$\nbinary_log = None$\r$\n$\r$\n\
[postgres]$\r$\nuser = $pg_user$\r$\ndatabase = $pg_db$\r$\npassword = $2$\r$\n\
host = $pg_host$\r$\nport = $pg_port$\r$\napplication_name = mamonsu$\r$\n'
   FileClose $0

 Rename $1 "$INSTDIR\agent.conf"

 AccessControl::DisableFileInheritance "$INSTDIR"
 Pop $0 ; "error" on errors

 ;set directory ownership to ${USER}
 AccessControl::SetFileOwner "$INSTDIR" "${USER}"
 Pop $0 ; "error" on errors
 DetailPrint "Change file owner to ${USER} : $0"
 AccessControl::GrantOnFile "$INSTDIR" "(S-1-3-0)" "FullAccess" ; S-1-3-0 - owner

 AccessControl::SetFileOwner "$INSTDIR\service.exe" "${USER}"
 Pop $0 ; "error" on errors
 AccessControl::GrantOnFile "$INSTDIR\service.exe" "(S-1-3-0)" "FullAccess"

 AccessControl::SetFileOwner "$INSTDIR\agent.conf" "${USER}"
 Pop $0 ; "error" on errors
 AccessControl::GrantOnFile "$INSTDIR\agent.conf" "(S-1-3-0)" "FullAccess"

 ;revoke Users
 AccessControl::RevokeOnFile "$INSTDIR" "(S-1-5-32-545)" "FullAccess"
 Pop $0 ; "error" on errors
 cancel:   
FunctionEnd

Function CreateReg
 ${if} $reinstall == 'true'
   SetRegView 32
   WriteRegExpandStr HKLM "${MAMONSU_REG_PATH}" "Version" "${VERSION}"
   goto cancel
 ${endif}
 SetRegView 32
 WriteRegExpandStr HKLM "${MAMONSU_REG_PATH}" "Version" "${VERSION}"
 WriteRegExpandStr HKLM "${MAMONSU_REG_PATH}" "User" "${USER}"
 WriteRegExpandStr HKLM "${MAMONSU_REG_PATH}" "InstallDir" "$INSTDIR"
 WriteRegExpandStr HKLM "${MAMONSU_REG_PATH}" "ConfigFile" "$INSTDIR\agent.conf"

 WriteRegExpandStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "DisplayName" "${NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "Publisher" "Postgres Professional"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "HelpLink" "http://github.com/postgrespro/mamonsu"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "Comments" "Packaged by PostgresPro.ru"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}" "UrlInfoAbout" "http://github.com/postgrespro/mamonsu"
  cancel:
FunctionEnd

Function CreateService
 ${if} $reinstall == 'true'
   SimpleSC::ExistsService "${SERVICE_NAME}"
   Pop $0
   ${if} $0 == 0 ; service exist  
     DetailPrint "Service already exist"
      ${if} $user_not_exist == 'true' ; service exist and user was recreated, we forced to drop and recreate service
       DetailPrint "User was recreated so we forced to recreate service"
       DetailPrint "Removing service ..."
       SimpleSC::RemoveService "${SERVICE_NAME}"
       Pop $0 
        ${if} $0 == 0 ; service deleted
          DetailPrint "Result RemoveService: ok"
        ${else}
          DetailPrint "Result RemoveService: error"
        ${endIf}
     ${else} ; service exist but user was not recreated, so its ok to exit
       DetailPrint "Service exist and user was not recreated, so its ok to use existing service"
       goto cancel
     ${endif}
    ${endif}
  ${endif} 
 DetailPrint "Creating service ${SERVICE_NAME} ... "
 DetailPrint '"$INSTDIR\service.exe" --username "$hostname\${USER}" --password "$user_password" --startup delayed install"'
 nsExec::ExecToStack /TIMEOUT=10000 '"$INSTDIR\service.exe" --username "$hostname\${USER}" --password "$user_password" --startup delayed install'
 Pop $0
 Pop $1
 ${if} $0 == 'error'
   DetailPrint "Result: error"
   DetailPrint "$1"
 ${elseif} $0 == 0
   DetailPrint "Result: ok"
 ${endif}
 cancel:
FunctionEnd

Function StopService
 DetailPrint "Stoping service ${SERVICE_NAME} ... "
 nsExec::ExecToStack /TIMEOUT=10000 'net stop mamonsu'
 Pop $0
 Pop $1
 ${if} $0 == 'error'
   DetailPrint "Result: error"
   DetailPrint "$1"
 ${elseif} $0 == 0
   DetailPrint "Result: ok"
 ${endif}
FunctionEnd
 
Function StartService
 DetailPrint "Starting service ${SERVICE_NAME} ... "
 nsExec::ExecToStack /TIMEOUT=10000 'net start mamonsu'
 Pop $0
 Pop $1

 ${if} $0 == 'timeout'
   DetailPrint "Result: $0"  
 ${elseif} $0 == 0
   DetailPrint "Result: ok"
 ${elseif} $0 == 'error'
   DetailPrint "Result: $0"
   DetailPrint "$1"
 ${endif}
FunctionEnd
;----------------------------------------------
; Uninstall functions

;Function un.CheckExist
;FunctionEnd

Function un.DeleteService
  DetailPrint "Stoping service mamonsu ..."
  nsExec::ExecToStack /TIMEOUT=10000  'net stop mamonsu'
  Pop $0
  Pop $1
  ${if} $0 == 0
   DetailPrint "Result: ok"  
  ${elseif} $0 == 'timeout'
   DetailPrint "Result: $0"
   Abort
  ${elseif} $0 == 'error'
   DetailPrint "Result: $0"
   DetailPrint "$1"
   Abort
  ${endif}

  ;remove
  DetailPrint "Removing service mamonsu ..."
  nsExec::ExecToStack '"$INSTDIR\service.exe" remove'
  Pop $0
  Pop $1
  ${if} $0 == 0
    DetailPrint "Result: ok"  
  ${elseif} $0 == 'timeout'
    DetailPrint "Result: $0"
    Abort
  ${elseif} $0 == 'error'
    DetailPrint "Result: $0"
    DetailPrint "$1"
    Abort
  ${endif}
FunctionEnd

Function un.DeleteUser
  DetailPrint "Delete user ${USER} ..."
  UserMgr::DeleteAccount "${USER}"
  Pop $0
  DetailPrint "DeleteUser Result : $0"
FunctionEnd  

Function un.DeleteReg
DetailPrint "Delete registry entry ..."
SetRegView 32
DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}"
DeleteRegKey /ifempty HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}"

DeleteRegKey HKLM "${MAMONSU_REG_PATH}"
DeleteRegKey /ifempty HKLM "${MAMONSU_REG_PATH}"
FunctionEnd
