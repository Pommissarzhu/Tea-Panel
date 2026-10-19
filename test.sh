#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/module-cache
xcrun swiftc -swift-version 6 -module-cache-path "$PWD/build/module-cache" \
  Sources/TeaCore.swift Tests/TeaCoreTests.swift -o build/TeaCoreTests
build/TeaCoreTests

if [[ "${1:-}" == "--motion" ]]; then
  xcrun swiftc -swift-version 6 -D TEA_PANEL_TESTING \
    -target arm64-apple-macosx13.0 -module-cache-path "$PWD/build/module-cache" \
    Sources/TeaCore.swift Sources/TeaMotion.swift Sources/TeaViews.swift Sources/TeaPanelApp.swift \
    Tests/TeaMotionTests.swift -o build/TeaMotionTests
  build/TeaMotionTests
fi
