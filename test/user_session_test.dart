import 'package:flutter_test/flutter_test.dart';
import 'package:sipalab/session/user_session.dart';

void main() {
  tearDown(UserSession.clear);

  test('menyimpan data pengguna dan bearer token dari login online', () {
    UserSession.setUser({
      'id': 7,
      'nama': 'Budi Santoso',
      'nim': '221011234',
      'kelas': '23TI-01',
      'email': 'budi@labkamp.com',
      'role': 'mahasiswa',
    }, authToken: '1|abc123');

    expect(UserSession.userId, 7);
    expect(UserSession.nama, 'Budi Santoso');
    expect(UserSession.kelas, '23TI-01');
    expect(UserSession.role, 'mahasiswa');
    expect(UserSession.token, '1|abc123');
  });

  test('id berupa string tetap dikonversi menjadi integer', () {
    UserSession.setUser({
      'id': '12',
      'nama': 'Siti Rahayu',
      'email': 'siti@labkamp.com',
      'role': 'mahasiswa',
    });

    expect(UserSession.userId, 12);
  });

  test('token tersimpan di dalam map sesi offline dapat dipulihkan', () {
    UserSession.setUser({
      'id': 3,
      'nama': 'Andi Pratama',
      'email': 'andi@labkamp.com',
      'role': 'mahasiswa',
      '_token': '2|offline-token',
    });

    expect(UserSession.token, '2|offline-token');
  });

  test('logout membersihkan seluruh data sesi termasuk token', () {
    UserSession.setUser({
      'id': 1,
      'nama': 'Admin Laboratorium',
      'email': 'admin@labkamp.com',
      'role': 'admin',
    }, authToken: '3|token');

    UserSession.clear();

    expect(UserSession.userId, isNull);
    expect(UserSession.email, isNull);
    expect(UserSession.role, isNull);
    expect(UserSession.token, isNull);
  });
}
