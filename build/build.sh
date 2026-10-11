#!/bin/bash
# Linux/WSL 上编译 mmcv CUDA 扩展 -> wheel
#
# 用法: bash build.sh <mmcv源码目录> [cuda_arch_list]
#   cuda_arch_list 省略时用 "7.5;8.0;8.6;8.9;9.0"
#
# 前置：当前环境已有 torch+cuXXX 与 CUDA Toolkit（nvcc 在 PATH）。
set -euo pipefail

SRC="${1:?用法: bash build.sh <mmcv源码目录> [cuda_arch_list]}"
ARCH="${2:-7.5;8.0;8.6;8.9;9.0}"

export TORCH_CUDA_ARCH_LIST="$ARCH"
export MMCV_WITH_OPS=1
export MAX_JOBS="${MAX_JOBS:-8}"
# 这里的三个是 Windows 才需要的（vcvars 已激活时告知 setuptools），
# 在 Linux 上设了也无害，保持脚本两边通用。
export DISTUTILS_USE_SDK=1
export MSSdk=1

echo "[build] nvcc: $(command -v nvcc || echo '未找到')"
nvcc --version | tail -2
python -c "import torch;print('torch',torch.__version__,'cuda',torch.version.cuda,'avail',torch.cuda.is_available())"

cd "$SRC"
echo "[build] TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST  MAX_JOBS=$MAX_JOBS"
python setup.py bdist_wheel
echo "[build] DONE:"
ls -la dist/
