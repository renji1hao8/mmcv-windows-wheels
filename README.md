# mmcv Windows (CUDA) wheels — unofficial builds

**非官方** Windows 预编译轮子，为 [`mmcv`](https://github.com/open-mmlab/mmcv) 官方不提供
Windows 二进制的问题提供一个可复现的构建与分发。

> ⚠️ **这不是 OpenMMLab 官方发布。** 由社区成员用本仓库的脚本从 mmcv 官方 sdist 源码编译，
> 未做任何源码改动。许可证仍为 Apache-2.0，见 `LICENSE` 与 `NOTICE`。

## 为什么需要这个

`mmcv` 在 PyPI 上**只有 sdist、没有 Windows 轮子**（实测：`mmcv 2.1.0` 该版本
PyPI 上只有 1 个文件、0 个 `win_amd64`）。Windows 用户装它必须用 MSVC + CUDA
从源码编译，而 mmcv 的官方文档与 CI 都不覆盖 Windows，成功案例零散。

顺带澄清一个常见误解：**卡点不是 `spconv`**。`spconv-cu121 2.3.8` 在 PyPI 上有
5 个 `win_amd64` 轮子（cp310–cp313），可直接装；真正没有 Windows 轮子的是 `mmcv`。

## 安装

```
pip install https://github.com/<owner>/<repo>/releases/download/<tag>/mmcv-2.1.0-cp310-cp310-win_amd64.whl
```

装之前需要已有的运行时依赖（与官方一致）：

```
pip install torch==2.1.2+cu121 torchvision==0.16.2+cu121 --index-url https://download.pytorch.org/whl/cu121
pip install "numpy<2" addict "mmengine>=0.3.0" packaging Pillow pyyaml yapf regex
```

**注意**：`torch 2.1.x` 只支持 `numpy<2`。轮子的 ABI 与 torch 版本绑定，
本仓库每个轮子的文件名与 Release 说明都会写清对应的 torch / CUDA /
Python 版本，装之前先核对。

## 验证这个轮子

```python
import torch, mmcv
from mmcv.ops import nms            # 纯 C++ 算子
from mmcv.ops import ball_query     # CUDA 算子
print(mmcv.__version__, torch.__version__, torch.version.cuda)
print(mmcv.ops.__file__)
```

`from mmcv.ops import <CUDA 算子>` 能成功 import 且能在 GPU 上跑通，
就说明 CUDA 扩展编对了。**只 import mmcv 不算验证**——`mmcv-lite`（无算子的版本）
也能 import 成功，那正是本仓库要解决的场景。

## 自己编译（可复现）

构建环境（本仓库的脚本假设如下，其他组合需自行调整）：

| 组件 | 版本 |
|---|---|
| Python | 3.10 |
| torch / torchvision | 2.1.2+cu121 / 0.16.2+cu121 |
| CUDA Toolkit | 12.4（12.1+ 均可，见下） |
| MSVC | VS 2022 Build Tools（`vcvars64.bat`） |
| Windows SDK | 10.0.26100 |
| setuptools | **<81**（81 起移除了 `pkg_resources`，mmcv 2.1.0 的 setup.py 仍依赖它） |

```
# 1) 环境
uv venv --python 3.10 .venv
uv pip install --python .venv/Scripts/python.exe torch==2.1.2+cu121 torchvision==0.16.2+cu121 \
    --index-url https://download.pytorch.org/whl/cu121
uv pip install --python .venv/Scripts/python.exe "numpy<2" "setuptools<81" addict mmengine packaging Pillow pyyaml yapf regex wheel

# 2) 源码
curl -sSL -o mmcv-2.1.0.tar.gz https://files.pythonhosted.org/packages/source/m/mmcv/mmcv-2.1.0.tar.gz
tar xzf mmcv-2.1.0.tar.gz

# 3) 编译（脚本会初始化 MSVC 环境并设置必需的环境变量）
build\build.bat "7.5;8.0;8.6;8.9;9.0"      # 省略参数则只编本机架构，用于快速验证
```

### 踩过的坑（脚本里都已处理）

1. **`.bat` 里不能有非 ASCII 字符**——cmd 按 ANSI/GBK 读 `.bat`，中文注释会变成乱码命令。
2. **必须设 `DISTUTILS_USE_SDK=1` 与 `MSSdk=1`**——否则 torch 的 `cpp_extension`
   检测到"VC 环境已激活但 SDK 未声明"会直接拒绝构建。
3. **`setuptools` 必须 <81**——81 起删了 `pkg_resources`，而 mmcv 2.1.0 的
   `setup.py` 第 5 行就 `from pkg_resources import ...`。
4. **CUDA Toolkit 版本不必与 torch 的 cuXXX 完全一致**：本仓库的轮子用 CUDA 12.4
   工具链编译、却在 `torch 2.1.2+cu121`（CUDA 12.1）上运行正常——CUDA 12.x 内部
   有次版本兼容。但同一次构建内 torch 与 toolkit 的**主版本**要对上。
5. **`TORCH_CUDA_ARCH_LIST`**：只编本机架构快很多，但给社区分发要用覆盖常见卡的列表
   （如 `7.5;8.0;8.6;8.9;9.0`），否则别人机器上会因缺少对应 `sm_XX` 而跑不了。
6. **`MAX_JOBS` 别开太大**：`nvcc` 很吃内存，32 核机器上取 8 比较稳。

## 目录

```
build/       构建脚本（Windows .bat 与 Linux/WSL .sh）
LICENSE      Apache-2.0（来自 mmcv 官方）
NOTICE       来源说明与非官方声明
```

## 免责与来源

- 源码完全来自 [open-mmlab/mmcv](https://github.com/open-mmlab/mmcv) 官方 sdist，**未作任何修改**。
- 本仓库只提供**构建脚本与二进制分发**，不对 mmcv 本身做任何支持承诺。
- 上游有 bug 请报给上游；**构建脚本**的问题报本仓库。

## 构建与验证记录（2026-10-11，本仓库首个轮子）

实测环境：Windows 11 + RTX 4060 Laptop (sm_89) + 驱动 560.94，
MSVC 14.42.34433 / CUDA Toolkit **12.4** / Windows SDK 10.0.26100 /
Python 3.10.21 / torch **2.1.2+cu121** / setuptools 80.9.0。

**验证结果**（`verify.py`，可直接跑）：

```
torch 2.1.2+cu121  cuda 12.1  avail True
device: NVIDIA GeForce RTX 4060 Laptop GPU
mmcv 2.1.0
C 扩展: _ext.cp310-win_amd64.pyd
纯 C++ 算子 nms                              import OK
CUDA 算子 ball_query / furthest_point_sample  import OK
nms(GPU)                   -> keep=[[0,0,10,10,0.9], [50,50,60,60,0.7]]
ball_query(GPU)            -> (2, 10, 8)
furthest_point_sample(GPU) -> (2, 16)
```

另做了**干净环境测试**：新建 venv、只装上面列出的声明依赖 + 本轮子，
上述算子依然跑通 → **轮子自足，无隐藏依赖**。

### 发布用的多架构轮子

单架构轮子（只编 `sm_89`）只能在 RTX 40 系上跑。**对外发布的是多架构版**：

```
TORCH_CUDA_ARCH_LIST = 7.0;7.5;8.0;8.6;8.9;9.0        # V100 / T4·RTX20 / A100 / RTX30 / RTX40 / H100
mmcv-2.1.0-cp310-cp310-win_amd64.whl   ≈ 20 MB         # 单架构版只有 4.7 MB
构建耗时 ≈ 51 分钟（单架构版约 20 分钟）
```

**用 `cuobjdump` 反查确认架构真的都嵌进去了**（不是只看构建参数）：

```
$ cuobjdump -lelf mmcv/_ext.cp310-win_amd64.pyd | grep -oE 'sm_[0-9]+' | sort -u
sm_70 sm_75 sm_80 sm_86 sm_89 sm_90          # 348 个 ELF(cubin) 段
$ cuobjdump -lptx ...                        # 空 —— 见下
```

⚠️ **没有嵌 PTX**。这意味着该轮子只覆盖上面这 6 个架构，**更新的 GPU（如 Blackwell、
`sm_100`）无法通过 JIT 前向兼容**，会报 `no kernel image is available`。
若需要前向兼容，构建时要在 `TORCH_CUDA_ARCH_LIST` 里加 `+PTX`（例如
`8.0+PTX`），代价是 wheel 再大一些、构建再久一些。

**一个值得记的观察**：轮子用 **CUDA 12.4** 工具链编译，却在
**torch 2.1.2+cu121（CUDA 12.1）** 上正常运行。CUDA 12.x 内部的次版本兼容
是成立的，所以不必为了匹配 torch 的 cuXXX 去装同版本的 CUDA Toolkit
（主版本要对上）。

---

## 发布步骤（本包已备好，只需执行）

本目录是**可直接发布**的形态。发布到 GitHub Release 的步骤：

```bash
# 1) 建仓库并推送本目录内容
cd mmcv-windows
git init -b main
git add -A && git commit -m "mmcv 2.1.0 unofficial Windows CUDA wheels + build recipe"
gh repo create mmcv-windows-wheels --public --source=. --push

# 2) 打 tag 并挂 Release（轮子 + 校验和）
gh release create v2.1.0-torch2.1.2-cu121 dist/*.whl \
    --title "mmcv 2.1.0 (Windows, cu121, torch 2.1.2)" \
    --notes-file <(printf '多架构构建: sm_70/75/80/86/89/90\n\n校验和:\n%s\n' \
        "$(sha256sum dist/*.whl)")
```

**本轮子的校验和**（发布时请一并附上）：

```
a20af1c0873f327f9afd2dd88ae580f47cfd2da1ce5839a4a25838f0fcc6e20a
```

**不要发到 PyPI。** PyPI 上 `mmcv` 这个发行名是 OpenMMLab 的，同名上传会被拒，
且区分度不够会误导使用者。GitHub Release 是非官方轮子的通行做法——
文件名与官方一致，`pip install <url>` 依然能满足 `mmcv==2.1.0` 的依赖解析。

若确实想进 PyPI，需要 fork 并把 `setup.py` 的发行名改成别的（如 `mmcv-win-cu121`），
但那会让 `mmcv==2.1.0` 这类依赖声明解析不到，得不偿失。
