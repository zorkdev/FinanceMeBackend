#!/bin/sh

set -euxo pipefail

swift run swiftlint --strict
swift test
