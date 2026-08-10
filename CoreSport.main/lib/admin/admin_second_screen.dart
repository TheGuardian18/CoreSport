import 'package:flutter/material.dart';

class AdminSecondScreen extends StatelessWidget {
  const AdminSecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          'Sección 2 del Administrador\n(pendiente de definir contenido)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}