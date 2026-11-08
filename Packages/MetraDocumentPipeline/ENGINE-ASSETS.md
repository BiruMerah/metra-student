# Aset mesin ekstraksi Teacher

Ukuran dan SHA-256 yang digunakan aplikasi tercantum di `engine-assets.json`. Setup tidak mengganti konfigurasi/rules/tokenizer dan tidak mengekspor ulang model. File ONNX tidak dimasukkan ke riwayat Git.

| File lokal | Sumber bobot | Distribusi setup |
| --- | --- | --- |
| `PP-DocLayout-L.onnx` | [PaddlePaddle/PP-DocLayout-L](https://huggingface.co/PaddlePaddle/PP-DocLayout-L/tree/ca760c3336d922ee63cdbff85003181222e3911c), Apache-2.0; ekspor Paddle2ONNX lokal FP32, opset 17 | GitHub Release `teacher-engine-assets-v1` |
| `PaddleOCR-PP-OCRv5-mobile-rec.onnx` | [PaddlePaddle/PP-OCRv5_mobile_rec_onnx](https://huggingface.co/PaddlePaddle/PP-OCRv5_mobile_rec_onnx/tree/ed152b8b495f84de93cda5709d768548a9127622), Apache-2.0 | Langsung dari upstream, `inference.onnx` |
| `Pix2Text-MFD.onnx` | [breezedeus/pix2text-mfd](https://huggingface.co/breezedeus/pix2text-mfd/tree/fc3797af79391c32ed0d56f8b5f437b5a49271be) | Langsung dari upstream, `mfd-v20240618.onnx` |
| `UniMERNet/*.onnx` (3 file) | [wanderkid/unimernet_tiny](https://huggingface.co/wanderkid/unimernet_tiny/tree/3f09ac4b1cd583be47ea20a7d7daef839473028a), Apache-2.0; ekspor lokal FP32, opset 18 | GitHub Release `teacher-engine-assets-v1`, nama aset diawali `UniMERNet-` |

PP-DocLayout diekspor dengan PaddlePaddle 3.3.0, Paddle2ONNX 2.1.0, ONNX 1.17.0 dan ONNX Optimizer 0.3.13. UniMERNet memakai checkpoint asli dan kode [UniMERNet](https://github.com/opendatalab/UniMERNet), PyTorch 2.5.1, Transformers 4.46.3, ONNX 1.17.0; encoder, decoder awal dan decoder cache disimpan terpisah. Metadata lengkap dan hash checkpoint tetap di `Resources/PP-DocLayout-L.config.json` dan `Resources/UniMERNet/unimernet-manifest.json`. Bobot tidak dikuantisasi.

Atribusi UniMERNet: Bin Wang, Zhuangcheng Gu, Chao Xu, Bo Zhang, Botian Shi dan Conghui He, *UniMERNet: A Universal Network for Real-World Mathematical Expression Recognition* (2024), [arXiv:2404.15254](https://arxiv.org/abs/2404.15254). README model asli disertakan di `Resources/UniMERNet/README.md`. Lisensi Apache-2.0: <https://www.apache.org/licenses/LICENSE-2.0>.

Pix2Text memiliki dua deklarasi lisensi upstream: model card menyebut MIT, sedangkan metadata ONNX menyebut AGPL-3.0 dari Ultralytics. Keduanya tetap dicatat di `Resources/Pix2Text-MFD.config.json`. Setup mengunduh file langsung dari upstream dan tidak mengunggahnya ulang ke release Teacher.
