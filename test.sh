#!/usr/bin/env sh

set -euo pipefail

swift run swiftlint --strict
swift test
