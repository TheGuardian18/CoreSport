import 'package:cloud_firestore/cloud_firestore.dart';

class Cancha {
  final String id;
  final String nombre;
  final String deporte;
  final double precioPorHora;
  final String imageUrl;
  final String estado; // 'Disponible', 'Reservado', 'Ocupado'
  final String descripcion;
  final bool esTapada;
  final bool esGras; // true = Gras, false = Losa
  final bool tieneIluminacion;
  final DateTime? createdAt;

  Cancha({
    required this.id,
    required this.nombre,
    required this.deporte,
    required this.precioPorHora,
    required this.imageUrl,
    this.estado = 'Disponible',
    this.descripcion = '',
    this.esTapada = false,
    this.esGras = true,
    this.tieneIluminacion = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'deporte': deporte,
      'precioPorHora': precioPorHora,
      'imageUrl': imageUrl,
      'estado': estado,
      'descripcion': descripcion,
      'esTapada': esTapada,
      'esGras': esGras,
      'tieneIluminacion': tieneIluminacion,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory Cancha.fromMap(String id, Map<String, dynamic> map) {
    return Cancha(
      id: id,
      nombre: map['nombre'] ?? '',
      deporte: map['deporte'] ?? '',
      precioPorHora: (map['precioPorHora'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      estado: map['estado'] ?? (map['disponible'] == false ? 'Ocupado' : 'Disponible'),
      descripcion: map['descripcion'] ?? '',
      esTapada: map['esTapada'] ?? false,
      esGras: map['esGras'] ?? true,
      tieneIluminacion: map['tieneIluminacion'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Cancha copyWith({
    String? id,
    String? nombre,
    String? deporte,
    double? precioPorHora,
    String? imageUrl,
    String? estado,
    String? descripcion,
    bool? esTapada,
    bool? esGras,
    bool? tieneIluminacion,
    DateTime? createdAt,
  }) {
    return Cancha(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      deporte: deporte ?? this.deporte,
      precioPorHora: precioPorHora ?? this.precioPorHora,
      imageUrl: imageUrl ?? this.imageUrl,
      estado: estado ?? this.estado,
      descripcion: descripcion ?? this.descripcion,
      esTapada: esTapada ?? this.esTapada,
      esGras: esGras ?? this.esGras,
      tieneIluminacion: tieneIluminacion ?? this.tieneIluminacion,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}