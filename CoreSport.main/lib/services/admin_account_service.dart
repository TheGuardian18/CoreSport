import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAccountService {
  final _db = FirebaseFirestore.instance;

  Future<bool> updateCredentials({
    required String role,
    required String newUsuario,
    required String newPassword,
  }) async {
    final query = await _db
        .collection('roleUsers')
        .where('role', isEqualTo: role)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    // Si cambia el usuario, verifica que no choque con otro ya existente
    if (newUsuario.trim().toLowerCase() != query.docs.first.data()['usuario']) {
      final existing = await _db
          .collection('roleUsers')
          .where('usuario', isEqualTo: newUsuario.trim().toLowerCase())
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return false; // usuario ya en uso
    }

    await query.docs.first.reference.update({
      'usuario': newUsuario.trim().toLowerCase(),
      'password': newPassword.trim(),
    });

    return true;
  }
}