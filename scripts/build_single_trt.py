#!/usr/bin/env python3
"""Build a TensorRT engine from the single end-to-end ONNX produced by
make_single_onnx.py (no custom plugin required).

Example:
  python build_single_trt.py \
      weights/onnx/23_36_37/576x960/23_36_37_iters_8_res_576x960.onnx \
      weights/onnx/23_36_37/576x960/23_36_37_iters_8_res_576x960.engine
"""

import argparse
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(
        description="Build a FP16/FP32 TRT engine from a pure-ONNX model.")
    p.add_argument("onnx", type=Path, help="Input .onnx path")
    p.add_argument("engine", type=Path, help="Output .engine path")
    p.add_argument("--fp32", action="store_true",
                   help="Disable FP16 builder flag (default allows FP16).")
    p.add_argument("--workspace-mb", type=int, default=4096,
                   help="TRT workspace memory pool (MiB). Default 4096.")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    if not args.onnx.exists():
        raise FileNotFoundError(args.onnx)
    args.engine.parent.mkdir(parents=True, exist_ok=True)

    import tensorrt as trt

    logger = trt.Logger(trt.Logger.INFO)
    trt.init_libnvinfer_plugins(logger, "")

    builder = trt.Builder(logger)
    if hasattr(trt.NetworkDefinitionCreationFlag, "EXPLICIT_BATCH"):
        flags = 1 << int(trt.NetworkDefinitionCreationFlag.EXPLICIT_BATCH)
        network = builder.create_network(flags)
    else:
        network = builder.create_network()
    parser = trt.OnnxParser(network, logger)

    if not parser.parse_from_file(str(args.onnx)):
        for i in range(parser.num_errors):
            print(parser.get_error(i))
        raise RuntimeError(f"Failed to parse {args.onnx}")

    config = builder.create_builder_config()
    config.set_memory_pool_limit(
        trt.MemoryPoolType.WORKSPACE, args.workspace_mb * 1024 * 1024)
    use_fp16 = not args.fp32
    if use_fp16:
        config.set_flag(trt.BuilderFlag.FP16)

    serialized = builder.build_serialized_network(network, config)
    if serialized is None:
        raise RuntimeError("build_serialized_network failed")

    args.engine.write_bytes(bytes(serialized))
    print(f"Built engine: {args.engine}")
    print(f"Precision: {'FP16 allowed' if use_fp16 else 'FP32'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
