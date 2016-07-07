!define NAME Mamonsu
!define VERSION 0.5.1
!define MAMONSU_REG_PATH "Software\PostgresPro\Mamonsu"
!define EDB_REG "SOFTWARE\Postgresql"
!define PGPRO_REG_1C "SOFTWARE\Postgres Professional\PostgresPro 1C"
!define PGPRO_REG_32 "SOFTWARE\PostgresPro\X86"
!define PGPRO_REG_64 "SOFTWARE\PostgresPro\X64"
!define USER "mamonsu"

!define SERVICE_NAME "mamonsu"
!define SERVICE_DISPLAY_NAME "Zabbix monitoring agent: mamonsu"
!define SERVICE_TYPE "16"      ; service that runs in its own process 
!define SERVICE_START_TYPE "2" ; automatic start
!define SERVICE_DEPENDENCIES "EventLog"
!define SERVICE_DESCRIPTION "mamonsu service"

LangString PG_TITLE ${LANG_ENGLISH} "PostgreSQL"
LangString PG_SUBTITLE ${LANG_ENGLISH} "Server options of PostgreSQL instance you want to monitor"
LangString ZB_TITLE ${LANG_ENGLISH} "Zabbix"
LangString ZB_SUBTITLE ${LANG_ENGLISH} "Server options of Zabbix"
;LangString LOG_TITLE ${LANG_ENGLISH} "Mamonsu"
;LangString LOG_SUBTITLE ${LANG_ENGLISH} "Mamonsu log directory"