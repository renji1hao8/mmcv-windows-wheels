# mmcv Windows (CUDA) wheels — unofficial

为 [`mmcv`](https://github.com/open-mmlab/mmcv) 提供 **Windows 预编译轮子**，
以及从源码复现它们的构建脚本。

> ⚠️ **非官方。** 本仓库与 OpenMMLab 无隶属关系，未经其审核或背书。
> 轮子由本仓库的脚本从 mmcv 官方 sdist 编译，**未修改任何 mmcv 源码**。
> 许可证仍为 Apache-2.0（见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)）。

---

## 为什么需要它

PyPI 上的 `mmcv` **只有 sdist，没有 Windows 轮子**（`mmcv 2.1.0` 在 PyPI 上只有 1 个文件、
0 个 `win_amd64`）。Windows 用户装它必须用 MSVC + CUDA 从源码编译，而 mmcv 的官方
CI 与文档都不覆盖 Windows，成功案例零散。

**先澄清一个流传很广的误解**：卡点**不是** `spconv`。`spconv-cu121 2.3.8` 在 PyPI 上有
5 个 `win_amd64` 轮子（cp310–cp313），`pip install` 直接就能装。**真正没有 Windows
轮子的是 `mmcv`**，本项目就为了解决它。

## 可用的轮子

| 版本 | Python | torch | CUDA | 目标架构 | 下载 |
|---|---|---|---|---|---|
| mmcv 2.1.0 | 3.10 | 2.1.2+cu121 | 12.1 | `sm_70/75/80/86/89/90` | [Release](https://github.com/renji1hao8/mmcv-windows-wheels/releases/tag/v2.1.0-torch2.1.2-cu121) |

覆盖 V100 / T4·RTX20 / A100 / RTX30 / RTX40 / H100。**未包含 PTX**，
更新的架构（Blackwell 等）不在覆盖范围内，详见[常见问题](#常见问题)。

## 安装

```
pip install https://github.com/renji1hao8/mmcv-windows-wheels/releases/download/v2.1.0-torch2.1.2-cu121/mmcv-2.1.0-cp310-cp310-win_amd64.whl
```

轮子的 ABI 与特定 torch 版本绑定，**装之前先对上**（见上表）。先备好运行时依赖：

```
pip install torch==2.1.2+cu121 torchvision==0.16.2+cu121 --index-url https://download.pytorch.org/whl/cu121
pip install "numpy<2" "setuptools<81" addict "mmengine>=0.3.0" packaging Pillow pyyaml yapf regex
```

两条容易踩的依赖约束：

- **`numpy<2`** —— torch 2.1.x 是按 numpy 1.x 的 ABI 编译的，装 numpy 2.x 会得到
  `Failed to initialize NumPy: _ARRAY_API not found`。
- **`setuptools<81`** —— 81 起移除了 `pkg_resources`，而 mmcv 2.1.0 的 `setup.py`
  第 5 行就 `from pkg_resources import ...`。

## 验证装对了

**只 `import mmcv` 不算验证** —— 无算子的 `mmcv-lite` 也能 import 成功，
而那正是本仓库要解决的问题。务必确认 CUDA 算子真在、真能跑：

```
python verify.py
```

（脚本就在本仓库根目录。）它会检查 C 扩展是否加载、`mmcv.ops` 下的 CUDA 算子
能否 import、并在 GPU 上实跑一遍。核心其实就三行：

```python
import torch
from mmcv.ops import nms, ball_query, furthest_point_sample
print(furthest_point_sample(torch.rand(1, 50, 3, device="cuda"), 8).shape)   # (1, 8)
```

---

## 自己构建

本仓库的脚本假设如下组合，其他组合需自行调整：

| 组件 | 版本 |
|---|---|
| Python | 3.10（这套栈锚定 torch 2.1.2，不支持 3.12+） |
| torch / torchvision | 2.1.2+cu121 / 0.16.2+cu121 |
| CUDA Toolkit | 12.4（12.1+ 均可，见[常见问题](#常见问题)） |
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

# 3) 编译（脚本会初始化 MSVC 环境并设置必需的环境变量）
set TORCH_CUDA_ARCH_LIST=7.0;7.5;8.0;8.6;8.9;9.0    # 省略则只编本机架构，用于快速验证
build\build.bat
```

Linux / WSL 用 `build/build.sh`（同一套环境变量，用法见脚本头注释）。

CI：[`.github/workflows/build-windows.yml`](.github/workflows/build-windows.yml)
在 `windows-2022` runner 上构建并**自动跑 verify**。

### 构建过程中必踩的坑

脚本里都已处理，单独列出来是因为它们都不报"真正的错"，容易卡很久：

1. **`.bat` 文件里不能有非 ASCII 字符** —— cmd 按 ANSI/GBK 读批处理文件，
   里面的中文注释会被当成命令执行，报一堆莫名其妙的错。
2. **必须设 `DISTUTILS_USE_SDK=1` 和 `MSSdk=1`** —— 否则 torch 的 `cpp_extension`
   检测到"VC 环境已激活但 SDK 未声明"，直接拒绝构建。
3. **`setuptools` 必须 <81** —— 见上文。
4. **架构列表不能走 `.bat` 参数** —— `7.0;7.5;...` 里的分号会破坏 cmd 的
   `if (...)` 块解析（报 `7.5 was unexpected at this time`）。用环境变量传。
5. **`TORCH_CUDA_ARCH_LIST` 决定分发范围** —— 只编本机架构快得多，但别人机器上
   若没有对应的 `sm_XX` 会直接跑不起来。
6. **`MAX_JOBS` 别开太大** —— `nvcc` 很吃内存，32 核机器上取 8 比较稳。

## 常见问题

**Q: 构建时 CUDA Toolkit 必须和 torch 的 `cuXXX` 完全一致吗？**
不必，**主版本一致即可**。本仓库发布的轮子就是用 CUDA **12.4** 工具链编译、
在 `torch 2.1.2+cu121`（CUDA 12.1）上运行正常的 —— CUDA 12.x 内部有次版本兼容。

**Q: 我的 GPU 不在 `sm_70`–`sm_90` 里怎么办？**
需要自己构建，并在 `TORCH_CUDA_ARCH_LIST` 里加上你的架构。想兼容未来架构的话
在列表里带 `+PTX`（例如 `8.0+PTX`），让驱动能 JIT —— 代价是轮子更大、构建更久。

**Q: 为什么没有 PTX？**
构建时用的是 `code=sm_XX`（只嵌 SASS）。可以用
`cuobjdump -lelf mmcv/_ext*.pyd` 反查实际嵌了哪些架构，
`cuobjdump -lptx` 看有没有 PTX。

**Q: 能发到 PyPI 吗？**
不行。PyPI 上 `mmcv` 这个发行名属于 OpenMMLab，同名上传会被拒，也不该造成混淆。
GitHub Release 是非官方轮子的通行做法 —— 文件名与官方一致，
`pip install <url>` 依然能满足 `mmcv==2.1.0` 这类依赖声明。

**Q: 装完 import 就报 `no kernel image is available`？**
你的 GPU 架构不在轮子的覆盖范围内，见上文。

## 目录

```
dist/        下载的轮子放这里（发布产物；已 gitignore，不进版本历史）
build/       构建脚本：build.bat（Windows）/ build.sh（Linux、WSL）
verify.py    验证脚本：确认拿到的确实是带 CUDA 算子的完整版
.github/     CI 工作流
LICENSE      Apache-2.0（来自 mmcv 官方）
NOTICE       来源说明与非官方声明
```

## 来源与免责

- 源码完全来自 [open-mmlab/mmcv](https://github.com/open-mmlab/mmcv) 官方 sdist，**未作任何修改**。
- 本仓库只提供**构建脚本与二进制分发**，不对 mmcv 本身做任何支持承诺。
- **上游的问题请报给上游**；构建脚本的问题报本仓库。
- 轮子按 Apache-2.0 的"AS IS"条款提供，不附带任何担保。
