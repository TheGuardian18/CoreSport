import 'package:flutter/material.dart';
import '../models/cancha.dart';
import '../services/cancha_service.dart';
import 'admin_crear_cancha_screen.dart';

class AdminCanchasScreen extends StatefulWidget {
  const AdminCanchasScreen({super.key});

  @override
  State<AdminCanchasScreen> createState() => _AdminCanchasScreenState();
}

class _AdminCanchasScreenState extends State<AdminCanchasScreen> {
  final CanchaService _canchaService = CanchaService();
  static const Color _accentColor = Color(0xFF00FF87);

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'Disponible':
        return Colors.green;
      case 'Reservado':
        return Colors.orangeAccent;
      case 'Ocupado':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración de Canchas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo, color: _accentColor),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCrearCanchaScreen()));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Cancha>>(
        stream: _canchaService.getCanchasStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final canchas = snapshot.data ?? [];

          if (canchas.isEmpty) {
            return const Center(
              child: Text('No hay canchas registradas', style: TextStyle(color: Colors.grey, fontSize: 18)),
            );
          }

          final screenWidth = MediaQuery.of(context).size.width;
          int crossAxisCount = screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 420, // Altura ajustada
              ),
              itemCount: canchas.length,
              itemBuilder: (context, index) {
                final cancha = canchas[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Imagen y Estado
                      SizedBox(
                        height: 160,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            cancha.imageUrl.isNotEmpty
                                ? Image.network(cancha.imageUrl, fit: BoxFit.cover)
                                : Container(color: const Color(0xFF131B33), child: const Icon(Icons.sports_soccer, size: 50)),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getColorEstado(cancha.estado),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  cancha.estado,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Datos de la Cancha
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    cancha.nombre,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('\$${cancha.precioPorHora}/hr', style: const TextStyle(color: _accentColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${cancha.deporte} • ${cancha.esGras ? 'Gras' : 'Losa'}${cancha.esTapada ? ' • Tapada' : ''}${cancha.tieneIluminacion ? ' • Luz' : ''}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            if (cancha.descripcion.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(cancha.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                            const Divider(height: 16),

                            // BOTONES RÁPIDOS DE CAMBIO DE ESTADO
                            const Text('Cambiar Estado:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['Disponible', 'Reservado', 'Ocupado'].map((st) {
                                final isSelected = cancha.estado == st;
                                return ChoiceChip(
                                  label: Text(st, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.white)),
                                  selected: isSelected,
                                  selectedColor: _getColorEstado(st),
                                  onSelected: (val) {
                                    if (val) _canchaService.cambiarEstadoCancha(cancha.id, st);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCrearCanchaScreen(cancha: cancha)));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    await _canchaService.eliminarCancha(cancha.id);
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}