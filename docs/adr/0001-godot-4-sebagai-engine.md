# Godot 4 sebagai engine

Game ini dikerjakan sepenuhnya oleh agent AI dan target utamanya APK Android (acuan: Samsung A33). Karena itu kita memilih Godot 4 dengan GDScript, bukan Unity atau Defold. Scene, resource, dan script Godot semuanya berupa teks bersih yang bisa dibuat dan diedit agent tanpa membuka editor. Export APK bisa dijalankan lewat CLI headless tanpa aktivasi lisensi. Ukuran APK dan performanya di perangkat menengah juga lebih dari cukup untuk game 2D.

## Considered Options

- **Unity**: ekosistemnya paling matang. Ditolak karena scene/prefab berupa YAML dengan GUID yang rawan rusak bila diedit agent sebagai teks, build butuh Editor dengan aktivasi lisensi, dan APK-nya lebih berat.
- **Defold**: APK paling kecil. Ditolak karena ekosistem dan contoh kodenya sedikit, sehingga agent lebih sering salah.
