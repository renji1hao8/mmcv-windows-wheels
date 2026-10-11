@echo off
REM ===========================================================================
REM  Build mmcv CUDA extensions on Windows with MSVC + CUDA -> wheel
REM
REM  Usage:  build.bat [cuda_arch_list]
REM    arch list omitted -> build only this machine's arch (RTX 4060 = 8.9),
REM    useful for a quick validation build.
REM    For a community wheel use something like "7.5;8.0;8.6;8.9;9.0".
REM
REM  Prereq: .venv (Python 3.10 + torch 2.1.2+cu121) and src\mmcv-2.1.0\
REM
REM  NOTE: keep this file ASCII-only. cmd.exe reads .bat as ANSI/GBK, so
REM        non-ASCII comments here become garbage commands.
REM ===========================================================================
setlocal

set BUILD_ROOT=%~dp0
set VENV=%BUILD_ROOT%.venv
set MMCV_SRC=%BUILD_ROOT%src\mmcv-2.1.0

if "%~1"=="" (
    set TORCH_CUDA_ARCH_LIST=8.9
) else (
    set TORCH_CUDA_ARCH_LIST=%~1
)

REM mmcv CUDA ops are on by default (MMCV_WITH_OPS=1)
set MMCV_WITH_OPS=1
REM nvcc is memory hungry; this box has 32 cores, 8 parallel jobs is safe
set MAX_JOBS=8
set MMCV_USE_PARROTS=0
REM Required on Windows when vcvars is already active: tell setuptools the
REM SDK env is ready so it does not try to re-activate the VC environment.
set DISTUTILS_USE_SDK=1
set MSSdk=1

echo [build] init MSVC x64 environment...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 (
    echo [build] FAILED: vcvars64.bat
    exit /b 1
)

echo [build] toolchain check
where cl
where nvcc
"%VENV%\Scripts\python.exe" -c "import torch;print('torch',torch.__version__,'cuda',torch.version.cuda,'avail',torch.cuda.is_available())"
if errorlevel 1 (
    echo [build] FAILED: torch not ready
    exit /b 1
)

echo [build] TORCH_CUDA_ARCH_LIST=%TORCH_CUDA_ARCH_LIST%  MAX_JOBS=%MAX_JOBS%
cd /d "%MMCV_SRC%"
if errorlevel 1 (
    echo [build] FAILED: source dir not found: %MMCV_SRC%
    exit /b 1
)

echo [build] compiling CUDA extensions (this takes a while)...
"%VENV%\Scripts\python.exe" setup.py bdist_wheel
if errorlevel 1 (
    echo [build] FAILED: compile error
    exit /b 1
)

echo [build] DONE. artifacts:
dir /b "%MMCV_SRC%\dist"
endlocal
