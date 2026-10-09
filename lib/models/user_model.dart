class UserModel {
  final int? id;
  final String nama;
  final String email;
  final String password;
  final String role; // 'mahasiswa' atau 'admin'
  final String? nim;
  final String? noHp;

  UserModel({
    this.id,
    required this.nama,
    required this.email,
    required this.password,
    required this.role,
    this.nim,
    this.noHp,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      nama: map['nama'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: map['role'] ?? 'mahasiswa',
      nim: map['nim'],
      noHp: map['no_hp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'email': email,
      'password': password,
      'role': role,
      'nim': nim,
      'no_hp': noHp,
    };
  }
}
