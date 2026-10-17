# Konten game sebagai JSON dengan skema

Data konten (level, hewan, produk, resep workshop, harga, achievement) disimpan sebagai file JSON yang divalidasi skema di CI, bukan sebagai Resource `.tres` Godot. Konten akan terus dibuat ulang oleh agent dan disetel oleh simulator balancing, dan JSON paling mudah dihasilkan, didiff, dan divalidasi di luar editor. Kekurangannya, data tidak bisa diedit lewat Inspector Godot.
