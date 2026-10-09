class UserSession {
  static int? userId;
  static String? nama;
  static String? nim;
  static String? kelas;
  static String? email;
  static String? role;
  static String? foto;
  static String? token;

  static void setUser(Map<String, dynamic> user, {String? authToken}) {
    userId = user['id'] is int
        ? user['id'] as int
        : int.tryParse(user['id']?.toString() ?? '');
    nama = user['nama']?.toString();
    nim = user['nim']?.toString();
    kelas = user['kelas']?.toString();
    email = user['email']?.toString();
    role = user['role']?.toString();
    foto = user['foto']?.toString();
    token = authToken ?? user['_token']?.toString();
  }

  static void clear() {
    userId = null;
    nama = null;
    nim = null;
    kelas = null;
    email = null;
    role = null;
    foto = null;
    token = null;
  }
}
