# mmcv Windows (CUDA) wheels — unofficial

为 [`mmcv`](https://github.com/open-mmlab/mmcv) 提供 **Windows 预编译轮子**，
以及从源码复现它们的构建脚本。

> ⚠️ **非官方构建。** 本仓库与 OpenMMLab 无隶属关系，未经其审核或背书。
> 轮子由本仓库的脚本从 mmcv 官方 sdist 编译，**未修改任何 mmcv 源码**。
> 许可证为 Apache-2.0，见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。

---

## 背景

PyPI 上的 `mmcv` **只提供 sdist，没有 Windows 轮子**（`mmcv 2.1.0` 在 PyPI 上
仅有 1 个文件，`win_amd64` 轮子数为 0）。Windows 上安装它必须使用 MSVC 与 CUDA
从源码编译，而 mmcv 的官方 CI 与文档均不覆盖 Windows，可参考的实践较为零散。

需要指出的是，网络上常见的"`spconv` 在 Windows 上不可用"并不成立：
`spconv-cu121 2.3.8` 在 PyPI 上提供 5 个 `win_amd64` 轮子（cp310–cp313），可直接安装。
**Windows 平台上缺失预编译轮子的是 `mmcv`**，本仓库即针对这一问题。

## 可用的轮子

| 版本 | Python | torch | CUDA | 目标架构 | 下载 |
|---|---|---|---|---|---|
| mmcv 2.1.0 | 3.10 | 2.1.2+cu121 | 12.1 | `sm_70/75/80/86/89/90` + `compute_90` PTX | [Release](https://github.com/renji1hao8/mmcv-windows-wheels/releases/tag/v2.1.0-torch2.1.2-cu121) |

覆盖 V100 / T4·RTX 20 系 / A100 / RTX 30 系 / RTX 40 系 / H100；
另附带 `compute_90` 的 PTX，高于 `sm_90` 的架构（如 Blackwell）可由驱动即时编译运行，
首次运行有一次性 JIT 开销。

## 安装

```
pip install https://github.com/renji1hao8/mmcv-windows-wheels/releases/download/v2.1.0-torch2.1.2-cu121/mmcv-2.1.0-cp310-cp310-win_amd64.whl
```

轮子的 ABI 与特定 torch 版本绑定，安装前请先核对上表所列的版本组合。
运行时依赖需预先安装：

```
pip install torch==2.1.2+cu121 torchvision==0.16.2+cu121 --index-url https://download.pytorch.org/whl/cu121
pip install "numpy<2" "setuptools<81" addict "mmengine>=0.3.0" packaging Pillow pyyaml yapf regex
```

其中两条版本约束不可省略：

- **`numpy<2`** —— torch 2.1.x 按 numpy 1.x 的 ABI 编译；安装 numpy 2.x 会触发
  `Failed to initialize NumPy: _ARRAY_API not found`。
- **`setuptools<81`** —— setuptools 81 起移除了 `pkg_resources`，而 mmcv 2.1.0 的
  `setup.py` 第 5 行即 `from pkg_resources import ...`。

## 验证安装结果

仅验证 `import mmcv` 通过是不充分的：不带算子的 `mmcv-lite` 同样可以成功导入，
而这正是本仓库所要解决的问题。请确认 CUDA 扩展确实存在且可执行：

```
python verify.py
```

该脚本位于本仓库根目录，会检查 C 扩展是否加载、`mmcv.ops` 下的 CUDA 算子能否导入，
并在 GPU 上实际执行一次。核心检查即为：

```python
import torch
from mmcv.ops import nms, ball_query, furthest_point_sample
print(furthest_point_sample(torch.rand(1, 50, 3, device="cuda"), 8).shape)   # (1, 8)
```

---

## 自行构建

本仓库的脚本针对以下组合，其他组合需相应调整：

| 组件 | 版本 |
|---|---|
| Python | 3.10（该技术栈依赖 torch 2.1.2，不支持 3.12 及以上） |
| torch / torchvision | 2.1.2+cu121 / 0.16.2+cu121 |
| CUDA Toolkit | 12.4（12.1 及以上均可，参见[常见问题](#常见问题)） |
| MSVC | VS 2022 Build Tools（提供 `vcvars64.bat`） |
| Windows SDK | 10.0.x（本仓库在 10.0.26100 上验证） |
| setuptools | **<81** |

```bash
# 1) 环境
uv venv --python 3.10 .venv
uv pip install --python .venv/Scripts/python.exe torch==2.1.2+cu121 torchvision==0.16.2+cu121 \
    --index-url https://download.pytorch.org/whl/cu121
uv pip install --python .venv/Scripts/python.exe "numpy<2" "setuptools<81" addict mmengine \
    packaging Pillow pyyaml yapf regex wheel

# 2) 源码
curl -sSL -o mmcv-2.1.0.tar.gz https://files.pythonhosted.org/packages/source/m/mmcv/mmcv-2.1.0.tar.gz
tar xzf mmcv-2.1.0.tar.gz

# 3) 编译（脚本负责初始化 MSVC 环境并设置所需的环境变量）
set TORCH_CUDA_ARCH_LIST=7.0;7.5;8.0;8.6;8.9;9.0    # 省略则仅编译本机架构，用于快速验证
build\build.bat
```

Linux / WSL 环境使用 `build/build.sh`（环境变量相同，用法见脚本头部注释）。

持续集成：[`.github/workflows/build-windows.yml`](.github/workflows/build-windows.yml)
在 `windows-2022` runner 上构建，并自动执行 verify。

### 构建注意事项

以下几项均已在脚本中处理。单独列出是因为它们通常不会产生指向根因的报错，
排查成本较高：

1. **`.bat` 文件须为纯 ASCII。** cmd 以 ANSI/GBK 读取批处理文件，其中的非 ASCII
   字符（如中文注释）会被解析为命令并报错。
2. **须设置 `DISTUTILS_USE_SDK=1` 与 `MSSdk=1`。** 否则 torch 的 `cpp_extension`
   会因"VC 环境已激活但未声明 SDK"而拒绝构建。
3. **`setuptools` 须低于 81。** 原因见上文依赖约束。
4. **架构列表不可经 `.bat` 参数传递。** `7.0;7.5;...` 中的分号会破坏 cmd 的
   `if (...)` 块解析（报 `7.5 was unexpected at this time`），应通过环境变量传入。
5. **`TORCH_CUDA_ARCH_LIST` 决定分发范围。** 仅编译本机架构可显著缩短构建时间，
   但目标机器若缺少对应的 `sm_XX` 将无法运行。
6. **`MAX_JOBS` 取值需克制。** `nvcc` 内存占用较高，32 核机器上建议取 8。

## 常见问题

**构建时 CUDA Toolkit 是否必须与 torch 的 `cuXXX` 完全一致？**
不需要完全一致，**主版本一致即可**。本仓库发布的轮子由 CUDA **12.4** 工具链编译，
在 `torch 2.1.2+cu121`（CUDA 12.1）上运行正常 —— CUDA 12.x 内部保持次版本兼容。

**目标 GPU 不在 `sm_70`–`sm_90` 范围内怎么办？**
`sm_70`–`sm_90` 已由 SASS 直接覆盖。高于 `sm_90` 的架构（如 Blackwell）
可由驱动从轮子内置的 `compute_90` PTX 即时编译运行，首次运行有一定 JIT 开销。
若目标架构**低于** `sm_70`，需自行构建并在 `TORCH_CUDA_ARCH_LIST` 中加入对应架构。

**轮子包含 PTX 吗？**
包含。构建参数为 `7.0;7.5;8.0;8.6;8.9;9.0+PTX`，除 6 个架构的 SASS 外，
还嵌入了 `compute_90` 的 PTX。可自行核对：

```
cuobjdump -lelf mmcv/_ext*.pyd | grep -oE 'sm_[0-9]+' | sort -u     # SASS 架构
cuobjdump -lptx mmcv/_ext*.pyd                                      # PTX 段
```

**能否发布到 PyPI？**
不能。PyPI 上 `mmcv` 这一发行名归属 OpenMMLab，同名上传会被拒绝，且会造成混淆。
GitHub Release 是非官方轮子的通行做法：文件名与官方一致，
`pip install <url>` 仍可满足 `mmcv==2.1.0` 这类依赖声明。

**安装后导入时报 `no kernel image is available`？**
目标 GPU 的架构不在轮子覆盖范围内，参见上文说明。

## 目录

```
dist/        发布产物（已加入 .gitignore，不进入版本历史）
build/       构建脚本：build.bat（Windows）/ build.sh（Linux、WSL）
verify.py    验证脚本，确认所装为带 CUDA 算子的完整版本
.github/     持续集成工作流
LICENSE      Apache-2.0（来自 mmcv 官方）
NOTICE       来源说明与非官方构建声明
```

## 来源与免责

- 源码来自 [open-mmlab/mmcv](https://github.com/open-mmlab/mmcv) 官方 sdist，未作任何修改。
- 本仓库仅提供构建脚本与二进制分发，不对 mmcv 本身提供支持。
- 上游问题请反馈给上游；构建脚本的问题请反馈至本仓库。
- 轮子按 Apache-2.0 的"AS IS"条款提供，不附带任何担保。
