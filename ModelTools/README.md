# Alat model — khusus maintainer

Folder ini tidak menjadi bagian target aplikasi. Developer cukup memasang Git LFS sekali, pull, lalu build di Xcode. CI tidak menjalankan Python atau mengunduh release Teacher.

Python hanya diperlukan untuk ekspor ulang atau perbandingan model. Gunakan macOS Apple Silicon dan Python 3.11:

```sh
python3.11 -m venv ModelTools/.venv
ModelTools/.venv/bin/pip install -r ModelTools/requirements.txt
ModelTools/.venv/bin/python ModelTools/export-models.py \
  --source /path/to/original/Resources --output ModelTools/work/converted
ModelTools/.venv/bin/python ModelTools/verify-parity.py \
  --source /path/to/original/Resources --models ModelTools/work/converted \
  --report ModelTools/work/parity.json
```

`--source` harus berisi enam ONNX asli sesuai hash `source-models.json`. Repo Teacher tidak diperlukan jika file asal disimpan di lokasi lain. Frontend `onnx_to_mil.py` hanya mendukung graph yang dipin ini; bukan konverter ONNX umum. Ia mempertahankan bentuk dinamis OCR/cache dan menghilangkan sumbu singleton pada view yang melebihi batas rank Core ML.

Ekspor berupa ML Programs FP32 iOS 18+, masih di bawah target iOS 27 aplikasi. Decoder digabung dengan utilitas resmi coremltools dan berbagi bobot tanpa kuantisasi. Python dan ONNX Runtime dalam requirements hanya dipakai di Mac maintainer.

Setelah hasil diverifikasi, pasang lima `.mlpackage` di Resources dan perbarui `engine-assets.json`, `Tools/bundled-assets.sha256`, dan `Tools/bundled-assets.xcfilelist`. Commit `.gitattributes`, model, MathCAT, dan manifest bersama-sama. Push branch dengan LFS agar rekan memperoleh objek besar otomatis. Tidak perlu mengubah riwayat development.

Fixture satu halaman dan tiga formula berasal dari preprocessing pilot Metra (layout dan formula build 5). Formula berupa input 192×672 yang sudah dipad. Hash fixture dicatat pada laporan. Parity memastikan konversi mempertahankan baseline, bukan membuktikan baseline selalu benar.
