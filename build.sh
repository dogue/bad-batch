#!/usr/bin/env bash

sokol-shdc -i src/shader.glsl -o src/shader.odin -l glsl430 -f sokol_odin
odin build src -out:build/main

if [ "$1" == "run" ]; then
    build/main
fi
