# Metra Student

Metra Student adalah aplikasi iPhone dan iPad untuk mengubah foto atau PDF materi matematika menjadi materi yang dapat dibaca dan didengarkan. Konversi dokumen berjalan di perangkat menggunakan Core ML dan framework Apple.

## Mulai mengembangkan

Siapkan Xcode 27 dan Git LFS. Model serta library native sudah disertakan dalam repository; build biasa tidak membutuhkan Python, checkout Teacher, ekspor model, atau download aset dari GitHub Release.

### 1. Aktifkan Git LFS sekali

Jika menggunakan Homebrew:

```sh
brew install git-lfs
git lfs install
```

Pilihan instalasi lain tersedia di [dokumentasi Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage).

### 2. Clone atau pull, lalu buka Xcode

Setelah Git LFS aktif, clone repository atau pull branch yang sedang dikerjakan. Git LFS mengambil file model dan MathCAT secara otomatis.

Dari root checkout:

```sh
open MetraStudent.xcodeproj
```

Pilih scheme **MetraStudent**, pilih iPhone/iPad atau simulator Apple Silicon, lalu **Run**. Untuk perangkat fisik, sesuaikan signing dan izin CloudKit dengan konfigurasi tim.

Jika checkout sudah ada sebelum Git LFS dipasang, atau pengunduhan otomatis sebelumnya dilewati, jalankan sekali:

```sh
git lfs pull
```

Gunakan clone Git untuk mengikuti alur ini. Kelengkapan aset dalam ZIP dari GitHub bergantung pada pengaturan archive repository.

### Build simulator dari terminal

```sh
xcodebuild -project MetraStudent.xcodeproj -scheme MetraStudent \
  -destination 'generic/platform=iOS Simulator' ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
```

## Model, MathCAT, dan Git LFS

Git LFS digunakan untuk **file biner dalam lima paket Core ML hasil konversi dan library MathCAT**. Konfigurasinya ada di [`.gitattributes`](.gitattributes). Classifier visual yang berukuran kecil tetap disimpan di Git biasa.

| File biner utama | Fungsi | Ukuran |
| --- | --- | ---: |
| PP-DocLayout | Deteksi layout halaman | 137,2 MB |
| PaddleOCR | Pengenalan karakter dan simbol tambahan | 16,4 MB |
| Pix2Text-MFD | Deteksi area rumus | 44,5 MB |
| UniMERNet Encoder | Mengubah gambar rumus menjadi representasi model | 104,4 MB |
| UniMERNet Decoder | Menghasilkan token LaTeX | 325,7 MB |
| MathCAT, slice iOS | Library native untuk bacaan matematika | 43,5 MB |
| MathCAT, slice simulator | Library native untuk pengembangan di simulator | 43,5 MB |

Ukuran pada tabel memakai MB desimal dan menunjukkan file bobot/library utama, bukan ukuran app yang diunduh dari App Store.

GitHub [membatasi file Git biasa hingga 100 MiB](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github), sekitar 104,9 MB. Bobot PP-DocLayout dan UniMERNet Decoder melewati batas tersebut, sehingga membutuhkan LFS agar dapat disimpan dan diambil melalui repository. Model yang lebih kecil dan MathCAT juga memakai LFS agar pengelolaan file biner konsisten; ukuran MathCAT sendiri tidak mewajibkan LFS.

LFS menyimpan referensi kecil di riwayat Git dan mengambil file aslinya saat clone/pull. **LFS tidak mengecilkan model atau ukuran app.** Ketika app dibangun, model Core ML dan library native tetap disertakan. Pengguna aplikasi tidak membutuhkan Git LFS.

Kelima paket Core ML hasil konversi total **631,8 MB**, dibandingkan **948,5 MB** ONNX sebelumnya, sekitar 33% lebih kecil. Dua fungsi decoder UniMERNet berbagi bobot tanpa kuantisasi. Runtime ekstraksi memakai **Core ML CPU FP32** untuk mempertahankan hasil yang sudah diverifikasi; ONNX Runtime sudah dihapus dari dependensi aplikasi.

Vision, Speech, dan Foundation Models tetap dikelola iOS. Foundation Models mengikuti ketersediaan Apple Intelligence di perangkat, dengan jalur fallback yang sudah ada. Model sistem Apple tidak perlu diimpor atau dikonversi.

## Python dan aset aplikasi

Script Python pada [ModelTools](ModelTools/README.md) hanya digunakan maintainer di Mac untuk mengekspor ulang atau membandingkan model. Folder tersebut berada di luar target aplikasi dan tidak ikut ke archive. Developer yang menjalankan app tidak perlu menyiapkan environment Python.

Xcode mengompilasi model menjadi `.mlmodelc`. CI mengambil aset melalui Git LFS, memverifikasi checksum, lalu memeriksa bundle sebelum upload TestFlight. Audit bundle memastikan keenam aset Core ML tersedia dan tidak ada file Python, ONNX, atau ONNX Runtime.

## Menggunakan aplikasi

Buka **Dokumen**, ketuk **Tambah Dokumen (+)**, lalu pilih foto dari Galeri atau PDF dari Files. Batasnya **50 MB per berkas** dan **10 halaman per PDF**. Hasil konversi disimpan di perangkat. Jika ada halaman yang gagal dibaca, aplikasi menampilkan nomor halamannya dan tidak menyimpan materi parsial.

Dokumen terbaru tampil di atas. Gunakan pencarian untuk menemukan judul, atau ketuk **Pilih** untuk menghapus beberapa dokumen. Satu dokumen juga dapat dihapus dari menu tekan lama, aksi VoiceOver pada baris, atau detail dokumen. Pembaca mendukung ClearSpeak dan SimpleSpeak; data SpeakEasy ikut tersimpan jika dihasilkan pipeline.

## Pipeline

Package lokal [MetraDocumentPipeline](Packages/MetraDocumentPipeline) berasal dari pipeline Teacher Pivot berbasis `dc63886`. Package ini menangani ekstraksi, pengelompokan topik, ringkasan, dan bacaan matematika. Adaptasi Student menggunakan aset dari bundle package, menyimpan berkas kerja sementara selama konversi, dan meneruskan materi ke SwiftData tanpa alur review guru. Checkout Teacher tidak diperlukan untuk build Student.

## Pemeriksaan dan dokumentasi

Untuk memeriksa kelengkapan dan checksum aset dari root checkout:

```sh
/bin/sh Tools/check-bundled-assets.sh
```

Jika aset hilang atau masih berupa pointer LFS, jalankan `git lfs pull`, lalu ulangi pemeriksaan.

- [Hasil verifikasi migrasi Core ML](Verification/COREML-MIGRATION.md): perbandingan numerik, tes native, clone LFS, build, dan archive Release.
- [Sumber, atribusi, dan lisensi aset](Packages/MetraDocumentPipeline/ENGINE-ASSETS.md).
- [Alat ekspor dan verifikasi khusus maintainer](ModelTools/README.md).

Sebelum rilis, lakukan pengujian pada iPhone/iPad fisik dan klarifikasi perbedaan deklarasi lisensi Pix2Text yang tercatat pada dokumentasi aset. Hasil verifikasi lokal belum mengukur latensi dan memori pada perangkat fisik.
