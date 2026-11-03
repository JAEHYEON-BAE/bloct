#!/bin/sh
set -eu
cd "$(dirname "$0")/../Editor"
npm run check
npm test
npm run build
