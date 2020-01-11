#!/bin/sh

set -euxo pipefail

swift run swiftlint --strict
swift test --generate-linuxmain
swift test
git diff --exit-code
