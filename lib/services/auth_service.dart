import '../models/user_model.dart';
import '../session/user_session.dart';
import 'api_service.dart';
import 'offline_service.dart';

class AuthService {
  // Login User
  Future<UserModel?> login(String email, String password) async {
    try {
      final map = await ApiService.postMap('/login', {
        'email': email,
        'password': password,
      });
      if (map == null) return null;

      final rawUser = map['user'];
      if (rawUser is! Map) return null;
      final user = Map<String, dynamic>.from(rawUser);
      final token = map['token']?.toString() ?? map['access_token']?.toString();
      if (token == null || token.isEmpty) return null;

      UserSession.setUser(user, authToken: token);

      // Ingat sesi untuk login offline (saat server mati).
      await OfflineService.instance.saveLogin(user, password, token: token);

      return UserModel.fromMap(user);
    } on OfflineException {
      // Server mati → coba login pakai sesi tersimpan.
      final cached =
          await OfflineService.instance.offlineLogin(email, password);
      if (cached != null) {
        UserSession.setUser(cached);
        return UserModel.fromMap(cached);
      }
      rethrow;
    }
  }

  // Register Mahasiswa Baru
  Future<int> register(UserModel user) async {
    final map = await ApiService.postMap('/register', user.toMap());
    return map?['id'] ?? 0;
  }

  // Cek apakah Email sudah terdaftar
  Future<bool> isEmailRegistered(String email) async {
    final map = await ApiService.getMap('/users/check-email?email=$email');
    return map?['registered'] == true;
  }

  // Get Profil User by ID
  Future<UserModel?> getUserById(int id) async {
    final map = await ApiService.getMap('/users/$id');
    if (map == null) return null;
    return UserModel.fromMap(map);
  }
}
