@echo off
setlocal
title Envoi du lot Play Integrity (KernelSU-Next) vers la tablette

rem Lot compatible KernelSU-Next pour SM-T870 (ordre d'installation) :
rem   1. Zygisk Next 1.5.3          (Zygisk pour KernelSU, obligatoire)
rem   2. Zygisk Assistant 2.1.4     (masquage du root, release)
rem   3. Play Integrity Fork v19    (id playintegrityfix : remplace Integrity Box / PIF inject)
rem   4. Tricky Store 1.4.1         (5ec1cff)
rem Rien n'est installe ni modifie sur la tablette : les zips sont seulement
rem copies dans Telechargements. L'installation se fait dans l'appli KernelSU-Next.

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

rem --- 2. Verifier l'integrite des fichiers (SHA-256 des releases GitHub officielles)
call :check "Zygisk-Next-1.5.3-880-22a1bf5-release.zip" 186a0a26c9fcb895af1954b42de831433c23d72d1bd0758b986069154359db67 || goto :fail
call :check "Zygisk-Assistant-v2.1.4-1013f8a-release.zip" 9eca30a269dc676a66f67a9339185dee55cccd47dc1fc8eeea5416124626d67a || goto :fail
call :check "PlayIntegrityFork-v19.zip" 83b4d5f32743805c5b5a69361d73b8ab9c095325e24f20711afa1abea837b58f || goto :fail
call :check "Tricky-Store-v1.4.1-245-72b2e84-release.zip" 2f5e73fcba0e4e43b6e96b38f333cbe394873e3a81cf8fe1b831c2fbd6c46ea9 || goto :fail
echo Empreintes SHA-256 : OK (4/4)
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
for %%F in (
  "Zygisk-Next-1.5.3-880-22a1bf5-release.zip"
  "Zygisk-Assistant-v2.1.4-1013f8a-release.zip"
  "PlayIntegrityFork-v19.zip"
  "Tricky-Store-v1.4.1-245-72b2e84-release.zip"
) do (
  "%ADB%" push "%~dp0%%~F" /sdcard/Download/ || goto :fail
)
echo.

rem --- 5. Quel gestionnaire de root est installe ? (lecture seule) -------
echo Gestionnaire de root detecte sur la tablette :
"%ADB%" shell pm list packages | findstr /i "com.topjohnwu.magisk me.weishu.kernelsu com.rifsxd.ksunext me.bmax.apatch" || echo   (aucun des paquets habituels : Magisk, KernelSU, KernelSU-Next, APatch)
echo.
echo Termine. Les 4 zips sont dans Telechargements sur la tablette.
echo Suite : appli KernelSU-Next ^> Modules ^> Installer, dans l'ordre 1 a 4.
echo Voir LISEZMOI.txt pour les reglages.
echo.
pause
exit /b 0

:check
if not exist "%~dp0%~1" (
  echo ERREUR : fichier manquant : %~1
  exit /b 1
)
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
