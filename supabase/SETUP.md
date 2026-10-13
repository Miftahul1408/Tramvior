# Menyiapkan Supabase Tramvior

## 1. Terapkan schema terbaru

Di Supabase Dashboard, buka **SQL Editor → New query**, tempel seluruh isi `schema.sql`, lalu klik **Run**. Jalankan ulang setelah perubahan schema; skrip ini menggunakan operasi yang aman untuk diterapkan ulang.

## 2. Atur konfirmasi email

Di **Authentication → Providers → Email**, aktifkan konfirmasi email. Di **Authentication → URL Configuration**, masukkan alamat situs Tramvior yang dipakai ke **Site URL** dan **Redirect URLs**. Untuk pengembangan lokal, tambahkan origin localhost yang benar-benar digunakan.

## 3. Buat akun admin

Buat pengguna admin melalui **Authentication → Users** dan pastikan emailnya sudah dikonfirmasi. Setelah itu, buka SQL Editor dan jalankan perintah berikut dengan alamat email admin yang benar:

```sql
update auth.users
set raw_app_meta_data =
  coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where email = 'email-admin-kamu@example.com';
```

Keluar lalu masuk kembali di halaman admin agar token sesi memuat role baru. Jangan menambahkan role admin ke metadata yang dapat diubah pengguna sendiri.

## 4. Pindahkan pendaftar lama

Buka aplikasi Tramvior di browser dan origin yang sama dengan tempat akun lama didaftarkan. Masuk menggunakan email serta kata sandi lamanya. Aplikasi memeriksa hash akun lama di browser, lalu meminta Supabase membuat akun autentikasi dengan kata sandi tersebut. Konfirmasi email, lalu masuk lagi dengan kata sandi itu. Profil, progres, dan foto kartu lama dipindahkan ke Supabase; data lama di browser baru dihapus setelah pemindahan berhasil.

Jangan bersihkan data situs atau `localStorage` sebelum migrasi berhasil. Jika akun lama tidak ditemukan di browser asal, atau pembuatan akun Supabase untuk email itu sudah pernah dimulai, gunakan **Lupa kata sandi?** atau hubungi pengelola sebelum mencoba lagi.

## Catatan

- Project URL dan publishable key berada di `supabase-client.js`. Publishable key memang digunakan oleh aplikasi browser; jangan pernah memasukkan password database, `service_role`, atau secret key ke file frontend.
- Profil, foto, serta progres belajar disimpan di Supabase. Preferensi tampilan dan status onboarding tetap tersimpan lokal di browser.
- Login dan penyimpanan progres memerlukan koneksi internet. Konten yang sudah dimuat mungkin masih bisa dibuka offline, tetapi progres offline tidak disimpan.
