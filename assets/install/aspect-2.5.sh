#!/usr/bin/env bash

set -e

CURDIR="$1"
ASPECTPATH="$2"
DEPDIR="$ASPECTPATH/deps"

if [ -d "$ASPECTPATH" ]; then
    echo "Error: Directory '$ASPECTPATH' already exists. Exiting." >&2
    exit 1
fi

mkdir -p "$ASPECTPATH" && mkdir -p "$DEPDIR"

#echo "Cloning candi from: https://github.com/dealii/candi ..."
#echo "Changing to candi version 9.4.0-r2 ..."
#echo "see https://github.com/dealii/candi/issues/309#issuecomment-1386276193"
#echo "============================================="
#git clone -q git@github.com:dealii/candi.git "$DEPDIR/candi" && cd "$DEPDIR/candi" && \
#	git checkout -q 438b4a1 && cd "$CURDIR"
#
#echo "Installing dealii v9.4.0 dependencies ..."
#echo "============================================="
#cd "$DEPDIR/candi" && { echo -e "\n"; echo -e "\n"; } | \
#	./candi.sh -j 8 -p "$DEPDIR/dealii" --packages="trilinos p4est dealii" && \
#	rm -rf "$DEPDIR/dealii/tmp" && cd "$CURDIR"
#
#echo "Cloning aspect from: https://github.com/geodynamics/aspect ..."
#echo "Changing to aspect version 2.5 ..."
#echo "============================================="
#git clone git@github.com:geodynamics/aspect.git "$DEPDIR/aspect" && cd "$DEPDIR/aspect" && \
#	git checkout aspect-2.5 && source $DEPDIR/dealii/configuration/enable.sh && cd "$CURDIR"
#
#echo "Installing aspect v2.5 ..."
#echo "============================================="
#cd "$ASPECTPATH" && cmake $DEPDIR/aspect && make && cd "$CURDIR"
#
#echo "aspect v2.5 build successful!"