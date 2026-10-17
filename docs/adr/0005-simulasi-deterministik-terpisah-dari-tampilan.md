# Simulasi deterministik terpisah dari tampilan

Seluruh aturan permainan (hewan, produksi, workshop, gudang, predator, sasaran, waktu) hidup sebagai kelas GDScript murni, bukan Node, dan berjalan dengan tick tetap 10 kali per detik. Lapisan tampilan (scene, sprite, animasi, input) hanya membaca state simulasi dan mengirim perintah ke dalamnya. Kita sengaja menyimpang dari gaya Godot biasa yang menaruh logika di Node, karena 90 level harus bisa diputar ribuan kali oleh simulator balancing headless tanpa merender apa pun.

## Consequences

- Dilarang memakai `randf()` global atau waktu nyata di dalam simulasi. Semua acak berasal dari RNG ber-seed milik simulasi, supaya satu seed selalu menghasilkan hasil yang sama.
- Animasi dan efek boleh bebas di lapisan tampilan, tapi tidak boleh memengaruhi hasil simulasi.
