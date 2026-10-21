# Style bible dan template prompt aset

Panduan untuk setiap batch grafis (Canva AI) dan audio. Setiap batch disetujui pemilik proyek sebelum dipakai (US 80), lalu dicatat di `CREDITS.md` (ADR 0007).

## Gaya visual

- Kartun pedesaan yang hangat, garis tepi cokelat tua tebal (≈4 px pada 1080p), bayangan lembut di bawah objek.
- Kamera tetap dari atas-depan sekitar 35°; objek digambar dengan sedikit perspektif (ADR 0002). Tidak ada rotasi kamera.
- Palet dasar (sama dengan token di `ui/app.gd`): krem `#f6eedc`, panel `#fffaf0`, tinta `#3b2a1a`, hijau aksi `#6aa84f`, hijau tua `#38761d`, peringatan `#cc4125`, tanah `#c8a96a`, pagar `#8b6b3d`, rumput `#7cb342`.
- Proporsi chibi: kepala besar, mata bulat hitam dengan kilau putih.
- Ukuran sprite pada resolusi logis 1920×1080: hewan kecil 90 px, sapi 130 px, beruang 140 px, produk 60 px, workshop 250×180 px.

## Template prompt Canva AI

Pakai kalimat ini persis, hanya bagian `{…}` yang diganti. Jangan menyebut merek, judul game, atau karakter yang sudah ada.

```
A single {subject}, cute cartoon farm game asset, chibi proportions, thick dark-brown outline,
soft cel shading, warm countryside palette (cream, grass green, earthy brown), viewed from a
fixed 3/4 top-down angle, centered, plain white background, no text, no logo.
```

Contoh `{subject}`: `white hen with a red comb`, `fluffy sheep`, `black-and-white cow`, `wooden bakery hut`, `glass bottle of milk`.

Lampirkan gambar referensi gaya dari batch yang sudah disetujui. Setelah disetujui, hapus background, potong ke ukuran di atas, dan simpan di `art/<batch>/`. Daftarkan setiap sprite beserta tinggi tampilnya di `ui/art.gd`; tampilan memakai placeholder prosedural untuk id yang belum punya sprite.

## Animasi

- Tween prosedural: squash/stretch saat muncul atau diambil, goyang saat lapar, lompat saat berjalan.
- Hewan dan predator memakai cutout rig Skeleton2D (kepala, badan, kaki) setelah aset final masuk.

## Audio

- Musik: satu trek per dunia (`audio/music/w1.ogg` … `w4.ogg`) dan satu untuk menu (`menu.ogg`).
- Efek: `click`, `collect`, `coins`, `error`, `warning`, `cage`, `sparkle`, `goal`, `achievement`, `win`, `animal_lost`, `hybrid` di `audio/sfx/<nama>.ogg`. Id baru juga didaftarkan di `App.SFX_IDS`.
- Musik di-loop dan berpindah dengan crossfade. Potong jeda sunyi di akhir trek agar loop mulus. Encode ke Ogg Vorbis q3 tanpa metadata.
- Lisensi apa pun boleh, tetapi wajib dicatat di `CREDITS.md`.
