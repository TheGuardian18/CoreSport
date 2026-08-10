import 'package:flutter/material.dart';
import '../services/pin_service.dart';

class AdminGestionMesasScreen extends StatefulWidget {
  const AdminGestionMesasScreen({super.key});

  @override
  State<AdminGestionMesasScreen> createState() => _AdminGestionMesasScreenState();
}

class _AdminGestionMesasScreenState extends State<AdminGestionMesasScreen> {
  final PinService _pinService = PinService();
  bool _isGenerating = false;

  // Color verde neón para destacados e íconos
  static const Color _accentColor = Color(0xFF00FF87); 

  Future<void> _generarNuevoPin() async {
    setState(() => _isGenerating = true);
    try {
      final nuevoPin = await _pinService.renovarPin();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Nuevo PIN generado: $nuevoPin!',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: _accentColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PIN: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Gestión de Mesas y Seguridad',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Tarjeta de Control del PIN
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_clock, size: 48, color: _accentColor),
                        const SizedBox(height: 12),
                        const Text(
                          'PIN de Verificación Activo (4 dígitos)',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<String>(
                          stream: _pinService.getPinStream(),
                          builder: (context, snapshot) {
                            final pin = snapshot.data ?? '----';
                            return Text(
                              pin,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8,
                                color: _accentColor,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _generarNuevoPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.refresh, color: Colors.black),
                          label: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Renovar PIN Ahora',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Encabezado de Cuentas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Cuentas Habilitadas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '25 Mesas',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // CUADRO INDEPENDIENTE CON SCROLL PROPIO
                Container(
                  height: 320, // Altura fija del recuadro
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: 25,
                        itemBuilder: (context, index) {
                          final numeroMesa = index + 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: const Color(0xFF131B33), // Tono ligeramente diferenciado
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _accentColor.withOpacity(0.15),
                                child: Text(
                                  '$numeroMesa',
                                  style: const TextStyle(
                                    color: _accentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Mesa $numeroMesa',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Usuario: mesa$numeroMesa | Clave: 123456',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              trailing: const Icon(
                                Icons.verified_user_outlined,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}