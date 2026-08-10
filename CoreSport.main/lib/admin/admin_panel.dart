import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/session_service.dart';
import '../services/cloudinary_service.dart';
import '/screens/login_screen.dart';
import 'admin_canchas_screen.dart';
import 'admin_crear_cancha_screen.dart';
import 'admin_torneos_screen.dart';
import 'admin_gestion_mesas_screen.dart';
import 'admin_manage_accounts_screen.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;
  String _menuImageUrl = 'https://res.cloudinary.com/demo/image/upload/sample.jpg';
  bool _isUploadingImage = false;
  
  // Controlador de scroll explícito para evitar el error de Scrollbar en Flutter Web
  final ScrollController _scrollController = ScrollController();

  final List<Widget> _screens = [
    const AdminCanchasScreen(),          // 0: Administración de Canchas (Principal)
    const AdminCrearCanchaScreen(),      // 1: Crear Cancha
    const AdminTorneosScreen(),          // 2: Torneos
    const AdminGestionMesasScreen(),     // 3: Gestión de Mesas
    const AdminManageAccountsScreen(),   // 4: Gestión de Cuentas (Solo Admin)
  ];

  @override
  void initState() {
    super.initState();
    _cargarImagenMenuConfigurada();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarImagenMenuConfigurada() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('menu_banner').get();
      if (doc.exists && doc.data()?['imageUrl'] != null) {
        if (mounted) {
          setState(() {
            _menuImageUrl = doc.data()!['imageUrl'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _cambiarImagenMenu() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      final url = await CloudinaryService().uploadImage(
        pickedFile, 
        'menu_banner_admin_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      await FirebaseFirestore.instance.collection('configuracion').doc('menu_banner').set({
        'imageUrl': url,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _menuImageUrl = url;
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Imagen del menú actualizada con éxito! ✅'), 
            backgroundColor: Color(0xFF00FF87),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _handleLogout() async {
    await SessionService().clearSession();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF00FF87);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // --- CABECERA CON IMAGEN TIPO BANNER GRANDE ---
            SizedBox(
              height: 180,
              child: DrawerHeader(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Color(0xFF0B132B)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _isUploadingImage
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                            )
                          : Image.network(
                              _menuImageUrl,
                              fit: BoxFit.cover,
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: child,
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF131B33),
                                child: const Icon(Icons.sports_soccer, size: 50, color: accentColor),
                              ),
                            ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Gestor de Canchas',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit, size: 16, color: accentColor),
                                  tooltip: 'Cambiar imagen',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                  onPressed: _isUploadingImage ? null : _cambiarImagenMenu,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Panel de Control',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- Opciones del Menú con ScrollController asignado ---
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.sports_soccer, color: accentColor),
                    title: const Text('Administración de Canchas'),
                    selected: _selectedIndex == 0,
                    selectedColor: accentColor,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_box, color: accentColor),
                    title: const Text('Crear Cancha'),
                    selected: _selectedIndex == 1,
                    selectedColor: accentColor,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.emoji_events, color: accentColor),
                    title: const Text('Torneos'),
                    selected: _selectedIndex == 2,
                    selectedColor: accentColor,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.group, color: accentColor),
                    title: const Text('Gestión de Mesas'),
                    selected: _selectedIndex == 3,
                    selectedColor: accentColor,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts, color: accentColor),
                    title: const Text('Gestión de Cuentas'),
                    selected: _selectedIndex == 4,
                    selectedColor: accentColor,
                    onTap: () {
                      setState(() => _selectedIndex = 4);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
    );
  }
}