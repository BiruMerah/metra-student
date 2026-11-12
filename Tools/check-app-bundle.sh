#!/bin/sh
set -eu
task_app="${1:?Usage: check-app-bundle.sh /path/to/MetraStudent.app}"
test -d "$task_app"
task_forbidden="$(find "$task_app" \( -iname '*.py' -o -iname '*.pyc' -o -iname '*.onnx' -o -iname '*python*.framework' -o -iname '*onnxruntime*' \) -print -quit)"
if [ -n "$task_forbidden" ]; then
    echo "error: Aset/runtime yang tidak diperlukan ikut ke app: $task_forbidden" >&2
    exit 1
fi
for task_name in PP-DocLayout-L Pix2Text-MFD PaddleOCR-PP-OCRv5-mobile-rec UniMERNet-Encoder UniMERNet-Decoder MathVisualRepresentationClassifier; do
    task_model="$(find "$task_app" -type d -name "$task_name.mlmodelc" -print -quit)"
    if [ -z "$task_model" ]; then
        echo "error: Model Core ML tidak ada di app: $task_name" >&2
        exit 1
    fi
done
echo "Enam aset model Core ML tersedia; bundle bebas Python dan ONNX Runtime."
