# Verifikasi migrasi Core ML — 11 November 2026

Branch `feature/update-ml-model`, berbasis development `37eb78c`.

- **110 perbandingan lulus** pada model yang dibundel: PP-DocLayout, OCR lebar 320/321/768/3200, MFD tinggi 32/768/1024/1536, tiga rumus sampai EOS, dan semua output cache pada panjang 127/511. Laporan: [coreml-parity.json](coreml-parity.json).
- **Empat XCTest lulus**: validasi shape/token, tensor dengan stride/padding, identitas model, encoder dan kedua fungsi decoder dengan cache.
- **Pemeriksaan regresi asisten lulus**. Referensi SectionViewModel diperbarui mengikuti lokasi source development.
- **Build Debug simulator arm64 lulus**, tanpa ONNX Runtime.
- **Ekspor ulang dari tooling yang disertakan lulus**; kelima file bobot hasil ekspor identik byte demi byte dengan aset yang dibundel.
- **Clone Git LFS baru lulus**: snapshot source dibuat sebagai repo lokal sementara, objek LFS dipush ke bare remote lokal, clone baru mengunduh otomatis, `git lfs fsck` dan checksum lulus. Tes ini tidak commit/push repository kerja asli.
- **Archive Release iOS dari clone baru lulus**, tanpa Python atau aset Teacher. Archive memakai `CODE_SIGNING_ALLOWED=NO` untuk verifikasi lokal; belum diunggah ke TestFlight/App Store.
- **Audit archive lulus**: enam `.mlmodelc` tersedia; tanpa `.py`, `.pyc`, `.onnx`, framework Python, atau ONNX Runtime. CI menjalankan audit yang sama sebelum upload.

## Menjalankan ulang pemeriksaan native

```sh
/bin/sh Tools/check-bundled-assets.sh
./Tests/run-assistant-checks.sh
cd Packages/MetraDocumentPipeline
xcodebuild -scheme MetraDocumentPipeline -destination 'platform=macOS' test
```

Audit hasil archive: `/bin/sh Tools/check-app-bundle.sh /path/to/MetraStudent.app`.

## Batas verifikasi

Parity dilakukan di Core ML CPU FP32 pada Mac Apple Silicon. Pengujian ini tidak mengukur akurasi baseline atau latensi/memori di iPhone/iPad. GPU/Neural Engine dan FP16 belum diaktifkan. Uji impor dokumen pada perangkat fisik dan signing distribusi masih diperlukan sebelum rilis. Warning isolasi actor pada ChannelViewModel baris 57 sudah ada di development.

[App Review Guideline 2.5.2](https://developer.apple.com/app-store/review/guidelines/#software-requirements) mengatur bundle mandiri dan kode yang diunduh/dijalankan untuk mengubah fungsi app. Script ekspor Python di luar target bukan runtime Python di app. Archive migrasi ini memakai Swift/native dan Core ML; ModelTools tidak dibundel. Konversi format tidak menyelesaikan perbedaan deklarasi lisensi Pix2Text yang dicatat di ENGINE-ASSETS.md.
