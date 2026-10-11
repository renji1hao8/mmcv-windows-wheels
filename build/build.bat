@echo off
REM ===========================================================================
REM  Build mmcv CUDA extensions on Windows with MSVC + CUDA -> wheel
REM
REM  Configuration comes from the ENVIRONMENT, not argv. An arch list such as
REM  "7.0;7.5;8.0" contains semicolons, which break cmd's parenthesised
REM  "if ... ( ... )" blocks when passed as %1, so it must not be an argument.
REM
REM    TORCH_CUDA_ARCH_LIST   default 8.9 (the local GPU)
REM    MAX_JOBS               default 8
REM    MMCV_WITH_OPS          default 1
REM
REM  Example:
REM    set TORCH_CUDA_ARCH_LIST=7.0;7.5;8.0;8.6;8.9;9.0+PTX
REM    build.bat
REM
REM  Prereq: .venv (Python 3.10 + torch 2.1.2+cu121) and src\mmcv-2.1.0\
REM
REM  NOTE: keep this file ASCII-only. cmd reads .bat as ANSI/GBK, so non-ASCII
REM        comments here are parsed as commands and produce spurious errors.
REM ===========================================================================
setlocal

set BUILD_ROOT=%~dp0
set VENV=%BUILD_ROOT%.venv
set MMCV_SRC=%BUILD_ROOT%src\mmcv-2.1.0

if not defined TORCH_CUDA_ARCH_LIST set TORCH_CUDA_ARCH_LIST=8.9
if not defined MMCV_WITH_OPS set MMCV_WITH_OPS=1
if not defined MAX_JOBS set MAX_JOBS=8
set MMCV_USE_PARROTS=0
REM Required on Windows when vcvars is already active: tell setuptools the SDK
REM env is ready so it does not try to re-activate the VC environment.
set DISTUTILS_USE_SDK=1
set MSSdk=1

echo [build] init MSVC x64 environment...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 goto :fail

echo [build] toolchain check
where cl
where nvcc
"%VENV%\Scripts\python.exe" -c "import torch;print('torch',torch.__version__,'cuda',torch.version.cuda,'avail',torch.cuda.is_available())"
if errorlevel 1 goto :fail

echo [build] TORCH_CUDA_ARCH_LIST=%TORCH_CUDA_ARCH_LIST%  MAX_JOBS=%MAX_JOBS%
cd /d "%MMCV_SRC%"
if errorlevel 1 goto :fail

echo [build] compiling CUDA extensions (this takes a while)...
"%VENV%\Scripts\python.exe" setup.py bdist_wheel
if errorlevel 1 goto :fail

echo [build] DONE. artifacts:
dir /b "%MMCV_SRC%\dist"
endlocal
exit /b 0

:fail
echo [build] FAILED
endlocal
exit /b 1
