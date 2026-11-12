#!/usr/bin/env python3
"""Maintainer-only CPU parity checks against the six original ONNX exports."""
import argparse
import gc
import hashlib
import json
from pathlib import Path
import importlib.metadata
import numpy as np
import onnxruntime as ort
import coremltools as ct
from PIL import Image

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--models', type=Path, default=ROOT.parent / 'Packages/MetraDocumentPipeline/Sources/MetraDocumentPipeline/Resources')
    parser.add_argument('--fixtures', type=Path, default=ROOT / 'Fixtures')
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    cases, generations = [], []
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.log_severity_level = 3
    sources = json.loads((ROOT / 'source-models.json').read_text())['files']
    for record in sources:
        path = args.source / record['path']
        assert path.stat().st_size == record['bytes']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], str(path)

    def original(path):
        return ort.InferenceSession(str(args.source / path), sess_options=options, providers=['CPUExecutionProvider'])

    def native(name, function=None):
        return ct.models.MLModel(str(args.models / f'{name}.mlpackage'), function_name=function,
                                 compute_units=ct.ComputeUnit.CPU_ONLY)

    def compare(name, a, b, tolerance):
        assert a.shape == b.shape, (name, a.shape, b.shape)
        assert np.isfinite(b).all(), name
        error = a.astype(np.float64) - b.astype(np.float64)
        row = {'name': name, 'shape': list(a.shape),
               'maximum_absolute_error': float(np.max(np.abs(error))),
               'rmse': float(np.sqrt(np.mean(error ** 2)))}
        cases.append(row)
        assert row['maximum_absolute_error'] < tolerance, row
        print(json.dumps(row), flush=True)
        return row

    def page_pixels(size):
        image = Image.open(args.fixtures / 'page.png').convert('RGB').resize(size, Image.Resampling.BILINEAR)
        return np.asarray(image, np.float32).transpose(2, 0, 1)[None] / 255

    passed = False
    try:
        s, m = original('PaddleOCR-PP-OCRv5-mobile-rec.onnx'), native('PaddleOCR-PP-OCRv5-mobile-rec')
        for width in [320, 321, 768, 3200]:
            x = np.random.default_rng(123).uniform(-1, 1, (1, 3, 48, width)).astype(np.float32)
            a, b = s.run(None, {'x': x})[0], m.predict({'x': x})['fetch_name_0']
            row = compare(f'paddle-width-{width}', a, b, 0.001)
            row['argmax_equal'] = bool(np.array_equal(a.argmax(-1), b.argmax(-1)))
            assert row['argmax_equal']
        del s, m
        gc.collect()

        s, m = original('Pix2Text-MFD.onnx'), native('Pix2Text-MFD')
        for height in [32, 768, 1024, 1536]:
            x = page_pixels((768, height))
            a, b = s.run(None, {'images': x})[0], m.predict({'images': x})['output0']
            row = compare(f'mfd-height-{height}', a, b, 0.1)
            row['score_maximum_absolute_error'] = float(np.max(np.abs(a[:, 4:] - b[:, 4:])))
            assert row['score_maximum_absolute_error'] < 0.001
        del s, m
        gc.collect()

        s, m = original('PP-DocLayout-L.onnx'), native('PP-DocLayout-L')
        for scale in [1., .625]:
            x = {'image': page_pixels((640, 640)), 'im_shape': np.array([[640, 640]], np.float32),
                 'scale_factor': np.array([[scale, scale]], np.float32)}
            a, b = s.run(None, x), m.predict(x)
            for i, key in enumerate(['fetch_name_0', 'fetch_name_1']):
                compare(f'layout-{scale}-{key}', a[i], b[key], 0.2)
            assert np.array_equal(a[0][:, 0], b['fetch_name_0'][:, 0])
            assert np.max(np.abs(a[0][:, 1] - b['fetch_name_0'][:, 1])) < .001
        del s, m
        gc.collect()

        encoder, native_encoder = original('UniMERNet/encoder_model.onnx'), native('UniMERNet-Encoder')
        decoder, cached = original('UniMERNet/decoder_model.onnx'), original('UniMERNet/decoder_with_past_model.onnx')
        first_ml, cached_ml = native('UniMERNet-Decoder', 'first_token'), native('UniMERNet-Decoder', 'cached_token')
        for fixture in sorted(args.fixtures.glob('formula-*.png')):
            x = ((np.asarray(Image.open(fixture).convert('L'), np.float32) / 255 - .7931) / .1738)[None, None]
            a, b = encoder.run(None, {'pixel_values': x})[0], native_encoder.predict({'pixel_values': x})['encoder_hidden_states']
            compare(f'{fixture.stem}-encoder', a, b, .002)
            old_cache, new_cache, tokens, token = {}, {}, [], 0
            for step in range(512):
                active, model = (decoder, first_ml) if step == 0 else (cached, cached_ml)
                old_inputs = {'input_ids': np.array([[token]], np.int64), 'encoder_hidden_states': a, **old_cache}
                new_inputs = {'input_ids': np.array([[token]], np.int32), 'encoder_hidden_states': b, **new_cache}
                outputs = dict(zip([v.name for v in active.get_outputs()], active.run(None, old_inputs)))
                prediction = model.predict(new_inputs)
                row = compare(f'{fixture.stem}-logits-{step}', outputs['logits'], prediction['logits'], .03)
                token = int(outputs['logits'].argmax(-1)[0, 0])
                row['argmax_equal'] = token == int(prediction['logits'].argmax(-1)[0, 0])
                assert row['argmax_equal']
                tokens.append(token)
                if token == 2: break
                old_cache = {key.replace('present_', 'past_'): value for key, value in outputs.items() if key != 'logits'}
                new_cache = {key.replace('present_', 'past_'): value for key, value in prediction.items() if key != 'logits'}
            assert tokens[-1] == 2, f'{fixture.name}: baseline did not reach EOS'
            generations.append({'fixture': fixture.name, 'tokens_equal': True, 'eos_reached': True, 'token_ids': tokens})

        for length in [127, 511]:
            rng = np.random.default_rng(1)
            inputs = {'input_ids': np.array([[5]], np.int64), 'encoder_hidden_states': a}
            for layer in range(8):
                inputs[f'past_key_{layer}'] = rng.normal(0, .1, (1, 16, length, 16)).astype(np.float32)
                inputs[f'past_value_{layer}'] = rng.normal(0, .1, (1, 16, length, 32)).astype(np.float32)
            outputs = dict(zip([v.name for v in cached.get_outputs()], cached.run(None, inputs)))
            inputs['input_ids'] = inputs['input_ids'].astype(np.int32)
            prediction = cached_ml.predict(inputs)
            for key in outputs: compare(f'unimer-cache-{length}-{key}', outputs[key], prediction[key], .03)
        passed = True
    finally:
        report = {'passed': passed, 'backend': 'Core ML CPU_ONLY FP32 vs ONNX Runtime CPUExecutionProvider',
                  'scope': 'Numerical and token parity, not a claim of model accuracy or iPhone latency.',
                  'tools': {name: importlib.metadata.version(name) for name in ['coremltools', 'onnxruntime', 'numpy', 'Pillow']},
                  'fixture_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(args.fixtures.glob('*.png'))},
                  'generations': generations, 'cases': cases}
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(f'{len(cases)} comparisons passed.', flush=True)


if __name__ == '__main__':
    main()
