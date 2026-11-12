#!/bin/sh
# Read-only build check. No downloads, Python, exports, or dependency on Teacher.
set -eu
task_root="${SRCROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
cd "$task_root"
task_manifest="Tools/bundled-assets.sha256"
while IFS= read -r task_line; do
    task_path="${task_line#*  }"
    if [ ! -f "$task_path" ]; then
        echo "error: Aset Student belum tersedia: $task_path. Pasang Git LFS sekali (git lfs install), lalu jalankan git lfs pull." >&2
        exit 1
    fi
    if LC_ALL=C head -c 42 "$task_path" | LC_ALL=C grep -q '^version https://git-lfs.github.com/spec/v1'; then
        echo "error: $task_path masih berupa pointer Git LFS. Jalankan git lfs pull lalu build ulang." >&2
        exit 1
    fi
done < "$task_manifest"
if ! shasum -a 256 --check --status "$task_manifest"; then
    echo "error: Aset Student tidak cocok dengan manifest. Pulihkan aset versi branch ini dengan git lfs pull." >&2
    exit 1
fi
echo "Aset Core ML dan MathCAT terverifikasi."
