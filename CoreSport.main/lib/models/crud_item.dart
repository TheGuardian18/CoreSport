class CrudItem {
  final String id;
  final String nombre;
  final String imageUrl;

  CrudItem({required this.id, required this.nombre, required this.imageUrl});

  factory CrudItem.fromMap(String id, Map<String, dynamic> data) {
    return CrudItem(
      id: id,
      nombre: data['nombre'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}