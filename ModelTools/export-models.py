#!/usr/bin/env python3
"""Export the six hash-pinned ONNX graphs; developer builds use committed Core ML assets."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import coremltools as ct
from onnx_to_mil import convert

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='Directory containing the original six ONNX files')
    parser.add_argument('--output', type=Path, required=True, help='Output directory; verify before installing in Resources')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'source-models.json').read_text())
    sources = {record['path']: record for record in manifest['files']}
    for name, record in sources.items():
        path = args.source / name
        if path.stat().st_size != record['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != record['sha256']:
            parser.error(f'Source is not the pinned model: {path}')
    args.output.mkdir(parents=True, exist_ok=True)
    cache_shapes = {'input_ids': [1, 1], 'encoder_hidden_states': [1, 126, 512]}
    for layer in range(8):
        cache_shapes[f'past_key_{layer}'] = [1, 16, [1, 511, 1], 16]
        cache_shapes[f'past_value_{layer}'] = [1, 16, [1, 511, 1], 32]
    jobs = [
        ('PP-DocLayout-L.onnx', 'PP-DocLayout-L', {'image': [1, 3, 640, 640], 'im_shape': [1, 2], 'scale_factor': [1, 2]}),
        ('PaddleOCR-PP-OCRv5-mobile-rec.onnx', 'PaddleOCR-PP-OCRv5-mobile-rec', {'x': [1, 3, 48, [320, 3200, 320]]}),
        ('Pix2Text-MFD.onnx', 'Pix2Text-MFD', {'images': [1, 3, [32, 1536, 768], 768]}),
        ('UniMERNet/encoder_model.onnx', 'UniMERNet-Encoder', {'pixel_values': [1, 1, 192, 672]}),
        ('UniMERNet/decoder_model.onnx', 'first', {'input_ids': [1, 1], 'encoder_hidden_states': [1, 126, 512]}),
        ('UniMERNet/decoder_with_past_model.onnx', 'cached', cache_shapes),
    ]
    with tempfile.TemporaryDirectory(prefix='metra-coreml-export-') as temp:
        work = Path(temp)
        for source, name, shapes in jobs:
            convert(args.source / source, work / f'{name}.mlpackage', shapes)
        descriptor = ct.utils.MultiFunctionDescriptor()
        descriptor.add_function(str(work / 'first.mlpackage'), 'main', 'first_token')
        descriptor.add_function(str(work / 'cached.mlpackage'), 'main', 'cached_token')
        descriptor.default_function_name = 'first_token'
        ct.utils.save_multifunction(descriptor, str(work / 'shared.mlpackage'))
        decoder = ct.models.MLModel(str(work / 'shared.mlpackage'), skip_model_load=True)
        for function, source in [('first_token', 'UniMERNet/decoder_model.onnx'), ('cached_token', 'UniMERNet/decoder_with_past_model.onnx')]:
            decoder.user_defined_metadata[f'metra.source.{function}.sha256'] = sources[source]['sha256']
        decoder.user_defined_metadata['metra.precision'] = 'FP32'
        decoder.save(str(work / 'UniMERNet-Decoder.mlpackage'))
        for name in [job[1] for job in jobs[:4]] + ['UniMERNet-Decoder']:
            destination = args.output / f'{name}.mlpackage'
            if destination.exists(): shutil.rmtree(destination)
            shutil.copytree(work / f'{name}.mlpackage', destination)
            print(f'Exported {destination}', flush=True)


if __name__ == '__main__':
    main()
