@echo off
REM ===========================================================================
REM  Illumio VEN Agent 自動部署腳本 — 方式二：手動安裝 (Batch)
REM  功能: 憑證匯入(防重複) + 自訂目錄安裝 + 自動啟用
REM  需要: 以系統管理員身分執行
REM ===========================================================================

setlocal enabledelayedexpansion

REM ==========================================
REM 設定區 (請依環境修改)
REM ==========================================
set "EXE_FILE=25.2.20-2018_illumio-ven-25.2.20-2018.win.x64.exe"
set "ACTIVATION_CODE=<YOUR_ACTIVATION_CODE>"
set "MANAGEMENT_SERVER=<YOUR_PCE_FQDN:PORT>"
set "INSTALL_DIR=C:\Program Files\Illumio"
set "DATA_DIR=C:\ProgramData\Illumio"
REM 部署日誌檔 (適用於 SCCM 靜默執行除錯)
set "LOG_FILE=%TEMP%\IllumioDeploy.log"
REM ==========================================

REM 將輸出同時導向到螢幕與檔案 (簡單做法: 建立 Log 函式)
call :Log ============================================
call :Log  Illumio VEN — 方式二：手動安裝 (Batch)
call :Log ============================================
call :Log.

REM === Step 1: 匯入憑證 ===
call :Log [Step 1/3] 檢查並匯入自簽 CA 憑證...

set "TEMP_CERT=%TEMP%\illumio-ca.crt"
(
-----BEGIN CERTIFICATE-----
PLACEHOLDER_CERTIFICATE_CONTENT_REPLACE_WITH_YOUR_ACTUAL_CERTIFICATE
-----END CERTIFICATE-----
) > "%TEMP_CERT%"

REM 從內嵌憑證動態計算 SHA1 Thumbprint (適用於任何環境更換憑證)
set "THUMBPRINT="
for /f "skip=1 delims=" %%A in ('certutil -hashfile "%TEMP_CERT%" SHA1') do (
    if not defined THUMBPRINT set "THUMBPRINT=%%A"
)
REM 去除空白字元
set "THUMBPRINT=!THUMBPRINT: =!"

if defined THUMBPRINT (
    certutil -verifystore Root "!THUMBPRINT!" >nul 2>&1
    if !errorlevel! equ 0 (
        call :Log [SKIP]   憑證已存在 ^(Thumbprint: !THUMBPRINT!^)，跳過匯入。
        del "%TEMP_CERT%" 2>nul
        goto :step2
    )
    call :Log [INFO]   動態計算憑證 Thumbprint: !THUMBPRINT!
)

certutil -addstore Root "%TEMP_CERT%" >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    call :Log [ERROR] 憑證匯入失敗。請以系統管理員身分執行。日誌參考: %LOG_FILE%
    del "%TEMP_CERT%" 2>nul
    exit /b 1
)
call :Log [OK]     憑證匯入成功。
del "%TEMP_CERT%" 2>nul

:step2
REM === Step 2: 安裝 VEN ===
call :Log.
call :Log [Step 2/3] 安裝 Illumio VEN Agent...

set "SCRIPT_DIR=%~dp0"
set "INSTALLER=%SCRIPT_DIR%%EXE_FILE%"

if not exist "%INSTALLER%" (
    call :Log [ERROR] 找不到安裝檔: %INSTALLER%
    exit /b 1
)

if "%INSTALL_DIR%"=="C:\Program Files\Illumio" (
    "%INSTALLER%" /install /quiet /norestart >> "%LOG_FILE%" 2>&1
) else (
    "%INSTALLER%" /install /quiet /norestart INSTALLDIR="%INSTALL_DIR%" DATDIR="%DATA_DIR%" >> "%LOG_FILE%" 2>&1
)

if %errorlevel% neq 0 (
    call :Log [ERROR] 安裝失敗。Exit Code: %errorlevel%. 詳見日誌: %LOG_FILE%
    exit /b %errorlevel%
)
call :Log [OK]     VEN Agent 安裝完成。

REM === Step 3: 啟用 ===
call :Log.
call :Log [Step 3/3] 啟用 VEN Agent...

set "VEN_CTL=%INSTALL_DIR%\illumio-ven-ctl.exe"
if not exist "%VEN_CTL%" set "VEN_CTL=C:\Program Files\Illumio\illumio-ven-ctl.exe"
if not exist "%VEN_CTL%" (
    call :Log [ERROR] 找不到 illumio-ven-ctl.exe
    exit /b 1
)

if "%ACTIVATION_CODE%"=="<YOUR_ACTIVATION_CODE>" (
    call :Log [ERROR] 請先設定 ACTIVATION_CODE。
    exit /b 1
)
if "%MANAGEMENT_SERVER%"=="<YOUR_PCE_FQDN:PORT>" (
    call :Log [ERROR] 請先設定 MANAGEMENT_SERVER。
    exit /b 1
)

"%VEN_CTL%" activate -activation-code %ACTIVATION_CODE% -management-server %MANAGEMENT_SERVER% >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    call :Log [ERROR] 啟用失敗。Exit Code: %errorlevel%. 詳見日誌: %LOG_FILE%
    exit /b %errorlevel%
)
call :Log [OK]     啟用指令已送出。

call :Log.
call :Log ============================================
call :Log  部署完成! 日誌儲存於: %LOG_FILE%
call :Log ============================================

endlocal
exit /b 0

REM ==========================================
REM 日誌函式
REM ==========================================
:Log
echo %*
echo [%DATE% %TIME%] %* >> "%LOG_FILE%"
exit /b 0
