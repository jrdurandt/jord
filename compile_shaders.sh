#!/bin/bash

# Script to compile GLSL shaders to SPIR-V

# Ensure source and destination directories exist
SOURCE_DIR="assets/shaders/source"
DEST_DIR="assets/shaders/compiled"

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Check if glslangValidator is installed
if ! command -v glslangValidator &> /dev/null; then
    echo "Error: glslangValidator is not installed or not in PATH"
    echo "Please install the Vulkan SDK which includes glslangValidator"
    exit 1
fi

# Find and compile all vertex shaders (.vert)
for shader in "$SOURCE_DIR"/*.vert; do
    if [ -f "$shader" ]; then
        filename=$(basename "$shader")
        echo "Compiling vertex shader: $filename"
        glslangValidator -V "$shader" -o "$DEST_DIR/$filename.spv"
        if [ $? -eq 0 ]; then
            echo "Successfully compiled $filename to $DEST_DIR/$filename.spv"
            echo ""
        else
            echo "Failed to compile $filename"
            echo ""
        fi
    fi
done

# Find and compile all fragment shaders (.frag)
for shader in "$SOURCE_DIR"/*.frag; do
    if [ -f "$shader" ]; then
        filename=$(basename "$shader")
        echo "Compiling fragment shader: $filename"
        glslangValidator -V "$shader" -o "$DEST_DIR/$filename.spv"
        if [ $? -eq 0 ]; then
            echo "Successfully compiled $filename to $DEST_DIR/$filename.spv"
            echo ""
        else
            echo "Failed to compile $filename"
            echo ""
        fi
    fi
done

echo "Shader compilation complete!"
