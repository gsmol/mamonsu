; check binary and config already installed, if true -> do not show dialog, only replace exe file 
; allow user to choose user-name

; Mamonsu install Script
; Written by Postgres Professional, Postgrespro.ru
; dba@postgrespro.ru
;--------------------------------
#!include "mamonsu.def.nsh"
!include Utf8Converter.nsh
!include MUI2.nsh
!include LogicLib.nsh
!include nsDialogs.nsh
!include TextFunc.nsh
!include NSISpcre.nsh
!insertmacro REMatches
;-------------------------------
;------------------------------
;macro
!define NAME Mamonsu
!define VERSION 0.4.1
!define EDB_REG "SOFTWARE\Postgresql"
!define PGPRO_REG_1C "SOFTWARE\Postgres Professional\PostgresPro 1C"
!define PGPRO_REG_32 "SOFTWARE\PostgresPro\X86"
!define PGPRO_REG_64 "SOFTWARE\PostgresPro\X64"
!define USER "mamonsu"
LangString PG_TITLE ${LANG_ENGLISH} "PostgreSQL"
LangString PG_SUBTITLE ${LANG_ENGLISH} "Server options of PostgreSQL instance you want to monitor"

LangString ZB_TITLE ${LANG_ENGLISH} "Zabbix"
LangString ZB_SUBTITLE ${LANG_ENGLISH} "Server options of Zabbix"
;--------------------------------


Name "${NAME} ${VERSION}"
OutFile "mamonsu.exe"
InstallDir "C:\mamonsu"
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
Var brand

Var zb_client
Var zb_client_input
Var zb_host
Var zb_address
Var zb_address_input
Var zb_port
Var zb_port_input
Var zb_conf
Var img_path
;-----------------------------------------
;General
RequestExecutionLevel admin

!insertmacro MUI_PAGE_WELCOME ;need some some_file as argument
;!insertmacro MUI_PAGE_LICENSE ;"License.txt"
!insertmacro MUI_PAGE_COMPONENTS ; 
!insertmacro MUI_PAGE_DIRECTORY

Page custom CheckVars ; check pre_ConfPage variables
Page custom CheckVarsZB
Page custom DefaultConf
Page custom PG_Page InputData ;+ ConfigurationPageLeave ; we must save them
Page custom ZB_Page InputDataZB

!insertmacro MUI_PAGE_STARTMENU Application $StartMenuDir ; we need 'Application' for desc
;add READY to install
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

;Lang
!insertmacro MUI_LANGUAGE "English"

;!insertmacro MUI_UNPAGE_WELCOME
;!insertmacro MUI_UNPAGE_CONFIRM
;!insertmacro MUI_UNPAGE_INSTFILES
;!insertmacro MUI_UNPAGE_FINISH


;-----------------------------------------------
;Sections 
Section "Microsoft Visual C++ 2010 Redistibutable" sectionMS ; we need section number 1 for description
  ;we install here tumtime to destination system
SectionEnd

Section "${NAME} ${VERSION}" section1 ; we need section number 2 for desc
  SetOutPath "$INSTDIR" ; install binary to directory on target machine
  File "agent.exe" ; pick that file and pack it to installer
 
  ;StartMenu stuff
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
  CreateDirectory "$SMPROGRAMS\$StartMenuDir"
  CreateShortcut "$SMPROGRAMS\$StartMenuDir\mamonsu.lnk" "$INSTDIR\agent.exe"
  !insertmacro MUI_STARTMENU_WRITE_END

  ;installation procedure
  ;check if user ${USER} exist, create if not
  
  UserMgr::CreateAccountEx "${USER}" "23109jdlksajlhuhf894jdYe" "${USER}" "${USER}" "${USER}" "UF_PASSWD_NOTREQD"
  Pop $0
  DetailPrint "CreateUser Result : $0"
  MessageBox MB_OK "test"
 

  ;create file, write there user-defined stuff
  ${AnsiToUtf8} $pg_password $2
  GetTempFileName $1
   FileOpen $0 $1 w
   FileWrite $0 '[zabbix]$\r$\nclient = $zb_client$\r$\naddress = $zb_address$\r$\n\
port = $zb_port$\r$\nbinary_log = None$\r$\n$\r$\n\
[postgres]$\r$\nuser = $pg_user$\r$\ndatabase = $pg_db$\r$\npassword = $2$\r$\n\
host = $pg_host$\r$\nport = $pg_port$\r$\napplication_name = mamonsu$\r$\n'
   FileClose $0

  Rename $1 "$INSTDIR\agent.conf"

AccessControl::DisableFileInheritance "$INSTDIR"
  Pop $0 ; "error" on errors
  ;DetailPrint "Change file owner to ${USER} : $0"
  MessageBox MB_OK "$0"

;set directory ownership to ${USER}
AccessControl::SetFileOwner "$INSTDIR" "${USER}"
  Pop $0 ; "error" on errors
  ;DetailPrint "Change file owner to ${USER} : $0"
  MessageBox MB_OK "$0"

AccessControl::SetFileOwner "$INSTDIR\agent.exe" "${USER}"
  Pop $0 ; "error" on errors
  ;DetailPrint "Change file owner to ${USER} : $0"
  MessageBox MB_OK "$0"

AccessControl::SetFileOwner "$INSTDIR\agent.conf" "${USER}"
  Pop $0 ; "error" on errors
  ;DetailPrint "Change file owner to ${USER} : $0"
  MessageBox MB_OK "$0"

;revoke Users
AccessControl::RevokeOnFile "$INSTDIR" "(S-1-5-32-545)" "FullAccess"
  Pop $0 ; "error" on errors
  ;DetailPrint "Change file owner to ${USER} : $0"
  MessageBox MB_OK "$0"

 ;create registry entry

 WriteRegExpandStr HKLM "Software\PostgresPro\Mamonsu" "Version" "${VERSION}"
 WriteRegExpandStr HKLM "Software\PostgresPro\Mamonsu" "User" "${USER}"
 WriteRegExpandStr HKLM "Software\PostgresPro\Mamonsu" "InstallDir" "${INSTDIR}"
 WriteRegExpandStr HKLM "Software\PostgresPro\Mamonsu" "ConfigFile" "${INSTDIR}\agent.conf"

 ;create service
SectionEnd




;------------------------------------------
;Functions

Function CheckVars

; check EDB installation
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


Function CheckVarsZB
 ; check zabbix agent installation
 ReadRegStr $zb_client HKLM "System\CurrentControlSet\Control\ComputerName\ActiveComputerName" "ComputerName"
 ReadRegStr $img_path HKLM "System\CurrentControlSet\Services\Zabbix Agent" "ImagePath"

 ;  !insertmacro CreateUser "\\$zb_client" "jdoe" "pkjqgbhj;tyrf1488" "Some User" "John" "Doe" 545
 ;  Pop $0
 ;  MessageBox MB_OK "$0"


 ${If} $img_path == ''
   ;MessageBox MB_OK "No zabbix agent instalation found"
   Abort
 ${EndIf}

 MessageBox MB_OK "$img_path"
 StrCpy $0 ''
 StrCpy $1 ''
 ${RECaptureMatches} $0 '^.* --config \"(.+.conf)\"(.*)?' $img_path 1 ; 1 - partial string match
 Pop $1
 StrCpy $zb_conf $1
 ;MessageBox MB_OK "$zb_conf"


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

${If} $brand == ''
 ; MessageBox MB_OK "Failed to locate installed PostgreSQL"
${EndIf}

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
;MessageBox MB_OK "$pg_port $pg_user $pg_version $pg_datadir $brand $pg_service $zb_client"

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
  ${NSD_GetText} $zb_address_input $zb_address
  ${NSD_GetText} $zb_port_input $zb_port
  ${NSD_GetText} $zb_client_input $zb_client

FunctionEnd
