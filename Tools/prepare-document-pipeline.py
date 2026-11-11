#!/usr/bin/env python3
"""Install the model weights and MathCAT build from a prepared Teacher Pivot."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "Packages/MetraDocumentPipeline"
RESOURCES = PACKAGE / "Sources/MetraDocumentPipeline/Resources"
MATHCAT = Path("Libraries/MathCATNative/MathCAT.xcframework")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("teacher", type=Path, nargs="?", default=ROOT / "../../Teacher/teacher-pivot")
    teacher = parser.parse_args().teacher.resolve()
    models = json.loads((PACKAGE / "engine-assets.json").read_text())["files"]
    framework = teacher / MATHCAT
    slices = ("ios-arm64", "ios-arm64-simulator")
    required = [teacher / "Resources" / model["path"] for model in models] + [framework / "Info.plist"]
    for arch in slices:
        required.extend((framework / arch / "libmetra_mathcat.a",
                         framework / arch / "Headers/metra_mathcat.h"))
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        parser.exit(1, "Siapkan dependensi Teacher Pivot terlebih dahulu. Berkas belum ada:\n"
                    + "\n".join(missing) + "\n")

    for model in models:
        source = teacher / "Resources" / model["path"]
        digest = hashlib.sha256()
        with source.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        if source.stat().st_size != model["bytes"] or digest.hexdigest() != model["sha256"]:
            parser.exit(1, f"Bobot model tidak sesuai dengan versi pipeline: {source}\n")

    for model in models:
        name = model["path"]
        shutil.copyfile(teacher / "Resources" / name, RESOURCES / name)
    destination = PACKAGE / "Binaries/MathCAT.xcframework"
    shutil.copytree(framework, destination, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".DS_Store"))
    for arch in slices:
        (destination / arch / "Headers/module.modulemap").write_text(
            'module MetraMathCAT {\n    header "metra_mathcat.h"\n    export *\n}\n'
        )
    print("Model ONNX dan MathCAT siap untuk Metra Student.")


if __name__ == "__main__":
    main()
