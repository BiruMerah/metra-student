# Penerimaan undangan kelas iCloud

Jalankan `zsh Tests/run-classroom-invitation-checks.sh` untuk 50 pemeriksaan offline: validasi link dan root CloudKit, akun pemilik, kecocokan pemilik kelas, deduplikasi callback, antrean yang bertahan setelah restart/onboarding, kelas tujuan, retry, nama profil, dan pencegahan penggabungan ganda.

Student menjadi penerima share untuk container bersama `iCloud.id.valen.TeacherPeerPOC`, dengan `CKSharingSupported = true` dan content type `id.birumerah.metra.student.classroom-invitation`. Teacher membuat link `CKShare` dan tidak mengiklankan penerimaan share. Link asli tetap berbentuk `https://www.icloud.com/share/...`.

Cold launch ditangani melalui metadata dalam scene connection options; warm launch melalui callback scene delegate. Metadata dan URL masuk ke `ClassroomInvitationInbox`, disimpan sebelum onboarding selesai, dan diteruskan ke halaman Undangan kelas. Pratinjau tidak menambah anggota; siswa menekan Gabung kelas untuk menerima share dan menyimpan record `ClassroomMembership` miliknya sendiri. Setelah berhasil, beranda memuat kelas dan materi.

Penerima memverifikasi container, tipe share, versi schema, root record, pemilik, identitas kelas, dan URL aktif. Kegagalan pendaftaran anggota ditampilkan untuk dicoba ulang, bukan diabaikan. Penanganan share menggunakan API async dan satu callback penyelesaian untuk pengambilan metadata.

## Keanggotaan terpisah dan izin CloudKit

Student tidak lagi menulis field `ClassroomChannel.members` milik guru. Schema server Development yang diekspor pada 17 November 2026 mengonfirmasi kelas hanya memberi `WRITE` kepada `_creator`; mencoba mengubah record itu dari akun siswa menghasilkan `CKError.permissionFailure` (10).

Setiap akun menyimpan satu public record `ClassroomMembership` per kelas. ID record berasal dari SHA-256 pasangan ID record kelas dan ID pengguna, sehingga retry tidak membuat anggota ganda. Field: `channelRecordName`, `channelCode`, `memberUserRecordID`, `displayName`, `enrollmentID` (String), dan `joinedAt` (Timestamp). `channelRecordName` harus memiliki index QUERYABLE.

Security roles: `_icloud` mendapat CREATE, `_creator` mendapat WRITE, `_world` mendapat READ, sama dengan keterbacaan roster lama. Siswa dapat membuat/mengubah/menghapus keanggotaannya sendiri. Field identitas divalidasi terhadap `creatorUserRecordID` server dan ID record deterministik; klaim identitas dari field yang dapat diedit saja tidak dipercaya. `ClassroomChannel` tetap WRITE khusus `_creator`.

Teacher menggabungkan anggota lama dalam `members` dengan keanggotaan baru saat memuat kelas dan membuka daftar anggota. Kegagalan memuat roster ditampilkan agar daftar yang belum lengkap tidak dianggap kosong. Guru mengeluarkan siswa dengan menyimpan kunci enrollment dalam `ClassroomChannel.removedMemberships` (List<String>), tanpa mengubah record milik siswa. Refresh tidak menghidupkan enrollment yang sudah dikeluarkan; siswa yang secara eksplisit bergabung lagi memakai enrollment baru pada row yang sama. Keluar kelas menghapus row milik siswa sebelum kelas dihapus dari daftar lokal. Nama anggota lama yang hanya tersimpan pada array legacy tetap dikelola oleh guru.

Penyimpanan keanggotaan memakai maksimum tiga percobaan saat `serverRecordChanged` dan memeriksa ulang tautan aktif serta pengeluaran setelah save. Nama kelas, pemilik, dan field pengaturan tidak pernah ditulis oleh proses join. Student membaca ulang identitas akun melalui CloudKit dan tidak menyimpan ID akun lama dalam cache aplikasi.

Detail error membedakan `acceptShare` dari `saveMembership`. Error izin tidak dilaporkan sebagai masalah jaringan dan tidak diulang otomatis. Kegagalan commit tidak menghasilkan kelas lokal yang dianggap sudah berhasil bergabung.

Jalankan `zsh Tests/run-classroom-membership-checks.sh`: 31 pemeriksaan registrasi nyata melalui database stub dengan interface yang hanya dapat menulis keanggotaan, ownership, idempotensi, konflik, pencabutan tautan, pengeluaran/rejoin, roster legacy, dan pemisahan error izin. Build simulator Student dan Teacher berhasil; 50 pemeriksaan undangan Student dan 20 regresi pengelolaan kelas Teacher juga lolos. Uji penerimaan dan save pada dua akun iCloud asli tetap diperlukan.

Schema baru disiapkan dari ekspor server dan lolos validasi CloudKit. Setelah persetujuan eksplisit pengguna, impor Development berhasil pada 17 November 2026; CloudKit Console mengonfirmasi “The schema was successfully imported.” Production tidak diubah. Untuk TestFlight/App Store, deploy perubahan schema setelah uji Development selesai. Build ulang kedua app sebelum menguji join; build lama Student masih mencoba menulis record kelas.

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
8. Dengan akun siswa berbeda, pastikan Gabung kelas membuat `ClassroomMembership` tanpa mengubah record kelas. Refresh daftar anggota Teacher, keluarkan siswa, refresh lagi, lalu uji rejoin eksplisit dan Keluar di Student. Uji retry tanpa duplikasi row serta error `acceptShare`/`saveMembership`.

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
