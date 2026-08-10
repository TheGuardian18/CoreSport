import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cancha.dart';
import 'cloudinary_service.dart';

class CanchaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  Stream<List<Cancha>> getCanchasStream() {
    return _db.collection('canchas').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Cancha.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<String> uploadImageOnly(XFile imagen, String nombre) async {
    return await _cloudinary.uploadImage(imagen, nombre);
  }

  Future<void> guardarObjetoCancha(Cancha cancha) async {
    await _db.collection('canchas').add(cancha.toMap());
  }

  Future<void> actualizarCancha({required Cancha cancha, XFile? nuevaImagen}) async {
    String imageUrl = cancha.imageUrl;
    if (nuevaImagen != null) {
      imageUrl = await _cloudinary.uploadImage(nuevaImagen, cancha.nombre);
    }
    final updated = cancha.copyWith(imageUrl: imageUrl);
    await _db.collection('canchas').doc(cancha.id).update(updated.toMap());
  }

  Future<void> cambiarEstadoCancha(String id, String nuevoEstado) async {
    await _db.collection('canchas').doc(id).update({'estado': nuevoEstado});
  }

  Future<void> eliminarCancha(String id) async {
    await _db.collection('canchas').doc(id).delete();
  }
}