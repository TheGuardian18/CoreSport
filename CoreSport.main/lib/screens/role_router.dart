import 'package:flutter/material.dart';
import '../admin/admin_panel.dart';
import '../mesa/mesa_panel.dart';
import '../espectador/espectador_panel.dart';

class RoleRouter extends StatelessWidget {
  final String role;
  const RoleRouter({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case 'administrador':
        return const AdminPanel();
      case 'mesa':
        return MesaPanel(); // SIN 'const' aquí
      case 'espectador':
        return const EspectadorPanel();
      default:
        return const Scaffold(body: Center(child: Text('Rol desconocido')));
    }
  }
}