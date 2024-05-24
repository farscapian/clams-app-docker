#!/bin/bash

set -eu

QR_DIMENSIONS="280x280"
OUTPUT_DIR="$LNPLAY_SERVER_PATH/connection_strings"
QRCODES_PATH="$OUTPUT_DIR/qrcodes"
OUTPUT_PDF="$OUTPUT_DIR/${BACKEND_FQDN}_labels.pdf"
mkdir -p "$OUTPUT_DIR"

# Counter to keep track of how many labels we've created
LABEL_COUNT=0

# Temporary directory for intermediate images
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR"
echo "Using temporary directory $TMP_DIR for intermediate images."

# Process the QR code images in batches of 6
BATCH=()
for QR_IMG in "$QRCODES_PATH"/*.png; do
    BATCH+=("$QR_IMG")
    if [ "${#BATCH[@]}" -eq 6 ]; then
        LABEL_COUNT=$((LABEL_COUNT + 1))
        
        # Use montage to create the label image
        montage -geometry "$QR_DIMENSIONS"+10+10 -tile 2x3 -background white -border 10 -bordercolor white "${BATCH[@]}" "$TMP_DIR/label_$LABEL_COUNT.png"
        
        # Reset BATCH array for next group of images
        BATCH=()
    fi
done

# Check for any remaining images in the BATCH array
if [ "${#BATCH[@]}" -gt 0 ]; then
    LABEL_COUNT=$((LABEL_COUNT + 1))
    montage -geometry "$QR_DIMENSIONS"+10+10 -tile 2x3 -background white -border 10 -bordercolor white "${BATCH[@]}" "$TMP_DIR/label_$LABEL_COUNT.png"
fi

# Convert all montage images to a single PDF, setting the page size to 4"x6"
img2pdf $(ls "$TMP_DIR"/*.png | sort -V) --pagesize 4inx6in -o "$OUTPUT_PDF"

# Move the generated labels to the OUTPUT_DIR
rm -r "$TMP_DIR"

echo "Generated $LABEL_COUNT labels in $OUTPUT_PDF."