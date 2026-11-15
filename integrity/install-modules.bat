@echo off
setlocal
title Envoi des modules Play Integrity vers la tablette

rem --- 1. Trouver adb ---------------------------------------------------
set "ADB="
where adb >nul 2>&1 && set "ADB=adb"
if not defined ADB if exist "%USERPROFILE%\Latest ADB Fastboot Tool\adb.exe" set "ADB=%USERPROFILE%\Latest ADB Fastboot Tool\adb.exe"
if not defined ADB if exist "%USERPROFILE%\Latest ADB Fastboot Tool\platform-tools\adb.exe" set "ADB=%USERPROFILE%\Latest ADB Fastboot Tool\platform-tools\adb.exe"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB (
  echo adb.exe est introuvable. Glisse adb.exe sur cette fenetre puis appuie sur Entree :
  set /p "ADB="
)
set "ADB=%ADB:"=%"
echo adb utilise : %ADB%
echo.

rem --- 2. Verifier l'integrite des fichiers (SHA-256 releve sur GitHub) --
call :check "PlayIntegrityFork-v19.zip" 83b4d5f32743805c5b5a69361d73b8ab9c095325e24f20711afa1abea837b58f || goto :fail
call :check "Tricky-Store-v1.4.1-245-72b2e84-release.zip" 2f5e73fcba0e4e43b6e96b38f333cbe394873e3a81cf8fe1b831c2fbd6c46ea9 || goto :fail
echo Empreintes SHA-256 : OK
echo.

rem --- 3. Tablette connectee et autorisee ? -----------------------------
"%ADB%" start-server >nul 2>&1
"%ADB%" get-state 2>nul | findstr /x "device" >nul
if errorlevel 1 (
  echo Aucune tablette autorisee. Branche-la en USB, active le debogage USB
  echo et accepte la demande "Autoriser le debogage USB" sur son ecran.
  "%ADB%" devices
  goto :fail
)

rem --- 4. Copier les zips dans Telechargements (aucune modification systeme)
"%ADB%" push "%~dp0PlayIntegrityFork-v19.zip" /sdcard/Download/ || goto :fail
"%ADB%" push "%~dp0Tricky-Store-v1.4.1-245-72b2e84-release.zip" /sdcard/Download/ || goto :fail
echo.

rem --- 5. Quel gestionnaire de root est installe ? (lecture seule) -------
echo Gestionnaire de root detecte sur la tablette :
"%ADB%" shell pm list packages | findstr /i "com.topjohnwu.magisk me.weishu.kernelsu com.rifsxd.ksunext me.bmax.apatch" || echo   (aucun des paquets habituels : Magisk, KernelSU, KernelSU-Next, APatch)
echo.
echo Termine. Les 2 zips sont dans Telechargements sur la tablette.
echo Suite : ouvre l'application de root ^> Modules ^> Installer depuis le stockage.
echo Voir LISEZMOI.txt pour l'ordre et les reglages.
echo.
pause
exit /b 0

:check
set "H="
for /f "skip=1 tokens=* delims=" %%h in ('certutil -hashfile "%~dp0%~1" SHA256') do if not defined H set "H=%%h"
set "H=%H: =%"
if /i "%H%"=="%~2" exit /b 0
echo ERREUR : empreinte differente pour %~1
echo   attendue : %~2
echo   obtenue  : %H%
exit /b 1

:fail
echo.
echo Arret : rien n'a ete modifie sur la tablette.
pause
exit /b 1
