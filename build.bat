@echo off
setlocal enabledelayedexpansion enableextensions
set BUILD_DIR=%~dp0

for /f "delims=" %%X IN ('dir /B /A /S *') DO (
	for %%D in ("%%~dpX\.") do (
		set PACKAGE_NAME=%%~nxD
		goto FoundPkgName
	)
)

:FoundPkgName
pushd %BUILD_DIR%

cd ..\System

:: make sure to always rebuild the package
:: New package GUID, No doubts about staleness
del %PACKAGE_NAME%.u

ucc make

:: dont do the post-process steps if compilation failed
if ERRORLEVEL 1 goto cleanup

:: Generate compressed file for redirects
ucc compress %PACKAGE_NAME%.u

:: copy to release location
if not exist %BUILD_DIR%System do (mkdir %BUILD_DIR%System)
copy %PACKAGE_NAME%.u     %BUILD_DIR%System >NUL
copy %PACKAGE_NAME%.u.uz  %BUILD_DIR%System >NUL

:cleanup
popd
endlocal
