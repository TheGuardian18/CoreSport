import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class PinService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene un Stream en tiempo real del PIN de 4 dígitos activo
  Stream<String> getPinStream() {
    return _db.collection('security_pin').doc('current').snapshots().map((doc) {
      if (!doc.exists) return '0000';
      return doc.data()?['pin'] ?? '0000';
    });
  }

  /// Genera un PIN aleatorio de 4 dígitos (entre 1000 y 9999) y lo actualiza en Firestore
  Future<String> renovarPin() async {
    final random = Random();
    final newPin = (1000 + random.nextInt(9000)).toString();

    await _db.collection('security_pin').doc('current').set({
      'pin': newPin,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return newPin;
  }

  /// Valida si el PIN ingresado por el usuario de Mesa coincide con el PIN activo
  Future<bool> validarPin(String pinIngresado) async {
    final doc = await _db.collection('security_pin').doc('current').get();
    if (!doc.exists) return false;
    return doc.data()?['pin'] == pinIngresado.trim();
  }
}