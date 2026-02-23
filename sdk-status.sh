#!/usr/bin/env bash

# Jetson Nano JetPack 4.6.x SDK Status Check
# Copyright (c) 2026 Mischa (Michael Schaefer)
# https://github.com/mischa-robots/jetpack-sdk-test/
# MIT License

# No 'set -e' — we handle all errors explicitly with || true / if-else
set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

PASS_CNT=0; FAIL_CNT=0; WARN_CNT=0

have() { command -v "$1" >/dev/null 2>&1; }

py_dlopen() {
  local lib="$1"
  python3 - 2>/dev/null <<PY
import ctypes, sys, os, glob

lib = "$lib"
search_dirs = [
    "/usr/lib/aarch64-linux-gnu",
    "/usr/local/lib/aarch64-linux-gnu",
    "/usr/local/cuda/lib64",
    "/usr/lib",
    "/usr/local/lib",
]

try:
    ctypes.CDLL(lib)
    sys.exit(0)
except Exception:
    pass

for d in search_dirs:
    for f in sorted(glob.glob(os.path.join(d, lib + "*"))):
        try:
            ctypes.CDLL(f)
            sys.exit(0)
        except Exception:
            continue

sys.exit(1)
PY
}

# ── Layout helpers ─────────────────────────────────────────────────────────────
TW=$(tput cols 2>/dev/null || echo 100)
# Section headers and bars are capped so they don't stretch across huge monitors
CONTENT_W=120

hbar() {
  local bar
  bar=$(printf '─%.0s' $(seq 1 "$TW"))
  printf "${CYAN}%s${RESET}\n" "$bar"
}
dbar() {
  local bar
  bar=$(printf '═%.0s' $(seq 1 "$TW"))
  printf "${BOLD}${CYAN}%s${RESET}\n" "$bar"
}
section() {
  local title=" $* "
  local tlen=${#title}
  local rpad=$(( CONTENT_W - tlen - 5 ))
  [[ $rpad -lt 2 ]] && rpad=2
  local lside
  lside=$(printf '─%.0s' $(seq 1 5))
  local rside
  rside=$(printf '─%.0s' $(seq 1 $rpad))
  printf "\n${CYAN}%s${BOLD}%s${RESET}${CYAN}%s${RESET}\n" "$lside" "$title" "$rside"
}

# ── Spinner ───────────────────────────────────────────────────────────────────
# Spinner writes to stderr only; resolved rows go to stdout.
FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
_SPIN_PID=""

start_spin() {
  local label="$1"
  printf "  ${CYAN}⠋${RESET}  ${BOLD}%-30s${RESET}  ${DIM}checking...${RESET}" "$label" >&2
  (
    local i=0
    while true; do
      sleep 0.08
      local f="${FRAMES[$((i % 10))]}"
      printf "\r  ${CYAN}%s${RESET}  ${BOLD}%-30s${RESET}  ${DIM}checking...${RESET}" "$f" "$label" >&2
      i=$((i + 1))
    done
  ) &
  _SPIN_PID=$!
  disown "$_SPIN_PID" 2>/dev/null || true
}

stop_spin() {
  if [[ -n "$_SPIN_PID" ]]; then
    kill "$_SPIN_PID" 2>/dev/null || true
    wait "$_SPIN_PID" 2>/dev/null || true
    _SPIN_PID=""
    printf "\r\033[2K" >&2
  fi
}

trap 'stop_spin' EXIT INT TERM

# resolve STATUS LABEL VERSION HINT
resolve() {
  local status="$1" label="$2" version="$3" hint="$4"
  stop_spin
  local sym color
  case "$status" in
    PASS) sym="${GREEN}✅${RESET}"; color="$GREEN";  PASS_CNT=$((PASS_CNT+1)) ;;
    FAIL) sym="${RED}❌${RESET}";   color="$RED";    FAIL_CNT=$((FAIL_CNT+1)) ;;
    WARN) sym="${YELLOW}⚠️  ${RESET}"; color="$YELLOW"; WARN_CNT=$((WARN_CNT+1)) ;;
  esac
  printf "  %s  ${color}${BOLD}%-30s${RESET}  ${color}%-18s${RESET}  ${DIM}%s${RESET}\n" \
    "$sym" "$label" "${version:----}" "$hint"
}

# ── Header ────────────────────────────────────────────────────────────────────
dbar
printf "${BOLD}${CYAN}  NVIDIA JetPack SDK Health Check  ·  $(date '+%Y-%m-%d %H:%M:%S')${RESET}\n"
dbar
printf "${DIM} Copyright (c) 2026 Mischa (Michael Schaefer) ${RESET}\n"
printf "${DIM} https://github.com/mischa-robots/jetpack-sdk-test/ ${RESET}\n"
printf "\n  ${DIM}%-4s  %-30s  %-18s  %s${RESET}\n" "" "Component" "Version" "Info / Hint"
hbar

# ═════════════════════════════════════════════════════════════════════════════
section "System / L4T"

start_spin "L4T / Tegra Release"
if [[ -f /etc/nv_tegra_release ]]; then
  L4T_RAW=$(cat /etc/nv_tegra_release 2>/dev/null || true)
  L4T_R=$(printf '%s' "$L4T_RAW"   | grep -oE 'R[0-9]+' | head -1 || true)
  L4T_REV=$(printf '%s' "$L4T_RAW" | grep -oE 'REVISION: [0-9.]+' | awk '{print $2}' || true)
  resolve PASS "L4T / Tegra Release" "${L4T_R}.${L4T_REV}" "$(uname -m) · JetPack 4.6.x"
else
  resolve FAIL "L4T / Tegra Release" "—" "/etc/nv_tegra_release missing"
fi

start_spin "Linux Kernel"
KERN_VER=$(uname -r 2>/dev/null || echo "—")
DISTRO=""
if [[ -f /etc/os-release ]]; then
  DISTRO=$(grep ^PRETTY_NAME /etc/os-release | cut -d'"' -f2 || true)
fi
resolve PASS "Linux Kernel" "$KERN_VER" "$DISTRO"

start_spin "Python"
PY_VER=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "—")
resolve PASS "Python" "$PY_VER" "system python3"

start_spin "L4T Core Packages"
L4T_PKG=$(dpkg -l 2>/dev/null | awk '/nvidia-l4t-core/{print $3; exit}' || true)
if [[ -n "$L4T_PKG" ]]; then
  resolve PASS "L4T Core Packages" "$L4T_PKG" "nvidia-l4t-core"
else
  resolve WARN "L4T Core Packages" "—" "nvidia-l4t-core not found in dpkg"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "CUDA"

CUDA_HOME="/usr/local/cuda"
NVCC_BIN="$CUDA_HOME/bin/nvcc"
NVCC_OK=0
CUDA_VER="—"

start_spin "CUDA Toolkit"
if [[ -f "$CUDA_HOME/version.txt" ]]; then
  CUDA_VER=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$CUDA_HOME/version.txt" 2>/dev/null | head -1 || true)
  resolve PASS "CUDA Toolkit" "${CUDA_VER:-present}" "$CUDA_HOME"
else
  resolve FAIL "CUDA Toolkit" "—" "$CUDA_HOME/version.txt not found"
fi

start_spin "nvcc Compiler"
if [[ -x "$NVCC_BIN" ]]; then
  NVCC_VER=$("$NVCC_BIN" --version 2>&1 | grep -oE 'V[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  NVCC_OK=1
  resolve PASS "nvcc Compiler" "${NVCC_VER:-present}" "$NVCC_BIN"
else
  resolve FAIL "nvcc Compiler" "—" "not found at $NVCC_BIN"
fi

start_spin "CUDA Runtime (smoke test)"
if [[ "$NVCC_OK" -eq 1 ]]; then
  _TMP=$(mktemp -d)
  cat > "$_TMP/s.cu" <<'CU'
#include <cstdio>
#include <cuda_runtime.h>
int main(){
  int n=0;
  if(cudaGetDeviceCount(&n)!=cudaSuccess||n<1) return 1;
  cudaDeviceProp p{};
  cudaGetDeviceProperties(&p,0);
  printf("%s cc%d.%d",p.name,p.major,p.minor);
  return 0;
}
CU
  if "$NVCC_BIN" -O2 "$_TMP/s.cu" -o "$_TMP/s" >/dev/null 2>&1; then
    SMOKE=$("$_TMP/s" 2>/dev/null || true)
    if [[ -n "$SMOKE" ]]; then
      resolve PASS "CUDA Runtime (smoke test)" "OK" "$SMOKE"
    else
      resolve FAIL "CUDA Runtime (smoke test)" "—" "binary produced no output"
    fi
  else
    resolve FAIL "CUDA Runtime (smoke test)" "—" "nvcc compilation failed"
  fi
  rm -rf "$_TMP"
else
  resolve WARN "CUDA Runtime (smoke test)" "—" "skipped — nvcc not usable"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "cuDNN"

start_spin "cuDNN Package"
CUDNN_VER=$(dpkg -l 2>/dev/null | awk '/libcudnn8 /{print $3; exit}' || true)
if [[ -n "$CUDNN_VER" ]]; then
  resolve PASS "cuDNN Package" "$CUDNN_VER" "libcudnn8"
else
  resolve WARN "cuDNN Package" "—" "libcudnn8 not found in dpkg"
fi

start_spin "cuDNN Shared Library"
if py_dlopen "libcudnn.so.8" || py_dlopen "libcudnn.so"; then
  resolve PASS "cuDNN Shared Library" "loadable" "libcudnn.so.8"
else
  resolve FAIL "cuDNN Shared Library" "—" "dlopen libcudnn.so.8 failed"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "TensorRT"

TRTEXEC=""
for _p in /usr/src/tensorrt/bin/trtexec /usr/bin/trtexec /usr/local/bin/trtexec; do
  if [[ -x "$_p" ]]; then TRTEXEC="$_p"; break; fi
done

start_spin "TensorRT (trtexec)"
if [[ -n "$TRTEXEC" ]]; then
  TRT_H=$("$TRTEXEC" --help 2>&1 || true)
  TRT_TAG=$(printf '%s' "$TRT_H" | head -1 | grep -oE '\[TensorRT v[0-9]+\]' | tr -d '[]' || true)
  resolve PASS "TensorRT (trtexec)" "${TRT_TAG:-present}" "$TRTEXEC"
else
  resolve WARN "TensorRT (trtexec)" "—" "trtexec not found"
fi

start_spin "TensorRT Shared Library"
if py_dlopen "libnvinfer.so.8" || py_dlopen "libnvinfer.so"; then
  resolve PASS "TensorRT Shared Library" "loadable" "libnvinfer.so.8"
else
  resolve FAIL "TensorRT Shared Library" "—" "dlopen libnvinfer.so.8 failed"
fi

start_spin "TensorRT Python"
TRT_PY=$(python3 -c "import tensorrt as trt; print(trt.__version__)" 2>/dev/null || true)
if [[ -n "$TRT_PY" ]]; then
  resolve PASS "TensorRT Python" "$TRT_PY" "import tensorrt OK"
else
  resolve WARN "TensorRT Python" "—" "needs Python 3.6 — not in Ubuntu 22.04"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "VPI"

start_spin "VPI Package"
VPI_VER=$(dpkg -l 2>/dev/null | awk '/libnvvpi/{print $3; exit}' || true)
if [[ -n "$VPI_VER" ]]; then
  resolve PASS "VPI Package" "$VPI_VER" "libnvvpi"
else
  resolve WARN "VPI Package" "—" "not found in dpkg"
fi

start_spin "VPI Shared Library"
if py_dlopen "libnvvpi.so.1" || py_dlopen "libnvvpi.so"; then
  resolve PASS "VPI Shared Library" "loadable" "libnvvpi.so.1"
else
  resolve WARN "VPI Shared Library" "—" "dlopen libnvvpi.so* failed"
fi

start_spin "VPI Python"
VPI_PY=$(python3 -c "import vpi; print(getattr(vpi,'__version__','ok'))" 2>/dev/null || true)
if [[ -n "$VPI_PY" ]]; then
  resolve PASS "VPI Python" "$VPI_PY" "import vpi OK"
else
  resolve WARN "VPI Python" "—" "needs Python 3.6 — not in Ubuntu 22.04"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "OpenCV"

start_spin "OpenCV"
OCV_INFO=$(python3 - 2>/dev/null <<'PY' || true
import sys
try:
    import cv2
    cuda = "NO"
    try:
        for l in cv2.getBuildInformation().splitlines():
            if ("NVIDIA CUDA" in l or "Use CUDA" in l) and "YES" in l:
                cuda = "YES"
                break
    except Exception:
        pass
    print("OK|" + cv2.__version__ + "|" + cuda)
except Exception as e:
    print("FAIL||NO|" + str(e))
PY
)
OCV_ST=$(printf '%s' "$OCV_INFO"   | cut -d'|' -f1)
OCV_VER=$(printf '%s' "$OCV_INFO"  | cut -d'|' -f2)
OCV_CUDA=$(printf '%s' "$OCV_INFO" | cut -d'|' -f3)
OCV_ERR=$(printf '%s' "$OCV_INFO"  | cut -d'|' -f4)

if [[ "$OCV_ST" == "OK" ]]; then
  resolve PASS "OpenCV" "$OCV_VER" "cv2 import OK"
else
  resolve FAIL "OpenCV" "—" "import failed: $OCV_ERR"
fi

start_spin "OpenCV CUDA Support"
if [[ "$OCV_ST" == "OK" ]]; then
  if [[ "$OCV_CUDA" == "YES" ]]; then
    resolve PASS "OpenCV CUDA Support" "enabled" "CUDA $CUDA_VER"
  else
    resolve FAIL "OpenCV CUDA Support" "disabled" "built without CUDA support"
  fi
else
  resolve WARN "OpenCV CUDA Support" "—" "skipped — OpenCV not available"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "VisionWorks"

start_spin "VisionWorks"
VW_VER=$(dpkg -l 2>/dev/null | awk '/libvisionworks /{print $3; exit}' || true)
if [[ -n "$VW_VER" ]]; then
  resolve PASS "VisionWorks" "$VW_VER" "libvisionworks (deprecated in JP5+)"
else
  resolve WARN "VisionWorks" "—" "not installed (optional / deprecated)"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "Multimedia / GStreamer"

start_spin "GStreamer"
if have gst-inspect-1.0; then
  GST_VER=$(gst-inspect-1.0 --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
  resolve PASS "GStreamer" "${GST_VER:-present}" "gst-inspect-1.0 found"
  for _elem in nvvidconv nvv4l2decoder nvv4l2h264enc; do
    start_spin "gst · $_elem"
    if gst-inspect-1.0 "$_elem" >/dev/null 2>&1; then
      resolve PASS "gst · $_elem" "present" "Jetson HW-accelerated element"
    else
      resolve WARN "gst · $_elem" "—" "missing — check nvidia-l4t-gstreamer"
    fi
  done
else
  resolve WARN "GStreamer" "—" "gst-inspect-1.0 not found"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "Container Runtime"

start_spin "Docker"
if have docker; then
  DOCKER_VER=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  resolve PASS "Docker" "${DOCKER_VER:-present}" "docker CLI"

  start_spin "NVIDIA Container Runtime"
  if docker info 2>/dev/null | grep -qi nvidia; then
    resolve PASS "NVIDIA Container Runtime" "detected" "nvidia runtime in docker info"
  else
    resolve WARN "NVIDIA Container Runtime" "?" "not visible in docker info"
  fi

  start_spin "nvidia-container-cli"
  if have nvidia-container-cli; then
    NV_CLI_VER=$(nvidia-container-cli --version 2>/dev/null | grep -oE '[0-9]+\.[0-9.]+' | head -1 || true)
    resolve PASS "nvidia-container-cli" "${NV_CLI_VER:-present}" ""
  else
    resolve WARN "nvidia-container-cli" "—" "not found"
  fi
else
  resolve WARN "Docker" "—" "not installed"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "Optional SDKs"

start_spin "DeepStream"
if have deepstream-app; then
  DS_VER=$(deepstream-app --version-all 2>/dev/null \
    | grep -i "deepstream-app version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  resolve PASS "DeepStream" "${DS_VER:-present}" "deepstream-app"
else
  resolve WARN "DeepStream" "—" "not installed (optional)"
fi

start_spin "Triton Inference Server"
TRITON_VER=$(dpkg -l 2>/dev/null | awk '/triton|libtritonserver/{print $3; exit}' || true)
if [[ -n "$TRITON_VER" ]]; then
  resolve PASS "Triton Inference Server" "$TRITON_VER" ""
else
  resolve WARN "Triton Inference Server" "—" "not installed (optional)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════
echo
hbar
echo
printf "  ${BOLD}SUMMARY${RESET}    "
printf "${GREEN}${BOLD}✅ PASS: %-4s${RESET}  " "$PASS_CNT"
printf "${YELLOW}${BOLD}⚠️  WARN: %-4s${RESET}  " "$WARN_CNT"
printf "${RED}${BOLD}❌ FAIL: %-4s${RESET}\n" "$FAIL_CNT"
echo
hbar

if ! have nvcc && [[ -x "$NVCC_BIN" ]]; then
  printf "\n  ${YELLOW}💡 nvcc not in PATH.${RESET} To fix permanently:\n"
  printf "  ${DIM}printf 'export PATH=/usr/local/cuda/bin:\${PATH}\\n"
  printf "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\${LD_LIBRARY_PATH:-}\\n'"
  printf " | sudo tee /etc/profile.d/cuda.sh${RESET}\n"
  printf "  ${DIM}source /etc/profile.d/cuda.sh${RESET}\n"
fi

printf "\n  ${CYAN}ℹ️  Python bindings (TensorRT / VPI):${RESET}\n"
printf "     JetPack 4.6.x wrappers require ${BOLD}Python 3.6${RESET} — Ubuntu 22.04 ships ${BOLD}%s${RESET}.\n" "$PY_VER"
printf "     C/C++ libs and trtexec work fine. ${DIM}import tensorrt${RESET} / ${DIM}import vpi${RESET} failing is expected.\n\n"

[[ "$FAIL_CNT" -gt 0 ]] && exit 1
exit 0
