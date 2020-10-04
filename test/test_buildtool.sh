#!/bin/sh

../bin/appctl-buildtool.sh                        \
    --src-dir=$PWD/env/source              \
    --pkg-dir=$PWD/env/package             \
    --wrk-dir=$PWD/env/work
