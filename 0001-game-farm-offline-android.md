# PRD: Game farm manajemen waktu, offline, untuk Android

> Label: `ready-for-agent`. Diterbitkan ke issue tracker setelah repo GitHub dibuat.
> Istilah mengikuti `CONTEXT.md`. Keputusan arsitektur ada di `docs/adr/0001`–`0007`.

## Problem Statement

Saya ingin memainkan game sekelas Farm Frenzy 4 di HP Android saya (Samsung A33), lengkap dengan semua fiturnya, tanpa perlu internet. Game aslinya buatan Alawar dan dirancang untuk PC dengan mouse. Saya ingin versi saya sendiri yang nyaman dimainkan dengan jari dalam mode landscape, berjalan lancar, dan bisa dikembangkan sepenuhnya oleh agent AI tanpa saya harus menulis kode.

## Solution

Sebuah game 2D bergaya 3D yang mekaniknya setara Farm Frenzy 4: 90 level dalam empat dunia, semua jenis hewan termasuk hewan hibrida, workshop berantai, gudang, truk ke kota, predator, meter klik, item tersembunyi, tropi, boost, 40 achievement, kustomisasi karakter, dan tutorial yang mengajar sambil bermain. Nama, karakter, cerita, grafis, dan audionya orisinal.

Game berjalan offline penuh dan didistribusikan sebagai APK yang di-sideload. Game menyesuaikan diri dengan rasio layar apa pun, berjalan stabil 60 FPS di A33, dan menyimpan progres secara lokal, termasuk melanjutkan level yang terputus karena aplikasi ditutup Android.

Pengerjaan dimulai dari vertical slice (Dunia 1, sekitar 5 level dengan grafis, audio, dan animasi final) yang saya uji di A33. Setelah disetujui, baru dilanjutkan ke produksi massal level dan dunia sisanya.

## User Stories

### Profil dan kampanye

1. As a pemain, I want memilih satu dari tiga slot profil, so that progres saya terpisah dari progres anggota keluarga lain yang memakai HP yang sama.
2. As a pemain, I want membuat profil baru dengan nama, so that saya bisa mengenali profil saya.
3. As a pemain, I want memilih dan mendandani karakter pemain saat membuat profil, so that farm terasa milik saya.
4. As a pemain, I want mengubah dandanan karakter belakangan, so that saya bisa memakai pilihan yang baru terbuka.
5. As a pemain, I want menghapus profil dengan konfirmasi, so that slot bisa dipakai ulang tanpa terhapus tidak sengaja.
6. As a pemain, I want melihat peta empat dunia beserta level-levelnya, so that saya tahu posisi saya dalam kampanye.
7. As a pemain, I want level berikutnya terbuka setelah saya memenangkan level sebelumnya, so that ada rasa kemajuan.
8. As a pemain, I want dunia berikutnya terbuka setelah level terakhir dunia sebelumnya dimenangkan, so that tiap dunia terasa sebagai babak baru.
9. As a pemain, I want melihat tropi terbaik yang pernah saya raih di setiap level, so that saya tahu level mana yang layak diulang.
10. As a pemain, I want mengulang level yang sudah dimenangkan, so that saya bisa memperbaiki tropi.
11. As a pemain, I want cerita singkat dari karakter-karakter disampaikan di awal dunia dan level, so that ada alasan untuk terus bermain.

### Sesi level

12. As a pemain, I want melihat sasaran level sebelum mulai, so that saya bisa merencanakan.
13. As a pemain, I want melihat sisa progres setiap sasaran selama bermain, so that saya tahu apa yang masih kurang.
14. As a pemain, I want melihat waktu berjalan beserta batas emas dan perak, so that saya bisa mengejar tropi terbaik.
15. As a pemain, I want level dinyatakan menang begitu semua sasaran tercapai, so that saya tidak perlu menunggu.
16. As a pemain, I want mendapat tropi sesuai waktu penyelesaian, so that kecepatan saya dihargai.
17. As a pemain, I want tetap bisa menang meski melewati batas perak, so that level tidak terasa gagal hanya karena lambat.
18. As a pemain, I want menjeda level kapan saja, so that saya bisa berhenti sebentar.
19. As a pemain, I want keluar dari level dan memulainya ulang, so that saya bisa mencoba strategi lain.
20. As a pemain, I want melihat ringkasan hasil di akhir level (waktu, tropi, uang, item yang didapat), so that saya paham pencapaian saya.
21. As a pemain, I want sebuah level dilanjutkan persis dari posisi terakhir saat aplikasi ditutup atau dimatikan Android, so that progres di tengah level tidak hilang.
22. As a pemain, I want timer berhenti selama aplikasi tidak aktif, so that saya tidak dirugikan oleh telepon masuk.

### Hewan dan pakan

23. As a pemain, I want membeli hewan dengan uang level, so that farm saya bisa berproduksi.
24. As a pemain, I want hewan berkeliaran di area farm dan mencari makan sendiri, so that farm terasa hidup.
25. As a pemain, I want menanam rumput dengan mengetuk tanah, so that hewan punya makanan.
26. As a pemain, I want menanam rumput memakai air dari sumur yang bisa habis dan diisi ulang, so that ada sumber daya yang harus dikelola.
27. As a pemain, I want melihat tanda bila hewan lapar, so that saya tahu kapan harus menanam rumput.
28. As a pemain, I want hewan yang terlalu lama lapar mati atau hilang sesuai aturan game asli, so that ada risiko bila saya lalai.
29. As a pemain, I want hewan yang makan menghasilkan produk mentah secara berkala, so that saya punya bahan untuk dijual atau diolah.
30. As a pemain, I want mengambil produk mentah dengan mengetuknya, so that produk masuk ke gudang.
31. As a pemain, I want produk yang tidak diambil hilang setelah beberapa waktu, so that saya harus aktif.
32. As a pemain, I want menjual hewan yang tidak lagi dibutuhkan, so that uang bisa dialihkan.
33. As a pemain, I want mempertemukan dua jenis hewan tertentu untuk mendapatkan hewan hibrida, so that ada kejutan dan produk baru.
34. As a pemain, I want hewan hibrida menghasilkan produknya sendiri, so that kejutan tersebut punya nilai dalam permainan.

### Gudang, workshop, dan produk

35. As a pemain, I want gudang menampung produk dengan kapasitas terbatas, so that saya harus memutuskan kapan menjual.
36. As a pemain, I want melihat isi dan sisa kapasitas gudang, so that saya tidak kehabisan tempat.
37. As a pemain, I want meningkatkan kapasitas gudang di tengah level, so that saya bisa menyimpan lebih banyak bila mampu membayar.
38. As a pemain, I want membangun workshop di slot yang tersedia, so that saya bisa membuat produk olahan.
39. As a pemain, I want workshop mengolah produk mentah atau produk olahan lain menjadi produk olahan, so that ada rantai produksi.
40. As a pemain, I want melihat progres produksi di setiap workshop, so that saya tahu kapan hasilnya jadi.
41. As a pemain, I want workshop mengambil bahan dari gudang dan menaruh hasil siap ambil, so that alurnya konsisten dengan produk mentah.
42. As a pemain, I want meningkatkan workshop agar lebih cepat atau lebih efisien, so that saya bisa mengejar tropi emas.
43. As a pemain, I want menjual workshop yang tidak dipakai, so that slot bisa dipakai untuk workshop lain.

### Kota, truk, dan uang

44. As a pemain, I want memuat produk dari gudang ke truk, so that produk bisa dijual di kota.
45. As a pemain, I want truk berangkat ke kota, menjual muatannya, lalu kembali membawa uang, so that ada jeda waktu yang harus diperhitungkan.
46. As a pemain, I want melihat harga jual setiap produk sebelum memuat truk, so that saya bisa memilih yang paling menguntungkan.
47. As a pemain, I want meningkatkan truk agar kapasitasnya lebih besar atau perjalanannya lebih cepat, so that penjualan lebih efektif.
48. As a pemain, I want membeli bahan dari kota bila sasaran membutuhkannya, so that saya tidak terkunci bila hewan saya kurang.
49. As a pemain, I want melihat uang level setiap saat, so that saya tahu daya beli saya.

### Predator

50. As a pemain, I want predator seperti beruang muncul dan mengancam hewan atau produk, so that ada tantangan aksi.
51. As a pemain, I want mengurung beruang dengan mengetuknya berulang kali, so that hewan saya selamat.
52. As a pemain, I want beruang yang dikurung bisa diambil dan dijual, so that ancaman menjadi keuntungan.
53. As a pemain, I want tikus tanah muncul dan mengganggu farm sampai saya menghalaunya, so that saya harus tetap waspada.
54. As a pemain, I want peringatan sebelum predator datang, so that saya punya kesempatan bereaksi.

### Meter klik, item tersembunyi, dan boost

55. As a pemain, I want meter klik terisi setiap kali saya mengetuk layar, so that ketukan saya selalu bernilai.
56. As a pemain, I want mendapat uang saat meter klik penuh, so that saya punya pemasukan tambahan.
57. As a pemain, I want menemukan item tersembunyi di layar level, so that meter klik terisi lebih cepat.
58. As a pemain, I want tahu berapa item tersembunyi yang tersisa di sebuah level, so that saya tergoda mencarinya.
59. As a pemain, I want mendapat item dari memenangkan tropi, so that ada hadiah di luar level.
60. As a pemain, I want menukar item menjadi boost sebelum memulai level, so that saya bisa memudahkan level yang sulit.
61. As a pemain, I want melihat boost yang aktif dan sisa durasinya, so that saya bisa memanfaatkannya sebaik mungkin.

### Achievement dan tutorial

62. As a pemain, I want membuka 40 achievement lintas level, so that ada tujuan jangka panjang.
63. As a pemain, I want notifikasi saat achievement terbuka, so that pencapaian terasa.
64. As a pemain, I want melihat daftar achievement beserta yang belum terbuka, so that saya tahu apa yang bisa dikejar.
65. As a pemain, I want tutorial muncul tepat saat sebuah mekanik pertama kali diperkenalkan, so that saya belajar sambil bermain.
66. As a pemain, I want tutorial tidak muncul lagi setelah selesai, so that permainan tidak terganggu.

### Kontrol, layar, dan kenyamanan

67. As a pemain, I want game berjalan landscape, so that sesuai dengan tata letak farm.
68. As a pemain, I want semua elemen yang bisa diketuk cukup besar untuk jari, so that saya jarang salah ketuk.
69. As a pemain, I want game memenuhi layar HP berasio 16:9 sampai 21:9 dan tablet 4:3 tanpa gepeng, so that game nyaman di perangkat apa pun.
70. As a pemain, I want HUD tidak tertutup lubang kamera atau sudut layar melengkung, so that semua informasi terbaca.
71. As a pemain, I want game berjalan stabil 60 FPS di A33, bahkan di level paling ramai, so that permainan terasa lancar.
72. As a pemain, I want level termuat dalam 3 detik atau kurang, so that saya tidak menunggu lama.
73. As a pemain, I want memilih bahasa Indonesia atau Inggris, so that saya bisa memakai bahasa yang saya suka.
74. As a pemain, I want mengatur volume musik dan efek suara secara terpisah, so that saya bisa bermain di tempat umum.
75. As a pemain, I want musik berbeda di setiap dunia dan di menu, so that suasananya berganti.
76. As a pemain, I want melihat menu Credits yang mencantumkan semua aset pihak ketiga, so that pembuatnya dihargai.
77. As a pemain, I want game bisa dimainkan tanpa internet sama sekali, so that saya bisa bermain di mana saja.

### Pembangun (agent dan pemilik proyek)

78. As a pemilik proyek, I want CI membangun APK setiap ada push, so that saya tinggal mengunduh dan memasangnya di A33.
79. As a pemilik proyek, I want sebuah scene benchmark yang menampilkan FPS dan waktu muat di perangkat, so that saya bisa memverifikasi target performa sendiri.
80. As a pemilik proyek, I want menyetujui setiap batch aset Canva sebelum dipakai, so that gaya grafis tetap konsisten.
81. As a pemilik proyek, I want vertical slice Dunia 1 selesai dan bisa dimainkan sebelum produksi massal, so that arah game bisa dikoreksi lebih awal.
82. As an agent, I want style bible dan template prompt aset yang tertulis, so that setiap aset baru sesuai gaya yang disetujui.
83. As an agent, I want setiap file konten JSON divalidasi skema di CI, so that kesalahan konten ketahuan sebelum masuk build.
84. As an agent, I want bot simulator yang memainkan setiap level headless, so that saya bisa membuktikan level bisa dimenangkan.
85. As an agent, I want batas tropi emas dan perak dihitung otomatis dari waktu bot, so that 90 level punya kurva kesulitan yang konsisten.
86. As an agent, I want sebuah level gagal masuk build bila bot tidak bisa memenangkannya, so that tidak ada level buntu.
87. As an agent, I want setiap aset pihak ketiga tercatat di `CREDITS.md` beserta sumber dan lisensinya, so that aset bermasalah mudah dilacak bila game kelak dirilis.
88. As an agent, I want simulasi yang sama selalu memberi hasil identik untuk seed dan rangkaian perintah yang sama, so that bug bisa direproduksi.

## Implementation Decisions

### Engine, platform, dan distribusi

- Godot 4 dengan GDScript (ADR 0001). Renderer ringan untuk mobile. Export APK Android lewat CLI headless di CI.
- 2D dengan tampilan 3D dari kamera tetap (ADR 0002). Urutan gambar mengikuti posisi Y. Kamera tidak pernah berputar.
- Offline penuh (ADR 0003). Untuk penggunaan pribadi dan di-sideload (ADR 0007). Ukuran APK maksimal 1 GB.
- Orientasi landscape. Resolusi logis 1920×1080 dengan mode stretch `canvas_items` dan aspect `expand`. Area bermain inti 16:9 selalu terlihat utuh. Background mengisi sisa layar dari 4:3 sampai 21:9. HUD menempel ke safe area. Tidak ada opsi kualitas grafis.
- Tekstur dikemas dalam atlas dengan kompresi ETC2.
- Bahasa UI Indonesia dan Inggris lewat file terjemahan sejak awal. Semua identifier kode berbahasa Inggris sesuai kolom `Code` di glosarium.

### Modul

**`GameCore` (fasad headless, satu-satunya seam)**
Lapisan tampilan, bot, validator, dan tes hanya berinteraksi lewat fasad ini. Fasad ini berisi kode GDScript murni tanpa Node. Fasad memiliki dua bagian:

- **Kampanye**: kelola tiga slot profil, kunci level dan dunia, tropi terbaik per level, achievement, inventaris item, penukaran item menjadi boost, kustomisasi karakter, dan status tutorial. Kampanye menerima hasil sesi level dan memperbarui progres.
- **Sesi level**: dibuat dari data level dan sebuah seed, plus boost yang dipilih. Sesi menerima perintah pemain yang bertipe (beli/jual hewan, tanam rumput, isi sumur, ambil produk, bangun/tingkatkan/jual workshop, tingkatkan gudang, muat/kirim truk, beli dari kota, ketuk predator, ketuk meter klik, temukan item tersembunyi). Sesi maju sebanyak N tick, membuka state yang bisa dibaca, dan memancarkan event (produk muncul, hewan lapar, predator datang, sasaran tercapai, level menang, achievement terbuka). Sesi juga mendukung snapshot dan restore lengkap.

**Simulasi (internal `GameCore`)**
Deterministik dengan tick tetap 10 kali per detik (ADR 0005). Semua acak berasal dari RNG ber-seed milik sesi. Tidak boleh ada waktu nyata atau `randf()` global. Aturan hewan, pakan, sumur, gudang, workshop, truk, predator, meter klik, item tersembunyi, boost, dan sasaran semuanya hidup di sini.

**Konten**
JSON dengan skema (ADR 0006): dunia, level (kondisi awal, sasaran, slot workshop, jadwal predator, item tersembunyi, batas tropi), hewan, kombinasi hewan hibrida, produk mentah dan olahan, resep workshop, harga, tingkat upgrade, achievement, opsi kustomisasi karakter, item dan boost, serta naskah tutorial dan cerita. Pemuat konten menolak data yang tidak lolos skema.

**Bot balancing dan validator**
Program headless yang memakai `GameCore`. Untuk setiap level, bot "pemain bagus" memainkan level dengan beberapa seed. Level gagal bila bot tidak bisa menang. Batas tropi dihitung sebagai emas = waktu bot × 1,3 dan perak = × 1,8, lalu ditulis kembali ke data level. Faktor ini disetel ulang setelah playtest vertical slice. Angka balancing dirancang sendiri dengan data publik hanya sebagai acuan bentuk kurva (ADR 0004).

**Penyimpanan**
Progres kampanye per profil disimpan lokal. Saat aplikasi masuk latar belakang, snapshot sesi level aktif ditulis. Saat aplikasi dibuka lagi, sesi dilanjutkan dari snapshot itu. Timer berhenti selama aplikasi tidak aktif.

**Tampilan dan UI**
Scene Godot yang membaca state `GameCore`, mengirim perintah dari input sentuh, dan menerjemahkan event menjadi animasi dan suara. Animasi utama berupa tween prosedural (squash/stretch, goyang, lompat). Hewan dan predator memakai cutout rig dengan Skeleton2D. Elemen yang bisa diketuk minimal sekitar 48 dp. Tampilan tidak boleh mengubah state simulasi selain lewat perintah.

**Pipeline aset**
Grafis dibuat dengan Canva AI memakai style bible, template prompt tetap, dan gambar referensi gaya. Setiap batch disetujui pemilik proyek, lalu background-nya dihapus. Prompt tidak boleh menyebut merek atau karakter yang sudah ada. Logo dan nama game tidak dibuat dengan AI. Audio berasal dari aset open source dengan lisensi apa pun, dan semuanya dicatat di `CREDITS.md` yang ditampilkan di menu Credits.

**Build dan verifikasi perangkat**
CI menjalankan validasi skema, tes `GameCore`, bot untuk semua level, lalu membangun APK sebagai artefak unduhan. Scene benchmark di dalam APK memuat level terberat dan menampilkan FPS rata-rata, FPS 1% terendah, dan waktu muat.

### Kriteria lulus performa (A33)

- 60 FPS stabil di level paling ramai, dengan FPS 1% terendah ≥ 50.
- Waktu muat level ≤ 3 detik.
- APK ≤ 1 GB.

### Tahapan

1. Vertical slice: Dunia 1, sekitar 5 level, dengan semua mekanik yang dibutuhkan level tersebut serta grafis, audio, dan animasi final. Diuji di A33 dan disetujui pemilik proyek.
2. Produksi massal: seluruh 90 level, empat dunia, semua hewan dan hewan hibrida, 40 achievement, dan semua opsi kustomisasi.

## Testing Decisions

- **Tes yang baik hanya menguji perilaku eksternal lewat `GameCore`**: siapkan sesi dari data level dan seed, kirim perintah, majukan tick, lalu periksa state dan event yang terbuka. Tes tidak boleh menyentuh kelas internal simulasi, sehingga internal bebas di-refactor.
- **Modul yang diuji**: hanya `GameCore`, mencakup kampanye dan sesi level. Bot, validator, dan pemuat konten ikut teruji karena bekerja lewat seam yang sama.
- **Jenis tes**:
  - Tes aturan per mekanik dengan data level kecil buatan tes. Contohnya: hewan lapar tanpa rumput, gudang penuh menolak produk, workshop memakan bahan dan menghasilkan produk olahan, truk kembali membawa uang, beruang terkurung setelah cukup ketukan, kombinasi hewan hibrida, meter klik memberi uang, dan boost aktif lalu kedaluwarsa.
  - Tes determinisme: seed dan rangkaian perintah yang sama menghasilkan state akhir identik.
  - Tes snapshot/restore: sesi yang di-snapshot di tengah jalan lalu dilanjutkan berakhir identik dengan sesi yang berjalan tanpa terputus.
  - Tes kampanye: menang membuka level berikutnya, tropi terbaik tidak turun saat level diulang, achievement terbuka sekali, dan tiga profil saling terpisah.
  - Tes konten (di CI, untuk semua level): lolos skema, bisa dimenangkan bot dengan beberapa seed, dan batas tropi konsisten dengan waktu bot.
- **Tidak diuji otomatis**: rendering, animasi, audio, dan input sentuh. Semuanya diverifikasi lewat scene benchmark dan playtest di A33.
- **Prior art**: belum ada karena repo masih baru. Kerangka tes headless Godot (misalnya GUT atau gdUnit4) dipilih saat setup repo.

## Out of Scope

- Semua fitur online: akun, leaderboard, cloud save, sinkronisasi antar-perangkat, dan iklan.
- Monetisasi, termasuk IAP dan versi demo.
- Rilis ke Google Play atau toko aplikasi lain.
- Grafis 3D asli, kamera yang bisa berputar, dan opsi kualitas grafis.
- Platform selain Android, termasuk iOS dan PC.
- Bahasa selain Indonesia dan Inggris.
- Aset, nama, karakter, cerita, maupun tabel angka yang diambil dari game asli.

## Further Notes

- Repo GitHub privat akan dibuat oleh pemilik proyek saat pengerjaan dimulai. PRD ini, `CONTEXT.md`, dan ADR dipindahkan ke repo tersebut, lalu PRD diterbitkan sebagai issue berlabel `ready-for-agent` setelah `/setup-matt-pocock-skills` dijalankan.
- Detail aturan yang belum diputuskan pemilik proyek (misalnya apakah hewan yang terlalu lama lapar mati atau kabur, serta perilaku persis tikus tanah) mengikuti game asli sejauh bisa dipastikan dari sumber publik, lalu dikonfirmasi saat review vertical slice.
- Output Canva AI boleh dipakai, tetapi Canva tidak menjamin hasilnya unik dan gambar AI mungkin tidak dilindungi hak cipta. Ini tidak menjadi masalah untuk penggunaan pribadi.
