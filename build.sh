#!/bin/bash
# Builds NppSwaggerPanel.dylib (universal) and packages it as a zip.
set -e
cd "$(dirname "$0")"
mkdir -p build/NppSwaggerPanel
clang++ -std=c++17 -fobjc-arc -fvisibility=hidden -dynamiclib \
  -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  -Iinclude -framework Cocoa -framework WebKit \
  -Wl,-current_version,1.0.0 \
  src/NppSwaggerPanel.mm -o build/NppSwaggerPanel/NppSwaggerPanel.dylib
rm -rf build/NppSwaggerPanel/resources && cp -R resources build/NppSwaggerPanel/resources
(cd build && rm -f NppSwaggerPanel.zip && zip -qr NppSwaggerPanel.zip NppSwaggerPanel)
echo "Built build/NppSwaggerPanel.zip"
