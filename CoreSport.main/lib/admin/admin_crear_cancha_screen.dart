import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/cancha.dart';
import '../services/cloudinary_service.dart';

class AdminCrearCanchaScreen extends StatefulWidget {
  final Cancha? cancha; // Si viene una cancha, es para editar

  const AdminCrearCanchaScreen({super.key, this.cancha});

  @override
  State<AdminCrearCanchaScreen> createState() => _AdminCrearCanchaScreenState();
}

class _AdminCrearCanchaScreenState extends State<AdminCrearCanchaScreen> {
  final _nombreController = TextEditingController();
  final _deporteController = TextEditingController(text: 'Fútbol');
  final _precioController = TextEditingController();
  final _descripcionController = TextEditingController();

  // Variables alineadas con el modelo Cancha (esGras, esTapada, tieneIluminacion)
  bool _esGras = true;
  bool _esTapada = false;
  bool _tieneIluminacion = true;

  XFile? _selectedImage;
  String? _currentImageUrl;
  bool _isUploading = false;
  String? _message;

  final List<String> _deportesDisponibles = ['Fútbol', 'Fútbol 11', 'Vóley', 'Básquet'];

  @override
  void initState() {
    super.initState();
    if (widget.cancha != null) {
      _nombreController.text = widget.cancha!.nombre;
      _deporteController.text = widget.cancha!.deporte;
      _precioController.text = widget.cancha!.precioPorHora.toString();
      _descripcionController.text = widget.cancha!.descripcion;
      _currentImageUrl = widget.cancha!.imageUrl;
      _esGras = widget.cancha!.esGras;
      _esTapada = widget.cancha!.esTapada;
      _tieneIluminacion = widget.cancha!.tieneIluminacion;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _deporteController.dispose();
    _precioController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _selectedImage = picked;
      });
    }
  }

  Future<void> _guardarCancha() async {
    final nombre = _nombreController.text.trim();
    final deporte = _deporteController.text.trim();
    final precioText = _precioController.text.trim();
    final descripcion = _descripcionController.text.trim();

    if (nombre.isEmpty || precioText.isEmpty) {
      setState(() => _message = 'Por favor completa el nombre y el precio.');
      return;
    }

    final precio = double.tryParse(precioText) ?? 0.0;

    setState(() {
      _isUploading = true;
      _message = null;
    });

    try {
      String imageUrl = _currentImageUrl ?? '';

      // Si seleccionó una nueva imagen, la subimos a Cloudinary
      if (_selectedImage != null) {
        imageUrl = await CloudinaryService().uploadImage(
          _selectedImage!,
          'cancha_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final canchaMap = {
        'nombre': nombre,
        'deporte': deporte,
        'precioPorHora': precio,
        'descripcion': descripcion,
        'imageUrl': imageUrl,
        'esGras': _esGras,
        'esTapada': _esTapada,
        'tieneIluminacion': _tieneIluminacion,
        'estado': 'Disponible',
      };

      if (widget.cancha == null) {
        // Crear nueva cancha
        await FirebaseFirestore.instance.collection('canchas').add({
          ...canchaMap,
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() => _message = '¡Cancha creada con éxito! ✅');
      } else {
        // Actualizar cancha existente
        await FirebaseFirestore.instance.collection('canchas').doc(widget.cancha!.id).update(canchaMap);
        setState(() => _message = '¡Cancha actualizada con éxito! ✅');
      }

      // Limpiar formulario si es nueva
      if (widget.cancha == null) {
        _nombreController.clear();
        _precioController.clear();
        _descripcionController.clear();
        setState(() {
          _selectedImage = null;
          _currentImageUrl = null;
          _esGras = true;
          _esTapada = false;
          _tieneIluminacion = true;
        });
      }
    } catch (e) {
      setState(() => _message = 'Error al guardar: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF00FF87);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cancha == null ? 'Crear Cancha' : 'Editar Cancha'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.cancha == null ? 'Registrar Nueva Cancha' : 'Modificar Cancha',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Nombre de la cancha
                    TextField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Cancha',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sports),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selector de Deporte
                    DropdownButtonFormField<String>(
                      value: _deportesDisponibles.contains(_deporteController.text) 
                          ? _deporteController.text 
                          : _deportesDisponibles.first,
                      decoration: const InputDecoration(
                        labelText: 'Deporte',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sports_soccer),
                      ),
                      items: _deportesDisponibles.map((dep) {
                        return DropdownMenuItem(value: dep, child: Text(dep));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _deporteController.text = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Precio por hora
                    TextField(
                      controller: _precioController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Precio por hora (\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    TextField(
                      controller: _descripcionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Ubicación',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Características con Switches (Gras/Losa, Iluminación, Tapada)
                    const Text('Características de la Cancha:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Tipo de Superficie: Gras (Activo) / Losa (Inactivo)'),
                      value: _esGras,
                      activeColor: accentColor,
                      onChanged: (val) => setState(() => _esGras = val),
                    ),
                    SwitchListTile(
                      title: const Text('Con Iluminación (Luz)'),
                      value: _tieneIluminacion,
                      activeColor: accentColor,
                      onChanged: (val) => setState(() => _tieneIluminacion = val),
                    ),
                    SwitchListTile(
                      title: const Text('Cancha Tapada (Techada)'),
                      value: _esTapada,
                      activeColor: accentColor,
                      onChanged: (val) => setState(() => _esTapada = val),
                    ),
                    const SizedBox(height: 16),

                    // Botón para seleccionar imagen
                    const Text('Fotografía de la Cancha:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: Text(_selectedImage == null ? 'Seleccionar nueva foto' : 'Foto seleccionada ✓'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Vista previa de la imagen
                    if (_selectedImage != null)
                      FutureBuilder<Uint8List>(
                        future: _selectedImage!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(snapshot.data!, height: 160, fit: BoxFit.cover),
                          );
                        },
                      )
                    else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentImageUrl!,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                        ),
                      ),

                    const SizedBox(height: 20),

                    if (_message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _message!.contains('✅') ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _message!.contains('✅') ? accentColor : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Botón Guardar / Actualizar
                    ElevatedButton(
                      onPressed: _isUploading ? null : _guardarCancha,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(
                              widget.cancha == null ? 'Crear Cancha' : 'Guardar Cambios',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}