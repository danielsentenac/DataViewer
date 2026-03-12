#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAME_DIR="${1:-/home/sentenac/TOMCAT/Fr}"
OUTPUT_DIR="${2:-$ROOT_DIR/tomcat-json-adapter/build/native}"
OUTPUT_LIB="${3:-$OUTPUT_DIR/libvirgo_frame_jni.so}"
NATIVE_SRC="$ROOT_DIR/tomcat-json-adapter/src/main/native/virgo_frame_jni.c"

if [[ ! -d "$FRAME_DIR" ]]; then
  echo "Frame source directory not found: $FRAME_DIR" >&2
  exit 1
fi

if [[ ! -f "$NATIVE_SRC" ]]; then
  echo "Native source not found: $NATIVE_SRC" >&2
  exit 1
fi

if [[ -n "${JAVA_HOME:-}" ]]; then
  JAVA_HOME_DIR="$JAVA_HOME"
else
  JAVAC_BIN="$(command -v javac)"
  if [[ -z "$JAVAC_BIN" ]]; then
    echo "javac not found and JAVA_HOME is not set." >&2
    exit 1
  fi
  JAVA_HOME_DIR="$(cd "$(dirname "$JAVAC_BIN")/.." && pwd)"
fi

JNI_OS_DIR="linux"
case "$(uname -s)" in
  Darwin)
    JNI_OS_DIR="darwin"
    ;;
  Linux)
    JNI_OS_DIR="linux"
    ;;
  *)
    echo "Unsupported platform for JNI include path: $(uname -s)" >&2
    exit 1
    ;;
esac

mkdir -p "$OUTPUT_DIR"
mapfile -t ZLIB_SOURCES < <(find "$FRAME_DIR/zlib" -maxdepth 1 -type f -name '*.c' | sort)

if [[ ${#ZLIB_SOURCES[@]} -eq 0 ]]; then
  echo "No Frame zlib sources found under $FRAME_DIR/zlib" >&2
  exit 1
fi

gcc \
  -shared \
  -fPIC \
  -O2 \
  -std=c99 \
  -D_POSIX_C_SOURCE=200809L \
  "-DFR_VERSION=\"local-jni\"" \
  "-DFR_PATH=\"$FRAME_DIR\"" \
  -I"$JAVA_HOME_DIR/include" \
  -I"$JAVA_HOME_DIR/include/$JNI_OS_DIR" \
  -I"$FRAME_DIR" \
  -I"$FRAME_DIR/zlib" \
  -o "$OUTPUT_LIB" \
  "$NATIVE_SRC" \
  "$FRAME_DIR/FrFilter.c" \
  "$FRAME_DIR/FrIO.c" \
  "$FRAME_DIR/FrameL.c" \
  "${ZLIB_SOURCES[@]}" \
  -lm

echo "$OUTPUT_LIB"
