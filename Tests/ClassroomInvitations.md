# Penerimaan undangan kelas iCloud

Jalankan `zsh Tests/run-classroom-invitation-checks.sh` untuk 50 pemeriksaan offline: validasi link dan root CloudKit, akun pemilik, kecocokan pemilik kelas, deduplikasi callback, antrean yang bertahan setelah restart/onboarding, kelas tujuan, retry, nama profil, dan pencegahan penggabungan ganda.

Student menjadi penerima share untuk container bersama `iCloud.id.valen.TeacherPeerPOC`, dengan `CKSharingSupported = true` dan content type `id.birumerah.metra.student.classroom-invitation`. Teacher membuat link `CKShare` dan tidak mengiklankan penerimaan share. Link asli tetap berbentuk `https://www.icloud.com/share/...`.

Cold launch ditangani melalui metadata dalam scene connection options; warm launch melalui callback scene delegate. Metadata dan URL masuk ke `ClassroomInvitationInbox`, disimpan sebelum onboarding selesai, dan diteruskan ke halaman Undangan kelas. Pratinjau tidak menambah anggota; siswa menekan Gabung kelas untuk menerima share dan mendaftarkan nama profilnya. Setelah berhasil, beranda memuat kelas dan materi.

Penerima memverifikasi container, tipe share, versi schema, root record, pemilik, identitas kelas, dan URL aktif. Kegagalan pendaftaran anggota ditampilkan untuk dicoba ulang, bukan diabaikan. Penanganan share menggunakan API async dan satu callback penyelesaian untuk pengambilan metadata.

`CKShareTypeKey` merupakan metadata presentasi opsional. Jika tersedia, nilainya harus cocok; jika tidak tersedia, pemeriksaan root/schema, pemilik kelas, dan URL aktif tetap wajib. Alias `CKCurrentUserDefaultName` dinormalisasi di kedua sisi perbandingan pemilik. Creator record server tetap diutamakan dibanding field pemilik yang bisa diubah.

Jika peran CloudKit adalah pemilik, atau identitas pemilik sama dengan pengguna saat ini, Student menjelaskan bahwa akun iCloud siswa harus berbeda dari guru. Membuka undangan sendiri tidak menambah nama siswa ke kelas. Ini berbeda dari kesalahan container atau struktur undangan. Detail validasi dapat disalin dari halaman undangan; isinya hanya kategori kegagalan dan konfigurasi aplikasi, tanpa URL undangan atau ID akun/record.

## Uji iCloud asli

1. Gunakan dua akun iCloud berbeda dan profil provisioning yang mengizinkan container yang sama. Pastikan kedua app memakai environment CloudKit yang sama.
2. Di Development, Teacher membuat private record type `ClassroomInvitation` dalam zone `MetraClassroomInvitations`. Field: `schemaVersion` (Int64), `channelCode`, `channelRecordName`, `name`, dan `createdBy` (String). Public `ClassroomChannel.shareURL` berisi link aktif. Deploy schema tersebut ke Production sebelum TestFlight.
3. Buat link dari Teacher > pilih kelas > Undang siswa, lalu kirim melalui share sheet.
4. Pada perangkat siswa dengan kedua app terpasang, tekan link dan pastikan Student dibuka. Ulangi saat Student tertutup, berjalan, dan belum menyelesaikan onboarding.
5. Cocokkan nama kelas/guru, isi nama profil, dan pilih Gabung kelas. Periksa kelas/materi di Student serta anggota di Teacher.
6. Uji callback ganda, membuka link yang sama kembali, kegagalan jaringan, kode enam karakter, dan link kelas yang sudah dihapus.
7. Buka tautan dengan akun iCloud guru sendiri: harus muncul petunjuk memakai akun siswa yang berbeda, tanpa mendaftarkan anggota. Ubah nama profil saja tidak mengubah akun iCloud.

Build simulator dan tes stub belum membuktikan pembuatan link server, penerimaan share antar akun, atau pemilihan aplikasi oleh iOS. Ketiganya membutuhkan uji link asli di perangkat.

Smoke test dengan signing simulator Xcode sudah memverifikasi startup dan pembukaan halaman Undangan kelas dari antrean lokal. Tanpa akun iCloud, halaman menampilkan petunjuk masuk dan tombol Coba lagi. Link contoh masuk melalui launch arguments; ini bukan bukti routing link asli oleh iOS. Hasil dan error undangan memakai pengumuman VoiceOver berbahasa Indonesia.

Referensi Apple: [CloudKit Sharing](https://developer.apple.com/documentation/cloudkit/sharing-cloudkit-data-with-other-icloud-users), [CKSharingSupported](https://developer.apple.com/documentation/bundleresources/information-property-list/cksharingsupported).

## Container mengikuti Guru

Bundle ID Student adalah `id.valen.MetraStudent`, terpisah dari Teacher `id.valen.TeacherPeerPOC`. Teacher menurunkan nama container dari `PRODUCT_BUNDLE_IDENTIFIER`. Student menurunkannya dari build setting `METRA_TEACHER_BUNDLE_IDENTIFIER` agar tetap memakai container Teacher, bukan container milik bundle Student sendiri.

`METRA_CLASSROOM_CONTAINER_IDENTIFIER` digunakan bersama oleh entitlements dan metadata Info.plist. Jika bundle ID Teacher berubah, perbarui `METRA_TEACHER_BUNDLE_IDENTIFIER` pada kedua konfigurasi Student. Provisioning profile dan container pada Apple Developer tetap harus diizinkan untuk kedua App ID.

Bundle ID aplikasi dan identifier container adalah dua konfigurasi yang berbeda:

| Konfigurasi | Teacher | Student |
| --- | --- | --- |
| Bundle ID aplikasi | `id.valen.TeacherPeerPOC` | `id.valen.MetraStudent` |
| Container iCloud | `iCloud.id.valen.TeacherPeerPOC` | `iCloud.id.valen.TeacherPeerPOC` |

Jangan menyamakan bundle ID Student dengan Teacher atau dengan nama container. `App` pada detail error melaporkan bundle ID aplikasi yang sedang berjalan; nilainya tidak perlu sama dengan `Container`. Error `ownerAccount` merujuk ke identitas akun iCloud pengguna, bukan bundle ID atau akun Apple Developer untuk signing.

Build Debug untuk `generic/platform=iOS` berhasil dengan automatic signing dan provisioning updates. Signature aplikasi dan embedded provisioning profile sudah diverifikasi memakai App ID `U3CC574JGM.id.valen.MetraStudent` serta mengizinkan container `iCloud.id.valen.TeacherPeerPOC`. Build simulator juga berhasil. Ini memastikan konfigurasi signing build; pemasangan dan penerimaan undangan dengan akun iCloud siswa berbeda tetap perlu diuji di perangkat.
