import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> setUserRole(String uid, String email, String role) {
    return _db.collection('users').doc(uid).set({
      'email': email,
      'role': role,
    });
  }

  Future<AppUser> getUserData(String uid, String email) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('Usuario sin rol asignado en Firestore');
    }
    final role = roleFromString(doc.data()!['role'] as String);
    return AppUser(uid: uid, email: email, role: role);
  }
}