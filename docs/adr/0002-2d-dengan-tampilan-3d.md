# 2D dengan tampilan "3D-look", bukan 3D asli

Game aslinya memakai grafis 3D, tetapi semua aset kita dibuat dengan Canva AI, yang hanya menghasilkan gambar 2D. Karena itu dunia game dirender sebagai sprite 2D yang digambar seolah 3D dari sudut kamera tetap. Karena kameranya tidak pernah berputar, pemain tidak bisa membedakannya dari 3D. Pendekatan ini juga jauh lebih ringan di perangkat target.

## Consequences

- Kamera tidak boleh berputar atau mengubah sudut pandang, karena tiap objek hanya punya satu sudut gambar.
- Urutan gambar (siapa di depan siapa) ditentukan dari posisi Y di layar, bukan dari kedalaman 3D.
