import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_account_service.dart';

class AdminManageAccountsScreen extends StatefulWidget {
  const AdminManageAccountsScreen({super.key});

  @override
  State<AdminManageAccountsScreen> createState() => _AdminManageAccountsScreenState();
}

class _AdminManageAccountsScreenState extends State<AdminManageAccountsScreen> {
  final AdminAccountService _accountService = AdminAccountService();

  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingFields = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadAdminCredentials();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Carga únicamente las credenciales del Administrador
  Future<void> _loadAdminCredentials() async {
    setState(() => _isLoadingFields = true);

    final query = await FirebaseFirestore.instance
        .collection('roleUsers')
        .where('role', isEqualTo: 'administrador')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      _usuarioController.text = data['usuario'] ?? '';
      _passwordController.text = data['password'] ?? '';
    }

    setState(() => _isLoadingFields = false);
  }

  // Actualiza el usuario y contraseña del Administrador
  Future<void> _updateAdminCredentials() async {
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text.trim();

    if (usuario.isEmpty || password.isEmpty) {
      setState(() => _message = 'Por favor completa todos los campos.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final success = await _accountService.updateCredentials(
        role: 'administrador',
        newUsuario: usuario,
        newPassword: password,
      );

      if (success) {
        setState(() => _message = '¡Credenciales de Administrador actualizadas con éxito! ✅');
      } else {
        setState(() => _message = 'Error: El usuario ya está en uso o no se encontró.');
      }
    } catch (e) {
      setState(() => _message = 'Error al actualizar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF00FF87);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Credenciales de Acceso (Administrador)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Modifica tu usuario y contraseña de acceso al panel de administración.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_isLoadingFields)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ))
                    else ...[
                      TextField(
                        controller: _usuarioController,
                        decoration: const InputDecoration(
                          labelText: 'Nuevo Usuario',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Nueva Contraseña',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    if (_message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _message!.contains('✅') 
                              ? Colors.green.withOpacity(0.2) 
                              : Colors.red.withOpacity(0.2),
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

                    ElevatedButton(
                      onPressed: _isLoading || _isLoadingFields ? null : _updateAdminCredentials,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Guardar Cambios',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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