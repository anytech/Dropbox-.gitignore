@echo off
setlocal EnableDelayedExpansion

set "BASE_DIR=%~dp0"
set "IGNORED_FILE=%TEMP%\dropbox_ignore_dirs.txt"
> "%IGNORED_FILE%" type nul

call :Walk "%BASE_DIR%"

echo Done.
del "%IGNORED_FILE%"
goto :eof

:Walk
setlocal EnableDelayedExpansion
set "DIR=%~1"

REM Skip if .dropboxignore exists
if exist "%DIR%\.dropboxignore" (
    endlocal & goto :eof
)

REM Skip if DIR is in ignored file
for /f "usebackq delims=" %%I in ("%IGNORED_FILE%") do (
    if /i "!DIR!"=="%%~fI" (
        endlocal & goto :eof
    )
)

REM Process .gitignore if exists
if exist "%DIR%\.gitignore" (
    echo Processing .gitignore in %DIR%
    call :ProcessGitignore "%DIR%\.gitignore"
)

REM Recurse into subdirectories
for /d %%D in ("%DIR%\*") do (
    call :Walk "%%~fD"
)

endlocal
goto :eof

:ProcessGitignore
setlocal EnableDelayedExpansion
set "GIPATH=%~1"
set "GIDIR=%~dp1"

for /f "usebackq tokens=*" %%L in ("!GIPATH!") do (
    set "LINE=%%L"
    for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"

    if not "!LINE!"=="" (
        echo !LINE! | findstr /b "#" >nul
        if errorlevel 1 (
            set "PAT=!LINE:"=!"
            set "PAT=!PAT:/=\!"

            echo !PAT! | find "*" >nul
            if errorlevel 1 (
                call :IgnorePath "!GIDIR!!PAT!"
            ) else (
                REM Handle glob matches (dirs)
                for /f "delims=" %%P in ('dir /b /s /a:d "!GIDIR!!PAT!" 2^>nul') do (
                    call :IgnorePath "%%P"
                )
                REM Handle glob matches (files)
                for /f "delims=" %%P in ('dir /b /s /a:-d "!GIDIR!!PAT!" 2^>nul') do (
                    call :IgnorePath "%%P"
                )
            )
        )
    )
)

endlocal
goto :eof

:IgnorePath
setlocal
set "TARGET=%~1"

if exist "%TARGET%\" (
    set "MARKER=%TARGET%\.dropboxignore"
    if not exist "!MARKER!" (
        echo. > "!MARKER!"
    )
    powershell -NoLogo -Command ^
      "Set-Content -Path '!MARKER!' -Stream 'com.dropbox.ignored' -Value '1' -Force"
    echo Ignored folder: %TARGET%
    echo %TARGET%>>"%IGNORED_FILE%"
) else if exist "%TARGET%" (
    powershell -NoLogo -Command ^
      "Set-Content -Path '%TARGET%' -Stream 'com.dropbox.ignored' -Value '1' -Force"
    echo Ignored file: %TARGET%
)

endlocal
goto :eof
