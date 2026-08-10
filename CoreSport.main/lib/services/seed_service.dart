import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SeedService {
  final _db = FirebaseFirestore.instance;

  Future<void> seedRoleAccounts() async {
    // Necesario: crear sesión anónima antes de tocar Firestore
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    final accounts = [
      {'usuario': 'administrador', 'password': '123456', 'role': 'administrador'},
      {'usuario': 'mesa', 'password': '123456', 'role': 'mesa'},
      {'usuario': 'espectador', 'password': '123456', 'role': 'espectador'},
    ];

    for (final acc in accounts) {
      final existing = await _db
          .collection('roleUsers')
          .where('usuario', isEqualTo: acc['usuario'])
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('roleUsers').add(acc);
      }
    }
  }
}