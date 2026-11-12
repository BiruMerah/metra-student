# Aset ekstraksi Student

Model aplikasi tersedia di repo melalui Git LFS. `engine-assets.json` dan `../../Tools/bundled-assets.sha256` mencatat ukuran dan SHA-256 file yang digunakan. Xcode memverifikasi aset dan mengompilasi `.mlpackage` / `.mlmodel` menjadi `.mlmodelc`. Tidak ada download model, Python, atau ONNX Runtime saat app berjalan.

| Aset | Input / fungsi |
| --- | --- |
| PP-DocLayout-L.mlpackage | RGB NCHW 640×640; bentuk/skala halaman |
| PaddleOCR-PP-OCRv5-mobile-rec.mlpackage | BGR NCHW, tinggi 48, lebar 320–3200 |
| Pix2Text-MFD.mlpackage | RGB NCHW, lebar 768, tinggi kelipatan 32 hingga 1536 |
| UniMERNet-Encoder.mlpackage | Grayscale NCHW 192×672 |
| UniMERNet-Decoder.mlpackage | `first_token` dan `cached_token`; cache 1–511 token; bobot bersama |
| MathVisualRepresentationClassifier.mlmodel | Vision scaleFit 360×360; sudah Core ML sebelumnya |

Kelima paket hasil konversi total **631.801.394 byte**, dari **948.462.443 byte** ONNX. Penghematan berasal dari berbagi bobot decoder, bukan kuantisasi. FP32, preprocessing, tokenizer, dictionary CTC, greedy decoding, EOS, batas token, dan postprocessing dipertahankan. Token Core ML menggunakan Int32; vocabulary 50.000 token berada dalam rentangnya. Core ML mengatur threading sendiri.

`CoreMLInference` memilih CPU FP32. GPU/Neural Engine, FP16, dan kompresi lossy belum diaktifkan. Hash sumber ditanam pada metadata Core ML dan diverifikasi saat dimuat. Integritas paket diperiksa sebelum build; hasil `.mlmodelc` dilindungi signing app.

MathCAT adalah library native Rust/C, bukan model ML. XCFramework iOS dan simulator serta header/module map ikut repo. Rules MathCAT, MathJax lokal, konfigurasi, dan tokenizer ikut bundle. Vision dan Foundation Models tetap dikelola iOS.

## Provenance sebelum konversi

Identitas enam graph ONNX asal tersimpan di `../../ModelTools/source-models.json`. File ONNX tidak ikut app. Metadata konfigurasi mempertahankan informasi ekspor lama. Bukti perangkat di `Resources/model-manifest.json` adalah baseline sebelum migrasi, bukan pengujian Core ML di iPhone. Tabel berikut mencatat sumber/distribusi baseline lama, bukan alur build Student sekarang.

| File lokal | Sumber bobot | Distribusi setup |
| --- | --- | --- |
| `PP-DocLayout-L.onnx` | [PaddlePaddle/PP-DocLayout-L](https://huggingface.co/PaddlePaddle/PP-DocLayout-L/tree/ca760c3336d922ee63cdbff85003181222e3911c), Apache-2.0; ekspor Paddle2ONNX lokal FP32, opset 17 | GitHub Release `teacher-engine-assets-v1` |
| `PaddleOCR-PP-OCRv5-mobile-rec.onnx` | [PaddlePaddle/PP-OCRv5_mobile_rec_onnx](https://huggingface.co/PaddlePaddle/PP-OCRv5_mobile_rec_onnx/tree/ed152b8b495f84de93cda5709d768548a9127622), Apache-2.0 | Langsung dari upstream, `inference.onnx` |
| `Pix2Text-MFD.onnx` | [breezedeus/pix2text-mfd](https://huggingface.co/breezedeus/pix2text-mfd/tree/fc3797af79391c32ed0d56f8b5f437b5a49271be) | Langsung dari upstream, `mfd-v20240618.onnx` |
| `UniMERNet/*.onnx` (3 file) | [wanderkid/unimernet_tiny](https://huggingface.co/wanderkid/unimernet_tiny/tree/3f09ac4b1cd583be47ea20a7d7daef839473028a), Apache-2.0; ekspor lokal FP32, opset 18 | GitHub Release `teacher-engine-assets-v1`, nama aset diawali `UniMERNet-` |

PP-DocLayout baseline diekspor dengan PaddlePaddle 3.3.0, Paddle2ONNX 2.1.0 dan ONNX 1.17.0. UniMERNet memakai checkpoint asli dengan hash `6f760862…7371`; ONNX FP32 opset 18. Core ML diekspor dengan coremltools 9.0; tidak ada model pengganti atau bobot acak.

Atribusi UniMERNet: Bin Wang, Zhuangcheng Gu, Chao Xu, Bo Zhang, Botian Shi dan Conghui He, *UniMERNet: A Universal Network for Real-World Mathematical Expression Recognition* (2024), [arXiv:2404.15254](https://arxiv.org/abs/2404.15254). README asli disertakan di `Resources/UniMERNet/README.md`. Lisensi MathCAT: `LICENSE-MathCAT`.

Konversi format tidak mengubah lisensi bobot. Pix2Text memiliki dua deklarasi upstream: model card MIT, metadata ONNX AGPL-3.0/Ultralytics. Keduanya tetap dicatat di konfigurasi sumber; perbedaan ini perlu diselesaikan sebelum distribusi komersial.
