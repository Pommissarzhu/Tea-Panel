#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/module-cache
xcrun swiftc -swift-version 6 -module-cache-path "$PWD/build/module-cache" \
  Sources/TeaCore.swift Tests/TeaCoreTests.swift -o build/TeaCoreTests
build/TeaCoreTests
