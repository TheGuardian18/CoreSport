import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimpleAuthService {
  final _db = FirebaseFirestore.instance;

  Future<void> ensureAnonAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<Map<String, dynamic>?> login(String usuario, String password) async {
    await ensureAnonAuth();
    final userInput = usuario.trim().toLowerCase();

    // 1. Si el usuario es de tipo 'mesa' (ej: mesa, mesa1, mesa2 ... mesa25)
    if (userInput.startsWith('mesa') && password == '123456') {
      return {
        'id': userInput,
        'usuario': userInput,
        'role': 'mesa',
      };
    }

    // 2. Para administrador y espectador, consulta Firestore normalmente
    final query = await _db
        .collection('roleUsers')
        .where('usuario', isEqualTo: userInput)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();

    if (data['password'] != password) return null;

    data['id'] = doc.id;
    return data;
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}