@echo off
REM TASK_6088 Test Server Build Script (Windows)
REM
REM This script builds the test server for vulnerability testing on Windows
REM
REM Prerequisites:
REM   - Apache Thrift installed (via vcpkg or manual build)
REM   - Visual Studio or MinGW-w64
REM   - thrift.exe in PATH
REM
REM Recommended: Use WSL instead for easier setup
REM   wsl
REM   ./build_test_server.sh
REM

setlocal enabledelayedexpansion

echo ================================================================
echo   TASK_6088 Test Server Build (Windows)
echo ================================================================
echo.

REM Check for thrift compiler
where thrift >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: 'thrift' compiler not found in PATH
    echo.
    echo Please install Apache Thrift:
    echo   Option 1: Use vcpkg
    echo     vcpkg install thrift
    echo.
    echo   Option 2: Use WSL (Recommended)
    echo     wsl --install
    echo     wsl
    echo     cd /mnt/c/Users/scout/Desktop/Agent_Sprint/model_a
    echo     ./build_test_server.sh
    echo.
    exit /b 1
)

echo [1/4] Cleaning old generated code...
if exist gen-cpp rmdir /s /q gen-cpp
mkdir gen-cpp

echo [2/4] Generating C++ code from test_server.thrift...
thrift --gen cpp test_server.thrift

if not exist gen-cpp (
    echo ERROR: Code generation failed
    exit /b 1
)

echo       Generated files:
dir /b gen-cpp\*.cpp gen-cpp\*.h

echo.
echo [3/4] Note: Manual compilation required on Windows
echo.
echo Please use Visual Studio or run in WSL:
echo   wsl
echo   cd /mnt/c/Users/scout/Desktop/Agent_Sprint/model_a
echo   ./build_test_server.sh
echo.
echo ================================================================
echo.

REM Show security status
findstr /C:"SIZE_LIMIT" gen-cpp\test_server_types.cpp >nul 2>&1
if %errorlevel% equ 0 (
    echo Security Status:
    echo   ✓ PATCHED - SIZE_LIMIT checks found in generated code
    echo     The exploit should be BLOCKED
) else (
    echo Security Status:
    echo   ⚠ UNPATCHED - No SIZE_LIMIT checks found
    echo     The exploit may cause a CRASH
)

echo.
echo ================================================================
echo.
echo Recommendation: Use WSL for compilation
echo   wsl ./build_test_server.sh
echo.
