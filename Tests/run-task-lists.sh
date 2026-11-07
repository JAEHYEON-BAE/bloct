#!/bin/sh
# The former 17-check legacy task bridge is retired. Aa task/save/history
# coverage now lives in the production ContentView visual/native harness.
set -eu
cd "$(dirname "$0")/.."
exec sh Tests/run-visual-native.sh
