#! /bin/bash
BASEDIR=$(dirname "$0")
for filename in $BASEDIR/*.vert; do
    glslc -c $filename -o $filename.spv
done
for filename in $BASEDIR/*.frag; do
    glslc -c $filename -o $filename.spv
done
for filename in $BASEDIR/*.comp; do
    glslc -c $filename -o $filename.spv
done