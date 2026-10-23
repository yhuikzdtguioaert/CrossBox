#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <firmware>" >&2
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "Error: file not found: $1" >&2
  exit 1
fi

if ! command -v ubireader_extract_images >/dev/null 2>&1; then
  echo "Error: ubireader_extract_images not found (install ubi_reader)" >&2
  exit 1
fi

if ! command -v unsquashfs >/dev/null 2>&1; then
  echo "Error: unsquashfs not found (install squashfs-tools)" >&2
  exit 1
fi

firmware="$1"
if [ -e tmp ] || [ -e squashfs-root ]; then
  echo "Error: use a clean working directory; tmp or squashfs-root already exists" >&2
  exit 1
fi
pos=$(python3 - "$firmware" <<'PY'
import sys
with open(sys.argv[1], 'rb') as image:
    consumed, tail = 0, b''
    while chunk := image.read(65536):
        data = tail + chunk
        index = data.find(b'UBI#')
        if index >= 0:
            offset = consumed - len(tail) + index
            if offset == 0:
                raise SystemExit('Error: raw UBI image has no TP-Link firmware header')
            print(offset)
            break
        consumed += len(chunk)
        tail = data[-3:]
    else:
        raise SystemExit("Error: UBI header marker ('UBI#') not found")
PY
)

mkdir -p tmp

dd if="$firmware" of=tmp/header.bin bs="$pos" count=1 status=none
dd if="$firmware" of=tmp/ubi.img bs="$pos" skip=1 status=none

(
  cd tmp
  ubireader_extract_images ubi.img
)

rootfs_img=$(find tmp -name "*rootfs.ubifs" | head -n 1)
if [ -z "$rootfs_img" ]; then
  echo "Error: extracted rootfs volume not found in tmp" >&2
  exit 1
fi

unsquashfs -f "$rootfs_img"

echo "Successfully unpacked rootfs to squashfs-root. Modify anything you want and repack the firmware"
