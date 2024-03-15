#!/usr/bin/env bash
# Aspect build for macos arm64
set -e

# Set home directory
BASEDIR="$PWD"

# Create build directory
BUILDDIR="assets/models/aspect_2.5"
DEPDIR="$BUILDDIR/dependencies"

if [ -d "$BUILDDIR" ]; then
    echo "Error: Directory '$BUILDDIR' already exists. Exiting." >&2
    exit 1
fi

mkdir -p "$BUILDDIR" && mkdir -p "$DEPDIR"
echo "Directory '$BUILDDIR' created ..."
echo "============================================="

# Install dealii and dependencies with candi
echo "Cloning candi from: https://github.com/dealii/candi ..."
echo "Changing to candi version 9.4.0-r2 ..."
echo "see https://github.com/dealii/candi/issues/309#issuecomment-1386276193"
echo "============================================="
git clone git@github.com:dealii/candi.git "$DEPDIR"
cd "$DEPDIR/candi" && git checkout 438b4a1 && cd "$BASEDIR"
echo "============================================="

# Install dealii and dependencies
echo "Installing dealii v9.4.0 dependencies to: '$DEPDIR/dealii' ..."
echo "============================================="
./$DEPDIR/candi/candi.sh -j 8 -p "$DEPDIR/dealii" --packages="trilinos p4est dealii"
echo "============================================="

# Install aspect
# https://github.com/geodynamics/aspect
echo "Cloning aspect from: https://github.com/geodynamics/aspect ..."
echo "Changing to aspect version 2.5 ..."
echo "============================================="
git clone git@github.com:geodynamics/aspect.git "$DEPDIR"
cd "$DEPDIR/aspect" && git checkout aspect-2.5 && cd "$BASEDIR"
# Enable dealii
. $DEPDIR/dealii/configuration/enable.sh
echo "============================================="

# Build "out of source" aspect 2.5
echo "Installing aspect v2.5 ..."
echo "============================================="
cd "$BUILDDIR"
cmake $DEPDIR/aspect && make
echo "============================================="