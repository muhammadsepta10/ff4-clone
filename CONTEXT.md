# Farm Game

Game manajemen waktu bertema farm untuk Android. Mekaniknya setara Farm Frenzy 4, dengan identitas orisinal. Pemain menjalankan farm per level di bawah tekanan waktu.

Istilah ditulis dalam bahasa Indonesia; nama di kode (`Code`) selalu bahasa Inggris.

## Language

### Struktur permainan

**Dunia** (`Code: World`):
Kumpulan level dengan latar dan tingkat kesulitan sendiri. Game memiliki empat dunia.
_Avoid_: Chapter, map, area

**Level** (`Code: Level`):
Satu sesi bermain di satu layar farm, dengan kondisi awal dan sasaran yang harus dicapai. Game memiliki 90 level.
_Avoid_: Stage, misi, ronde

**Sasaran** (`Code: Goal`):
Syarat kemenangan sebuah level, disampaikan sebagai tugas dari seorang karakter. Sasaran juga mencakup "tugas karakter"; keduanya satu konsep.
_Avoid_: Tugas, target, objektif, quest

**Tropi** (`Code: Trophy`):
Penghargaan yang didapat di sebuah level menurut seberapa cepat semua sasaran tercapai.
_Avoid_: Medali, bintang

**Achievement** (`Code: Achievement`):
Pencapaian lintas level yang terbuka sekali untuk seluruh permainan. Game memiliki 40 achievement.
_Avoid_: Trofi, badge

### Farm

**Hewan** (`Code: Animal`):
Makhluk yang dibeli pemain dan menghasilkan produk mentah bila diberi makan.
_Avoid_: Ternak, unit

**Hewan hibrida** (`Code: HybridAnimal`):
Hewan jenis baru yang lahir dari mempertemukan dua jenis hewan tertentu.
_Avoid_: Hewan campuran, mutan

**Predator** (`Code: Predator`):
Makhluk liar (beruang, tikus tanah) yang mengganggu farm dengan memakan hewan atau mencuri produk.
_Avoid_: Musuh, hama

**Workshop** (`Code: Workshop`):
Bangunan yang mengolah satu atau beberapa produk menjadi produk olahan.
_Avoid_: Pabrik, bengkel, mesin

### Produk

**Produk mentah** (`Code: RawProduct`):
Produk yang dihasilkan langsung oleh hewan.
_Avoid_: Bahan, resource

**Produk olahan** (`Code: CraftedProduct`):
Produk hasil workshop; bisa menjadi bahan workshop lain.
_Avoid_: Barang, item jadi

### Ekonomi

**Meter klik** (`Code: ClickMeter`):
Meter yang terisi setiap kali pemain mengetuk layar dan memberi uang saat penuh.
_Avoid_: Bar uang, combo meter

**Item tersembunyi** (`Code: HiddenItem`):
Objek rahasia di layar level yang mempercepat pengisian meter klik bila ditemukan.
_Avoid_: Easter egg, harta karun

**Boost** (`Code: Boost`):
Efek sementara yang ditukar dari item hasil memenangkan tropi.
_Avoid_: Power-up, buff
