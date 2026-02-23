# Jetson Nano JetPack SDK Tests

Health check scripts for **NVIDIA Jetson Nano** running **JetPack 4.6.x** on **Ubuntu 22.04**.  
Verifies that the full SDK stack — CUDA, cuDNN, TensorRT, VPI, OpenCV, GStreamer and more — is correctly installed and functional.

---

## Scripts

### `sdk-status.sh` — Pretty live status overview

Runs all checks and prints a clean, color-coded summary table - no log file is created.

Example output:

```
═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
  NVIDIA JetPack SDK Health Check  ·  2026-02-23 12:26:15
═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
 Copyright (c) 2026 Mischa (Michael Schaefer) 
 https://github.com/mischa-robots/jetpack-sdk-test/ 

        Component                       Version             Info / Hint
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

───── System / L4T ─────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  L4T / Tegra Release             R32.7.6             aarch64 · JetPack 4.6.x
  ✅  Linux Kernel                    4.9.337-tegra       Ubuntu 22.04.5 LTS
  ✅  Python                          3.10.12             system python3
  ✅  L4T Core Packages               32.7.6-20241104234540  nvidia-l4t-core

───── CUDA ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  CUDA Toolkit                    10.2.300            /usr/local/cuda
  ✅  nvcc Compiler                   V10.2.300           /usr/local/cuda/bin/nvcc
  ✅  CUDA Runtime (smoke test)       OK                  NVIDIA Tegra X1 cc5.3

───── cuDNN ────────────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  cuDNN Package                   8.2.1.32-1+cuda10.2  libcudnn8
  ✅  cuDNN Shared Library            loadable            libcudnn.so.8

───── TensorRT ─────────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  TensorRT (trtexec)              TensorRT v8201      /usr/src/tensorrt/bin/trtexec
  ✅  TensorRT Shared Library         loadable            libnvinfer.so.8
  ⚠️    TensorRT Python                 —                 needs Python 3.6 — not in Ubuntu 22.04

───── VPI ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  VPI Package                     1.2.3               libnvvpi
  ✅  VPI Shared Library              loadable            libnvvpi.so.1
  ⚠️    VPI Python                      —                 needs Python 3.6 — not in Ubuntu 22.04

───── OpenCV ───────────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  OpenCV                          4.8.1               cv2 import OK
  ✅  OpenCV CUDA Support             enabled             CUDA 10.2.300

───── VisionWorks ──────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  VisionWorks                     1.6.0.501           libvisionworks (deprecated in JP5+)

───── Multimedia / GStreamer ───────────────────────────────────────────────────────────────────────────────────────────
  ✅  GStreamer                       1.20.3              gst-inspect-1.0 found
  ✅  gst · nvvidconv                present             Jetson HW-accelerated element
  ✅  gst · nvv4l2decoder            present             Jetson HW-accelerated element
  ✅  gst · nvv4l2h264enc            present             Jetson HW-accelerated element

───── Container Runtime ────────────────────────────────────────────────────────────────────────────────────────────────
  ⚠️    Docker                          —                 not installed

───── Optional SDKs ────────────────────────────────────────────────────────────────────────────────────────────────────
  ✅  DeepStream                      6.0.1               deepstream-app
  ⚠️    Triton Inference Server         —                 not installed (optional)

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

  SUMMARY    ✅ PASS: 21    ⚠️  WARN: 4     ❌ FAIL: 0   

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

  ℹ️  Python bindings (TensorRT / VPI):
     JetPack 4.6.x wrappers require Python 3.6 — Ubuntu 22.04 ships 3.10.12.
     C/C++ libs and trtexec work fine. import tensorrt / import vpi failing is expected.
```

### `sdk-test.sh` — Functional test suite

Runs deeper validation checks including compiling and executing a minimal CUDA program, querying device properties, and testing library loading. Produces a structured PASS / WARN / FAIL log.

---

## Usage

```bash
git clone https://github.com/mischa-robots/jetpack-sdk-test.git
cd jetpack-sdk-test

chmod +x sdk-status.sh sdk-test.sh

./sdk-status.sh   # pretty live overview
./sdk-test.sh     # full functional test suite
```

Neither script requires `sudo`.

---

## What gets checked

| Category | Checks |
|---|---|
| **System** | L4T release, kernel version, distro, Python, L4T core packages |
| **CUDA** | Toolkit version, nvcc compiler, runtime smoke test (compile + run) |
| **cuDNN** | Package version, shared library load |
| **TensorRT** | trtexec binary, Python bindings, shared library load |
| **VPI** | Package version, Python bindings, shared library load |
| **OpenCV** | Import, CUDA support flag |
| **VisionWorks** | Package presence |
| **GStreamer** | Version, Jetson HW elements (`nvvidconv`, `nvv4l2decoder`, `nvv4l2h264enc`) |
| **Container Runtime** | Docker, NVIDIA container runtime, nvidia-container-cli |
| **Optional SDKs** | DeepStream, Triton Inference Server |

---

## Notes on Python bindings

JetPack 4.6.x ships Python bindings for TensorRT and VPI that require **Python 3.6**.  
Ubuntu 22.04 provides Python 3.10 — so `import tensorrt` and `import vpi` will fail.  
This is expected. The C/C++ libraries and `trtexec` work fine.

---

## Tested on

- **Hardware:** NVIDIA Jetson Nano Developer Kit (4 GB)
- **JetPack:** 4.6.6
- **L4T:** R32.7.6
- **OS:** Ubuntu 22.04.5 LTS (Jammy Jellyfish)
- **CUDA:** 10.2.300
- **cuDNN:** 8.2.1.32
- **TensorRT:** 8.2.1.9
- **OpenCV:** 4.8.1 (with CUDA)
