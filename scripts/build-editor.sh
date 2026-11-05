#!/bin/sh
set -eu
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")/../Editor"
if [ ! -d node_modules ]; then
    echo 'Run npm ci in Editor/ before building Bloct.' >&2
    exit 1
fi
npm run build
if [ "$#" -gt 0 ]; then
    mkdir -p "$1"
    cp dist/blocks.js dist/visual.css dist/math.js dist/math.css dist/editor-licenses.txt "$1/"
fi
