#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <new firmware filename>" >&2
  exit 1
fi

if [ -f "$1" ]; then
  echo "Error: file already exists: $1" >&2
  exit 1
fi

if [ ! -d "squashfs-root" ]; then
  echo "Error: squashfs-root directory not found" >&2
  exit 1
fi

if [ ! -f "tmp/header.bin" ]; then
  echo "Error: tmp/header.bin not found (did you run 01-unpack.sh first?)" >&2
  exit 1
fi

if ! command -v mksquashfs >/dev/null 2>&1; then
  echo "Error: mksquashfs not found (install squashfs-tools)" >&2
  exit 1
fi

if ! command -v ubinize >/dev/null 2>&1; then
  echo "Error: ubinize not found (install mtd-utils)" >&2
  exit 1
fi

if [ ! -x "$script_dir/bin/md5-fix" ]; then
  echo "Building md5-fix..."
  make -C "$script_dir"
fi

firmware="$1"

mksquashfs squashfs-root/ tmp/rootfs.bin -comp xz -b 256K -noappend

kernel=$(find tmp -name "*kernel.ubifs" | head -n 1)
if [ -z "$kernel" ]; then
  echo "Error: extracted kernel volume not found in tmp" >&2
  exit 1
fi

cp -f "$kernel" tmp/kernel.itb
ubinize -m 2048 -p 128KiB -o tmp/ubi-new.img etc/ubinize-ipq50xx.cfg
cat tmp/header.bin tmp/ubi-new.img > "$firmware"
printf '\x50\x72' | dd of="$firmware" bs=1 seek=28 count=2 conv=notrunc status=none
"$script_dir/bin/md5-fix" "$firmware"
rm -rf tmp

echo "Successfully repacked firmware to $firmware"
