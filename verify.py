"""验证轮子：不只看能不能 import，要确认 CUDA 算子真在、真能在 GPU 上跑。"""
import torch
print("=" * 62)
print(f"torch {torch.__version__}  cuda {torch.version.cuda}  avail {torch.cuda.is_available()}")
print(f"device: {torch.cuda.get_device_name(0)}")

import mmcv, mmcv._ext
print(f"mmcv {mmcv.__version__}")
print(f"C 扩展: {mmcv._ext.__file__}")

from mmcv.ops import nms, ball_query, furthest_point_sample
print("纯 C++ 算子 nms              import OK")
print("CUDA 算子 ball_query / furthest_point_sample  import OK")

# 纯 C++ 算子实跑
b = torch.tensor([[0., 0., 10., 10.], [1., 1., 11., 11.], [50., 50., 60., 60.]], device="cuda")
s = torch.tensor([0.9, 0.8, 0.7], device="cuda")
keep, _ = nms(b, s, 0.5)
print(f"nms(GPU)              -> keep={keep.tolist()}")

# CUDA 算子实跑
pts = torch.rand(2, 100, 3, device="cuda")
cent = torch.rand(2, 10, 3, device="cuda")
dists = ball_query(0.0, 0.3, 8, pts, cent)
print(f"ball_query(GPU)       -> {tuple(dists.shape)}")

idx = furthest_point_sample(pts, 16)
print(f"furthest_point_sample(GPU) -> {tuple(idx.shape)} max_idx={int(idx.max())}")

print("=" * 62)
print("✅ 这是带 CUDA 算子的完整 mmcv，不是 mmcv-lite")
