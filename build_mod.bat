@echo off
REM Build one LSPosed module.
REM Usage: build_mod.bat <moduledir> <root-package-dir> <apkname>
REM   e.g. build_mod.bat mod_window com\picoxr\winlimit winlimit
setlocal
set PICO=%~dp0
set MOD=%PICO%%~1
set PKGDIR=%~2
set APKNAME=%~3

set JAVA="C:\Program Files\Java\jdk-26.0.1\bin\java.exe"
set JAVAC="C:\Program Files\Java\jdk-26.0.1\bin\javac.exe"
set R8="%PICO%r8.jar"
set APKTOOL="%PICO%tools\apktool.jar"
set JARSIGNER="C:\Program Files\Java\jdk-26.0.1\bin\jarsigner.exe"
set KEYSTORE="%PICO%work\platform.keystore"

echo === [%~1] 1. compile java ===
if exist "%MOD%\build\classes" rmdir /s /q "%MOD%\build\classes"
mkdir "%MOD%\build\classes"
dir /s /b "%MOD%\stub\*.java" "%MOD%\src\*.java" > "%MOD%\build\sources.txt"
%JAVAC% --release 8 -nowarn -d "%MOD%\build\classes" @"%MOD%\build\sources.txt"
if errorlevel 1 ( echo COMPILE FAILED & exit /b 1 )

echo === [%~1] 2. dex (module classes only) ===
if exist "%MOD%\build\dex" rmdir /s /q "%MOD%\build\dex"
mkdir "%MOD%\build\dex"
dir /s /b "%MOD%\build\classes\%PKGDIR%\*.class" > "%MOD%\build\classlist.txt"
%JAVA% -cp %R8% com.android.tools.r8.D8 --min-api 29 --output "%MOD%\build\dex" @"%MOD%\build\classlist.txt"
if errorlevel 1 ( echo D8 FAILED & exit /b 1 )

echo === [%~1] 3. package ===
copy /y "%MOD%\build\dex\classes.dex" "%MOD%\classes.dex" >nul
%JAVA% -jar %APKTOOL% b "%MOD%" -o "%MOD%\build\%APKNAME%-unsigned.apk" >nul 2>&1
if errorlevel 1 ( echo APKTOOL FAILED & exit /b 1 )

echo === [%~1] 4. sign ===
copy /y "%MOD%\build\%APKNAME%-unsigned.apk" "%MOD%\build\%APKNAME%.apk" >nul
%JARSIGNER% -keystore %KEYSTORE% -storepass android -keypass android "%MOD%\build\%APKNAME%.apk" platform >nul 2>&1
if errorlevel 1 ( echo SIGN FAILED & exit /b 1 )

echo BUILD OK -^> %MOD%\build\%APKNAME%.apk
endlocal
