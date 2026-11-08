# Metra Student

Di iPhone dan iPad, buka **Dokumen** dan ketuk **Tambah Dokumen (+)**. Pilih foto dari Galeri atau pilih PDF dari Files. Batasnya 50 MB per berkas dan 10 halaman per PDF. Aplikasi langsung mengonversi dan menyimpan hasil di perangkat. Jika ada halaman yang gagal dibaca, aplikasi menampilkan nomor halamannya dan tidak menyimpan materi parsial.

Daftar menampilkan dokumen terbaru di atas. Cari berdasarkan judul atau ketuk **Pilih** untuk menghapus beberapa dokumen sekaligus. Satu dokumen juga bisa dihapus dari menu tekan lama, aksi VoiceOver pada baris, atau detail dokumen.

## Menyiapkan build

Jalankan dari root checkout Metra Student:

```sh
python3 Tools/prepare-document-pipeline.py
```

Script mengambil bobot model dan MathCAT dari checkout Teacher Pivot yang sudah disiapkan. Lokasi bawaan adalah `../../Teacher/teacher-pivot`; berikan lokasi Teacher Pivot sebagai argumen jika checkout ada di tempat lain. Jika bobot belum ada, jalankan `python3 Tools/setup-dependencies.py --models-only` dari root Teacher Pivot, lalu ulangi script Student.

Setelah itu, buka `MetraStudent.xcodeproj` di Xcode 27 dan jalankan scheme **MetraStudent** pada iPhone, iPad, atau simulator Apple Silicon. Untuk build simulator generik dari terminal, gunakan `ARCHS=arm64`. MathCAT dari Teacher Pivot memiliki slice iOS arm64 dan simulator arm64. Fitur impor ditargetkan untuk iOS dan iPadOS.

## Pipeline

Package lokal [MetraDocumentPipeline](Packages/MetraDocumentPipeline) membawa salinan pipeline dari working tree Teacher Pivot berbasis `dc63886`. Tahap ekstraksi, pengelompokan topik, ringkasan, dan bacaan matematika memakai implementasi Teacher. Adaptasi Student mengarahkan aset ke bundle package, menyimpan berkas kerja di folder sementara selama konversi, dan meneruskan materi ke SwiftData Student tanpa alur review guru. ClearSpeak dan SimpleSpeak tersedia di pembaca. Data SpeakEasy ikut tersimpan jika dihasilkan oleh pipeline.

ONNX Runtime dikunci ke 1.24.2. Sekitar 948 MB bobot ONNX dimasukkan ke build iOS dan tidak disimpan di Git. Lihat [sumber dan atribusi model](Packages/MetraDocumentPipeline/ENGINE-ASSETS.md). Tahap Foundation Models mengikuti ketersediaan Apple Intelligence di perangkat; pipeline memakai jalur fallback Teacher ketika model tidak tersedia.
