import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cancha_service.dart';
import '../models/cancha.dart';
import 'admin_torneo_detalle_screen.dart';

class AdminTorneosScreen extends StatefulWidget {
  const AdminTorneosScreen({super.key});

  @override
  State<AdminTorneosScreen> createState() => _AdminTorneosScreenState();
}

class _AdminTorneosScreenState extends State<AdminTorneosScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Color _accentColor = Color(0xFF00FF87);

  int _currentStep = 0;
  bool _modoCreacion = false;

  final _nombreController = TextEditingController();
  final Map<String, TextEditingController> _equipoControllers = {};

  final Map<String, bool> _deportesSeleccionados = {
    'Fútbol': false,
    'Vóley': false,
    'Básquet': false,
    'Fútbol 11': false,
  };

  final Map<String, List<String>> _equiposPorDeporte = {
    'Fútbol': [],
    'Vóley': [],
    'Básquet': [],
    'Fútbol 11': [],
  };

  final Map<String, List<String>> _canchasSeleccionadasPorDeporte = {
    'Fútbol': [],
    'Vóley': [],
    'Básquet': [],
    'Fútbol 11': [],
  };

  String _modalidad = 'Todos contra Todos';
  bool _isSaving = false;

  final List<String> _modalidades = [
    'Todos contra Todos',
    'Grupos',
    'Eliminación Directa'
  ];

  @override
  void initState() {
    super.initState();
    for (var d in _deportesSeleccionados.keys) {
      _equipoControllers[d] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    for (var c in _equipoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetFormulario() {
    _nombreController.clear();
    for (var controller in _equipoControllers.values) {
      controller.clear();
    }
    _deportesSeleccionados.updateAll((key, value) => false);
    _equiposPorDeporte.updateAll((key, value) => []);
    _canchasSeleccionadasPorDeporte.updateAll((key, value) => []);
    _modalidad = 'Todos contra Todos';
    _currentStep = 0;
  }

  void _agregarEquipo(String deporte) {
    final controller = _equipoControllers[deporte];
    if (controller != null) {
      final nombre = controller.text.trim();
      if (nombre.isNotEmpty && !_equiposPorDeporte[deporte]!.contains(nombre)) {
        setState(() {
          _equiposPorDeporte[deporte]!.add(nombre);
          controller.clear();
        });
      }
    }
  }

  void _abrirSelectorCanchas(String deporte, List<Cancha> canchasDisponibles) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final canchasFiltradas = canchasDisponibles
                .where((c) =>
                    c.deporte.toLowerCase() == deporte.toLowerCase() ||
                    c.deporte == 'Todos')
                .toList();

            return AlertDialog(
              title: Text('Seleccionar Canchas para $deporte'),
              content: canchasFiltradas.isEmpty
                  ? const Text('No hay canchas registradas para este deporte.')
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        primary: false, // ✅ Evita Scrollbar
                        itemCount: canchasFiltradas.length,
                        itemBuilder: (context, idx) {
                          final cancha = canchasFiltradas[idx];
                          final isChecked =
                              _canchasSeleccionadasPorDeporte[deporte]!
                                  .contains(cancha.nombre);

                          return CheckboxListTile(
                            title: Text(cancha.nombre),
                            subtitle: Text('\$${cancha.precioPorHora}/hr'),
                            value: isChecked,
                            activeColor: _accentColor,
                            checkColor: Colors.black,
                            onChanged: (bool? val) {
                              setModalState(() {
                                setState(() {
                                  if (val == true) {
                                    _canchasSeleccionadasPorDeporte[deporte]!
                                        .add(cancha.nombre);
                                  } else {
                                    _canchasSeleccionadasPorDeporte[deporte]!
                                        .remove(cancha.nombre);
                                  }
                                });
                              });
                            },
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Aceptar',
                      style: TextStyle(color: _accentColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 📌 GENERADOR DE FIXTURE COMPLETO (SIEMPRE CREA FINAL Y SEMIS)
  Future<void> _guardarYGenerarFixture() async {
    setState(() => _isSaving = true);

    try {
      final deportesActivos = _deportesSeleccionados.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final torneoRef = await _db.collection('torneos').add({
        'nombre': _nombreController.text.trim(),
        'modalidad': _modalidad,
        'deportes': deportesActivos,
        'equiposPorDeporte': _equiposPorDeporte,
        'canchasPorDeporte': _canchasSeleccionadasPorDeporte,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final batch = _db.batch();
      final random = Random();

      for (var deporte in deportesActivos) {
        final equipos = List<String>.from(_equiposPorDeporte[deporte]!)
          ..shuffle(random);
        final canchasAsignadas =
            _canchasSeleccionadasPorDeporte[deporte] ?? [];

        String obtenerCanchaAsignada(int index) {
          if (canchasAsignadas.isEmpty) return 'Sin Cancha';
          return canchasAsignadas[index % canchasAsignadas.length];
        }

        int partidoCounter = 0;

        if (_modalidad == 'Todos contra Todos') {
          // ... (sin cambios)
          for (int i = 0; i < equipos.length; i++) {
            for (int j = i + 1; j < equipos.length; j++) {
              final partidoRef = _db.collection('partidos').doc();
              batch.set(partidoRef, {
                'torneoId': torneoRef.id,
                'equipoA': equipos[i],
                'equipoB': equipos[j],
                'puntosA': 0,
                'puntosB': 0,
                'estado': 'Pendiente',
                'deporte': deporte,
                'fase': 'Todos contra Todos',
                'grupo': 'Grupo Único',
                'cancha': obtenerCanchaAsignada(partidoCounter++),
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
        } else if (_modalidad == 'Grupos') {
          // ... (sin cambios)
          final int mitad = (equipos.length / 2).ceil();
          final grupoA = equipos.sublist(0, mitad);
          final grupoB = equipos.sublist(mitad);

          void armarPartidosGrupo(List<String> grupo, String nombreGrupo) {
            for (int i = 0; i < grupo.length; i++) {
              for (int j = i + 1; j < grupo.length; j++) {
                final partidoRef = _db.collection('partidos').doc();
                batch.set(partidoRef, {
                  'torneoId': torneoRef.id,
                  'equipoA': grupo[i],
                  'equipoB': grupo[j],
                  'puntosA': 0,
                  'puntosB': 0,
                  'estado': 'Pendiente',
                  'deporte': deporte,
                  'fase': 'Grupos',
                  'grupo': nombreGrupo,
                  'cancha': obtenerCanchaAsignada(partidoCounter++),
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }

          armarPartidosGrupo(grupoA, 'Grupo A');
          armarPartidosGrupo(grupoB, 'Grupo B');
        } else {
          // 🟢 ELIMINACIÓN DIRECTA (SIEMPRE genera Semis y Final)
          final int totalEquipos = equipos.length;

          // Fase inicial: Octavos / Cuartos / Semifinal según cantidad
          String faseInicial = 'Cuartos';
          if (totalEquipos > 8) {
            faseInicial = 'Octavos';
          } else if (totalEquipos <= 4) {
            faseInicial = 'Semifinal';
          }

          // 1. Partidos de la fase inicial (si hay más de 4)
          if (totalEquipos > 4) {
            for (int i = 0; i < equipos.length; i += 2) {
              if (i + 1 < equipos.length) {
                final pRef = _db.collection('partidos').doc();
                batch.set(pRef, {
                  'torneoId': torneoRef.id,
                  'deporte': deporte,
                  'fase': faseInicial,
                  'equipoA': equipos[i],
                  'equipoB': equipos[i + 1],
                  'puntosA': 0,
                  'puntosB': 0,
                  'estado': 'Pendiente',
                  'cancha': obtenerCanchaAsignada(partidoCounter++),
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }

          // 2. Cuartos (si hay más de 8)
          if (totalEquipos > 8) {
            for (int i = 0; i < 4; i++) {
              final pRef = _db.collection('partidos').doc();
              batch.set(pRef, {
                'torneoId': torneoRef.id,
                'deporte': deporte,
                'fase': 'Cuartos',
                'equipoA': 'Por definir',
                'equipoB': 'Por definir',
                'puntosA': 0,
                'puntosB': 0,
                'estado': 'Pendiente',
                'cancha': obtenerCanchaAsignada(partidoCounter++),
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }

          // 3. SEMIFINALES (SIEMPRE 2 partidos)
          for (int i = 0; i < 2; i++) {
            final pRef = _db.collection('partidos').doc();
            batch.set(pRef, {
              'torneoId': torneoRef.id,
              'deporte': deporte,
              'fase': 'Semifinal',
              'equipoA': totalEquipos <= 4 && i < equipos.length
                  ? equipos[i * 2]
                  : 'Por definir',
              'equipoB': totalEquipos <= 4 && i < equipos.length && (i * 2 + 1) < equipos.length
                  ? equipos[i * 2 + 1]
                  : 'Por definir',
              'puntosA': 0,
              'puntosB': 0,
              'estado': 'Pendiente',
              'cancha': obtenerCanchaAsignada(partidoCounter++),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          // 4. GRAN FINAL (SIEMPRE)
          final finalRef = _db.collection('partidos').doc();
          batch.set(finalRef, {
            'torneoId': torneoRef.id,
            'deporte': deporte,
            'fase': 'Final',
            'equipoA': totalEquipos == 2 ? equipos[0] : 'Por definir',
            'equipoB': totalEquipos == 2 ? equipos[1] : 'Por definir',
            'puntosA': 0,
            'puntosB': 0,
            'estado': 'Pendiente',
            'cancha': obtenerCanchaAsignada(partidoCounter++),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _modoCreacion = false;
        _resetFormulario();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Torneo y fixture generados con éxito!'),
          backgroundColor: _accentColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        primary: false, // ✅ Evita Scrollbar automático
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _modoCreacion
                          ? 'Crear Nuevo Torneo (Etapas)'
                          : 'Gestión de Torneos',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (!_modoCreacion) {
                            _resetFormulario();
                          }
                          _modoCreacion = !_modoCreacion;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.black,
                      ),
                      icon: Icon(_modoCreacion ? Icons.list : Icons.add,
                          color: Colors.black),
                      label: Text(
                        _modoCreacion ? 'Ver Torneos Activos' : 'Nuevo Torneo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_modoCreacion)
                  Stepper(
                    currentStep: _currentStep,
                    onStepContinue: () {
                      if (_currentStep == 0) {
                        if (_nombreController.text.trim().isEmpty) return;
                        final activos = _deportesSeleccionados.values
                            .where((v) => v)
                            .length;
                        if (activos == 0) return;
                      } else if (_currentStep == 1) {
                        final deportesActivos = _deportesSeleccionados.entries
                            .where((e) => e.value)
                            .map((e) => e.key);
                        for (var d in deportesActivos) {
                          if (_equiposPorDeporte[d]!.length < 2) return;
                        }
                      }

                      if (_currentStep < 2) {
                        setState(() => _currentStep += 1);
                      } else {
                        _guardarYGenerarFixture();
                      }
                    },
                    onStepCancel: () {
                      if (_currentStep > 0) setState(() => _currentStep -= 1);
                    },
                    steps: [
                      Step(
                        title: const Text('1. Nombre y Deportes'),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0
                            ? StepState.complete
                            : StepState.editing,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nombreController,
                              decoration: const InputDecoration(
                                  labelText: 'Nombre del Torneo'),
                            ),
                            const SizedBox(height: 16),
                            const Text('Selecciona Deporte(s):',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: _deportesSeleccionados.keys.map((d) {
                                return FilterChip(
                                  label: Text(d),
                                  selected: _deportesSeleccionados[d]!,
                                  selectedColor: _accentColor.withOpacity(0.3),
                                  onSelected: (val) => setState(
                                      () => _deportesSeleccionados[d] = val),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('2. Registrar Equipos'),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1
                            ? StepState.complete
                            : StepState.editing,
                        content: Column(
                          children: _deportesSeleccionados.entries
                              .where((e) => e.value)
                              .map((entry) {
                            final deporte = entry.key;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Equipos para $deporte',
                                        style: const TextStyle(
                                            color: _accentColor,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                _equipoControllers[deporte],
                                            decoration: const InputDecoration(
                                                labelText:
                                                    'Nombre del Equipo'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle,
                                              color: _accentColor, size: 36),
                                          onPressed: () =>
                                              _agregarEquipo(deporte),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 60,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        primary: false, // ✅ Evita Scrollbar
                                        itemCount:
                                            _equiposPorDeporte[deporte]!.length,
                                        itemBuilder: (context, idx) {
                                          final eq =
                                              _equiposPorDeporte[deporte]![idx];
                                          return Container(
                                            margin:
                                                const EdgeInsets.only(right: 10),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF131B33),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: _accentColor
                                                      .withOpacity(0.5)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(eq,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                    onTap: () => setState(() =>
                                                        _equiposPorDeporte[
                                                                deporte]!
                                                            .remove(eq)),
                                                    child: const Icon(
                                                        Icons.close,
                                                        size: 18,
                                                        color: Colors.redAccent)),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Step(
                        title: const Text(
                            '3. Modalidad y Asignación de Canchas'),
                        isActive: _currentStep >= 2,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _modalidad,
                              decoration: const InputDecoration(
                                  labelText: 'Modalidad del Torneo'),
                              items: _modalidades
                                  .map((m) => DropdownMenuItem(
                                      value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _modalidad = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            StreamBuilder<List<Cancha>>(
                              stream: CanchaService().getCanchasStream(),
                              builder: (context, snapshot) {
                                final canchas = snapshot.data ?? [];
                                return Column(
                                  children: _deportesSeleccionados.entries
                                      .where((e) => e.value)
                                      .map((entry) {
                                    final deporte = entry.key;
                                    final seleccionadas =
                                        _canchasSeleccionadasPorDeporte[
                                                deporte] ??
                                            [];

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        title: Text('Canchas para $deporte'),
                                        subtitle: Text(
                                          seleccionadas.isEmpty
                                              ? 'Toca para seleccionar canchas'
                                              : 'Seleccionadas: ${seleccionadas.join(", ")}',
                                          style: TextStyle(
                                            color: seleccionadas.isEmpty
                                                ? Colors.grey
                                                : _accentColor,
                                          ),
                                        ),
                                        trailing: const Icon(
                                            Icons.checklist,
                                            color: _accentColor),
                                        onTap: () => _abrirSelectorCanchas(
                                            deporte, canchas),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('torneos')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                            child: Text('No hay torneos registrados',
                                style: TextStyle(color: Colors.grey)));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        primary: false, // ✅ Evita Scrollbar
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final torneoId = docs[index].id;
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final deportes =
                              List<dynamic>.from(data['deportes'] ?? []);
                          final canchasMap = Map<String, dynamic>.from(
                              data['canchasPorDeporte'] ?? {});

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.emoji_events,
                                      color: _accentColor)),
                              title: Text(data['nombre'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              subtitle: Text(
                                  'Modalidad: ${data['modalidad']} • Deportes: ${deportes.join(", ")}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios,
                                        color: _accentColor, size: 20),
                                    tooltip: 'Ver Fixture y Llaves por Deporte',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AdminTorneoDetalleScreen(
                                            torneoId: torneoId,
                                            nombreTorneo: data['nombre'] ?? '',
                                            modalidad: data['modalidad'] ??
                                                'Todos contra Todos',
                                            deportes: deportes,
                                            canchasPorDeporte: canchasMap,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.redAccent),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Eliminar Torneo'),
                                          content: const Text(
                                              '¿Deseas eliminar este torneo y todos sus datos asociados?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Eliminar',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        final batch = _db.batch();

                                        final partidosQuery = await _db
                                            .collection('partidos')
                                            .where('torneoId',
                                                isEqualTo: torneoId)
                                            .get();
                                        for (var doc in partidosQuery.docs) {
                                          batch.delete(doc.reference);
                                        }

                                        final plantillasQuery = await _db
                                            .collection('plantillas_equipos')
                                            .where('torneoId',
                                                isEqualTo: torneoId)
                                            .get();
                                        for (var doc in plantillasQuery.docs) {
                                          batch.delete(doc.reference);
                                        }

                                        final incidenciasQuery = await _db
                                            .collection('incidencias')
                                            .where('torneoId',
                                                isEqualTo: torneoId)
                                            .get();
                                        for (var doc in incidenciasQuery.docs) {
                                          batch.delete(doc.reference);
                                        }

                                        batch.delete(_db
                                            .collection('torneos')
                                            .doc(torneoId));

                                        await batch.commit();

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Torneo eliminado correctamente.'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}