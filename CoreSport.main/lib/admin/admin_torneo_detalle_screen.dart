import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTorneoDetalleScreen extends StatefulWidget {
  final String torneoId;
  final String nombreTorneo;
  final String modalidad;
  final List<dynamic> deportes;
  final Map<String, dynamic> canchasPorDeporte;

  const AdminTorneoDetalleScreen({
    super.key,
    required this.torneoId,
    required this.nombreTorneo,
    required this.modalidad,
    required this.deportes,
    required this.canchasPorDeporte,
  });

  @override
  State<AdminTorneoDetalleScreen> createState() =>
      _AdminTorneoDetalleScreenState();
}

class _AdminTorneoDetalleScreenState extends State<AdminTorneoDetalleScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Color _accentColor = Color(0xFF00FF87);

  // ==================== UTILIDADES ====================
  String _obtenerCanchaRotativa(String deporte, int index) {
    final rawList = widget.canchasPorDeporte[deporte];
    List<String> canchas = [];
    if (rawList is List) {
      canchas = rawList.map((e) => e.toString()).toList();
    }
    if (canchas.isEmpty) return 'Sin Cancha';
    return canchas[index % canchas.length];
  }

  // ==================== GENERAR / REHACER FIXTURE ====================
  Future<void> _rehacerFixtureAlAzar(String deporte) async {
    final torneoDoc =
        await _db.collection('torneos').doc(widget.torneoId).get();
    if (!torneoDoc.exists) return;

    final data = torneoDoc.data() as Map<String, dynamic>;
    final equiposPorDeporte =
        Map<String, dynamic>.from(data['equiposPorDeporte'] ?? {});
    List<String> equipos =
        List<String>.from(equiposPorDeporte[deporte] ?? []);

    if (equipos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Se necesitan al menos 2 equipos para hacer el fixture.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    equipos.shuffle(Random());

    final batch = _db.batch();
    final partidosQuery = await _db
        .collection('partidos')
        .where('torneoId', isEqualTo: widget.torneoId)
        .where('deporte', isEqualTo: deporte)
        .get();

    for (var doc in partidosQuery.docs) {
      batch.delete(doc.reference);
    }

    int partidoCounter = 0;
    final int totalEquipos = equipos.length;

    // ---- ELIMINACIÓN DIRECTA ----
    if (widget.modalidad == 'Eliminación Directa') {
      String faseInicial = 'Cuartos';
      if (totalEquipos > 8) {
        faseInicial = 'Octavos';
      } else if (totalEquipos <= 4) {
        faseInicial = 'Semifinal';
      }

      if (totalEquipos > 4) {
        for (int i = 0; i < equipos.length; i += 2) {
          if (i + 1 < equipos.length) {
            final pRef = _db.collection('partidos').doc();
            batch.set(pRef, {
              'torneoId': widget.torneoId,
              'deporte': deporte,
              'fase': faseInicial,
              'equipoA': equipos[i],
              'equipoB': equipos[i + 1],
              'puntosA': 0,
              'puntosB': 0,
              'estado': 'Pendiente',
              'cancha': _obtenerCanchaRotativa(deporte, partidoCounter++),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (totalEquipos > 8) {
        for (int i = 0; i < 4; i++) {
          final pRef = _db.collection('partidos').doc();
          batch.set(pRef, {
            'torneoId': widget.torneoId,
            'deporte': deporte,
            'fase': 'Cuartos',
            'equipoA': 'Por definir',
            'equipoB': 'Por definir',
            'puntosA': 0,
            'puntosB': 0,
            'estado': 'Pendiente',
            'cancha': _obtenerCanchaRotativa(deporte, partidoCounter++),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      for (int i = 0; i < 2; i++) {
        final pRef = _db.collection('partidos').doc();
        batch.set(pRef, {
          'torneoId': widget.torneoId,
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
          'cancha': _obtenerCanchaRotativa(deporte, partidoCounter++),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final finalRef = _db.collection('partidos').doc();
      batch.set(finalRef, {
        'torneoId': widget.torneoId,
        'deporte': deporte,
        'fase': 'Final',
        'equipoA': totalEquipos == 2 ? equipos[0] : 'Por definir',
        'equipoB': totalEquipos == 2 ? equipos[1] : 'Por definir',
        'puntosA': 0,
        'puntosB': 0,
        'estado': 'Pendiente',
        'cancha': _obtenerCanchaRotativa(deporte, partidoCounter++),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ---- MODALIDAD GRUPOS ----
    else if (widget.modalidad == 'Grupos') {
      final int mitad = (equipos.length / 2).ceil();
      final grupoA = equipos.sublist(0, mitad);
      final grupoB = equipos.sublist(mitad);

      void armarPartidosGrupo(List<String> grupo, String nombreGrupo) {
        for (int i = 0; i < grupo.length; i++) {
          for (int j = i + 1; j < grupo.length; j++) {
            final partidoRef = _db.collection('partidos').doc();
            batch.set(partidoRef, {
              'torneoId': widget.torneoId,
              'equipoA': grupo[i],
              'equipoB': grupo[j],
              'puntosA': 0,
              'puntosB': 0,
              'estado': 'Pendiente',
              'deporte': deporte,
              'fase': 'Grupos',
              'grupo': nombreGrupo,
              'cancha': _obtenerCanchaRotativa(deporte, partidoCounter++),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      armarPartidosGrupo(grupoA, 'Grupo A');
      armarPartidosGrupo(grupoB, 'Grupo B');
    }

    // ---- TODOS CONTRA TODOS ----
    else if (widget.modalidad == 'Todos contra Todos') {
      for (int i = 0; i < equipos.length; i++) {
        for (int j = i + 1; j < equipos.length; j++) {
          final partidoRef = _db.collection('partidos').doc();
          batch.set(partidoRef, {
            'torneoId': widget.torneoId,
            'deporte': deporte,
            'fase': 'Todos contra Todos',
            'grupo': 'Grupo Único',
            'equipoA': equipos[i],
            'equipoB': equipos[j],
            'puntosA': 0,
            'puntosB': 0,
            'estado': 'Pendiente',
            'cancha': _obtenerCanchaRotativa(deporte, partidoCounter++),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Fixture completo generado al azar con éxito! 🎲'),
        backgroundColor: _accentColor,
      ),
    );
  }

  // ==================== GENERAR ELIMINATORIA DESDE GRUPOS ====================
  Future<void> _generarEliminatoriaDesdeGrupos(
      String deporte, List<String> clasificados) async {
    if (clasificados.length < 4) return;

    int partidoIdx = 0;
    final batch = _db.batch();

    final sem1 = _db.collection('partidos').doc();
    batch.set(sem1, {
      'torneoId': widget.torneoId,
      'equipoA': clasificados[0],
      'equipoB': clasificados[3],
      'puntosA': 0,
      'puntosB': 0,
      'estado': 'Pendiente',
      'deporte': deporte,
      'fase': 'Semifinal',
      'cancha': _obtenerCanchaRotativa(deporte, partidoIdx++),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final sem2 = _db.collection('partidos').doc();
    batch.set(sem2, {
      'torneoId': widget.torneoId,
      'equipoA': clasificados[1],
      'equipoB': clasificados[2],
      'puntosA': 0,
      'puntosB': 0,
      'estado': 'Pendiente',
      'deporte': deporte,
      'fase': 'Semifinal',
      'cancha': _obtenerCanchaRotativa(deporte, partidoIdx++),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final fin = _db.collection('partidos').doc();
    batch.set(fin, {
      'torneoId': widget.torneoId,
      'equipoA': 'Por definir',
      'equipoB': 'Por definir',
      'puntosA': 0,
      'puntosB': 0,
      'estado': 'Pendiente',
      'deporte': deporte,
      'fase': 'Final',
      'cancha': _obtenerCanchaRotativa(deporte, partidoIdx++),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Fase eliminatoria generada con canchas heredadas! ✅'),
        backgroundColor: _accentColor,
      ),
    );
  }

  // ==================== GENERAR DESEMPATE (TODOS CONTRA TODOS) ====================
  Future<void> _generarDesempate(String deporte, List<String> equiposEmpatados) async {
    if (equiposEmpatados.length < 2) return;

    // Verificar si ya existen partidos de desempate para este deporte
    final existingQuery = await _db
        .collection('partidos')
        .where('torneoId', isEqualTo: widget.torneoId)
        .where('deporte', isEqualTo: deporte)
        .where('fase', isEqualTo: 'Desempate')
        .get();

    if (existingQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existen partidos de desempate para este deporte.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final batch = _db.batch();
    int partidoCounter = 0;

    // Generar todos contra todos entre los empatados
    for (int i = 0; i < equiposEmpatados.length; i++) {
      for (int j = i + 1; j < equiposEmpatados.length; j++) {
        final partidoRef = _db.collection('partidos').doc();
        batch.set(partidoRef, {
          'torneoId': widget.torneoId,
          'deporte': deporte,
          'fase': 'Desempate',
          'equipoA': equiposEmpatados[i],
          'equipoB': equiposEmpatados[j],
          'puntosA': 0,
          'puntosB': 0,
          'estado': 'Pendiente',
          'cancha': _obtenerCanchaRotativa(deporte, partidoCounter++),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡${equiposEmpatados.length} partidos de desempate generados!'),
        backgroundColor: _accentColor,
      ),
    );
  }

  // ==================== DETECTAR EMPATE EN PRIMER LUGAR ====================
  List<String> _detectarEmpatePrimerLugar(List<QueryDocumentSnapshot> partidos) {
    final Map<String, int> tablaPuntos = {};

    for (var doc in partidos) {
      final p = doc.data() as Map<String, dynamic>;
      final eqA = p['equipoA'] ?? '';
      final eqB = p['equipoB'] ?? '';
      final ptsA = (p['puntosA'] ?? 0) as int;
      final ptsB = (p['puntosB'] ?? 0) as int;

      tablaPuntos.putIfAbsent(eqA, () => 0);
      tablaPuntos.putIfAbsent(eqB, () => 0);

      if (p['estado'] == 'Finalizado') {
        if (ptsA > ptsB) {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 3;
        } else if (ptsB > ptsA) {
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 3;
        } else {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 1;
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 1;
        }
      }
    }

    if (tablaPuntos.isEmpty) return [];

    // Ordenar por puntos descendente
    final ordenados = tablaPuntos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Obtener el puntaje del primer lugar
    final int maxPuntos = ordenados.first.value;

    // Filtrar todos los equipos con ese puntaje
    final empatados = ordenados
        .where((entry) => entry.value == maxPuntos)
        .map((entry) => entry.key)
        .toList();

    // Si hay más de 1, hay empate
    return empatados.length > 1 ? empatados : [];
  }

  // ==================== BUILD PRINCIPAL ====================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: widget.deportes.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.nombreTorneo),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: _accentColor,
            labelColor: _accentColor,
            unselectedLabelColor: Colors.grey,
            tabs: widget.deportes
                .map((d) => Tab(
                      icon: Icon(_getDeporteIcon(d.toString())),
                      text: d.toString(),
                    ))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: widget.deportes.map((deporteObj) {
            final deporte = deporteObj.toString();

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deporte: $deporte',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Modalidad: ${widget.modalidad}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _rehacerFixtureAlAzar(deporte),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black),
                            icon: const Icon(Icons.shuffle, size: 18),
                            label: const Text('Rehacer Fixture al Azar',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('partidos')
                          .where('torneoId', isEqualTo: widget.torneoId)
                          .where('deporte', isEqualTo: deporte)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'No hay partidos generados para este deporte.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _rehacerFixtureAlAzar(deporte),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: _accentColor,
                                      foregroundColor: Colors.black),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Generar Fixture Inicial',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }

                        if (widget.modalidad == 'Eliminación Directa') {
                          return SingleChildScrollView(
                            primary: false,
                            child: _buildBracketCompletoDinamico(docs, deporte),
                          );
                        }

                        if (widget.modalidad == 'Grupos') {
                          return SingleChildScrollView(
                            primary: false,
                            child: _buildGruposView(deporte, docs),
                          );
                        }

                        // TODOS CONTRA TODOS
                        return SingleChildScrollView(
                          primary: false,
                          child: _buildTodosContraTodosView(deporte, docs),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================== ICONOS POR DEPORTE ====================
  IconData _getDeporteIcon(String deporte) {
    switch (deporte) {
      case 'Fútbol':
      case 'Fútbol 11':
        return Icons.sports_soccer;
      case 'Vóley':
        return Icons.sports_volleyball;
      case 'Básquet':
        return Icons.sports_basketball;
      default:
        return Icons.sports;
    }
  }

  // ==================== VISTA DE GRUPOS ====================
  Widget _buildGruposView(String deporte, List<QueryDocumentSnapshot> docs) {
    final docsGrupoA = docs
        .where((d) => (d.data() as Map)['grupo'] == 'Grupo A')
        .toList();
    final docsGrupoB = docs
        .where((d) => (d.data() as Map)['grupo'] == 'Grupo B')
        .toList();
    final docsEliminatoria = docs
        .where((d) =>
            (d.data() as Map)['fase'] == 'Semifinal' ||
            (d.data() as Map)['fase'] == 'Final')
        .toList();

    final grupoAFinalizado =
        docsGrupoA.every((d) => (d.data() as Map)['estado'] == 'Finalizado');
    final grupoBFinalizado =
        docsGrupoB.every((d) => (d.data() as Map)['estado'] == 'Finalizado');
    final todosGruposFinalizados =
        grupoAFinalizado && grupoBFinalizado && docsGrupoA.isNotEmpty && docsGrupoB.isNotEmpty;

    final clasificadosA = _obtenerClasificadosGrupo(docsGrupoA);
    final clasificadosB = _obtenerClasificadosGrupo(docsGrupoB);
    final todosClasificados = [...clasificadosA, ...clasificadosB];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSeccionGrupoCompleta('GRUPO A', docsGrupoA),
        const SizedBox(height: 24),
        _buildSeccionGrupoCompleta('GRUPO B', docsGrupoB),
        const SizedBox(height: 24),

        if (docsEliminatoria.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: todosGruposFinalizados ? _accentColor : Colors.grey),
            ),
            child: Column(
              children: [
                Text(
                  todosGruposFinalizados
                      ? '¡Todos los partidos de grupos han concluido! Ya puedes generar la fase eliminatoria.'
                      : 'El botón para pasar a Eliminación Directa se activará cuando concluyan todos los partidos de los grupos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: todosGruposFinalizados ? _accentColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: todosGruposFinalizados
                      ? () =>
                          _generarEliminatoriaDesdeGrupos(deporte, todosClasificados)
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor, foregroundColor: Colors.black),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Generar Fase Eliminatoria (2 Mejores)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ] else ...[
          const Divider(height: 30),
          const Text(
            '— FASE FINAL (ELIMINACIÓN DIRECTA) —',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildBracketCompletoDinamico(docsEliminatoria, deporte),
        ],
      ],
    );
  }

  // ==================== VISTA TODOS CONTRA TODOS (CON DESEMPATE) ====================
  Widget _buildTodosContraTodosView(String deporte, List<QueryDocumentSnapshot> docs) {
    // Separar partidos de liga y de desempate
    final partidosLiga = docs.where((d) {
      final fase = (d.data() as Map)['fase'] ?? '';
      return fase != 'Desempate';
    }).toList();

    final partidosDesempate = docs.where((d) {
      final fase = (d.data() as Map)['fase'] ?? '';
      return fase == 'Desempate';
    }).toList();

    // Verificar si todos los partidos de liga están finalizados
    final todosFinalizados = partidosLiga.isNotEmpty &&
        partidosLiga.every((d) {
          final estado = (d.data() as Map)['estado'] ?? 'Pendiente';
          return estado == 'Finalizado';
        });

    // Detectar empate en el primer lugar
    List<String> empatados = [];
    if (todosFinalizados) {
      empatados = _detectarEmpatePrimerLugar(partidosLiga);
    }

    // Verificar si ya hay partidos de desempate
    final hayDesempate = partidosDesempate.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TABLA Y ENFRENTAMIENTOS DE LIGA
        _buildSeccionGrupoCompleta('Tabla General - Todos contra Todos', partidosLiga),

        const SizedBox(height: 16),

        // ---- SECCIÓN DE DESEMPATE ----
        if (todosFinalizados && empatados.isNotEmpty && !hayDesempate) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 32),
                const SizedBox(height: 8),
                Text(
                  '⚠️ ¡EMPATE EN EL PRIMER LUGAR!',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los siguientes equipos están empatados: ${empatados.join(", ")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _generarDesempate(deporte, empatados),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.sports_score),
                  label: const Text(
                    'GENERAR PARTIDOS DE DESEMPATE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // MOSTRAR PARTIDOS DE DESEMPATE SI EXISTEN
        if (hayDesempate) ...[
          const Divider(height: 30),
          const Text(
            '— PARTIDOS DE DESEMPATE —',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildSeccionGrupoCompleta('Desempate', partidosDesempate),

          // Mostrar ganador del desempate (si todos los partidos de desempate están finalizados)
          if (partidosDesempate.isNotEmpty &&
              partidosDesempate.every((d) {
                final estado = (d.data() as Map)['estado'] ?? 'Pendiente';
                return estado == 'Finalizado';
              })) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.green, size: 36),
                  const SizedBox(height: 4),
                  Text(
                    '🏆 GANADOR DEL TORNEO',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _obtenerGanadorDesempate(partidosDesempate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ==================== OBTENER GANADOR DE DESEMPATE ====================
  String _obtenerGanadorDesempate(List<QueryDocumentSnapshot> partidosDesempate) {
    final Map<String, int> tablaPuntos = {};

    for (var doc in partidosDesempate) {
      final p = doc.data() as Map<String, dynamic>;
      final eqA = p['equipoA'] ?? '';
      final eqB = p['equipoB'] ?? '';
      final ptsA = (p['puntosA'] ?? 0) as int;
      final ptsB = (p['puntosB'] ?? 0) as int;

      tablaPuntos.putIfAbsent(eqA, () => 0);
      tablaPuntos.putIfAbsent(eqB, () => 0);

      if (p['estado'] == 'Finalizado') {
        if (ptsA > ptsB) {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 3;
        } else if (ptsB > ptsA) {
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 3;
        } else {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 1;
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 1;
        }
      }
    }

    if (tablaPuntos.isEmpty) return 'Sin definir';

    final ordenados = tablaPuntos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ordenados.first.key;
  }

  // ==================== SECCIÓN DE GRUPO (tabla + partidos) ====================
  Widget _buildSeccionGrupoCompleta(
      String titulo, List<QueryDocumentSnapshot> partidosDocs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _accentColor),
            ),
            const Divider(height: 16),
            const Text(
              'Tabla de Posiciones:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildTablaPosicionesCalculada(partidosDocs),
            const Divider(height: 20),
            const Text(
              'Enfrentamientos:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              primary: false,
              itemCount: partidosDocs.length,
              itemBuilder: (context, idx) {
                final pData = partidosDocs[idx].data() as Map<String, dynamic>;
                final bool finalizado = pData['estado'] == 'Finalizado';

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B33),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${pData['equipoA']} vs ${pData['equipoB']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Cancha: ${pData['cancha'] ?? "Sin Cancha"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        finalizado
                            ? '${pData['puntosA']} - ${pData['puntosB']}'
                            : 'Pendiente',
                        style: TextStyle(
                            color: finalizado ? Colors.greenAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TABLA DE POSICIONES ====================
  Widget _buildTablaPosicionesCalculada(List<QueryDocumentSnapshot> partidosDocs) {
    final Map<String, int> tablaPuntos = {};

    for (var doc in partidosDocs) {
      final p = doc.data() as Map<String, dynamic>;
      final eqA = p['equipoA'] ?? '';
      final eqB = p['equipoB'] ?? '';
      final ptsA = (p['puntosA'] ?? 0) as int;
      final ptsB = (p['puntosB'] ?? 0) as int;

      tablaPuntos.putIfAbsent(eqA, () => 0);
      tablaPuntos.putIfAbsent(eqB, () => 0);

      if (p['estado'] == 'Finalizado') {
        if (ptsA > ptsB) {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 3;
        } else if (ptsB > ptsA) {
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 3;
        } else {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 1;
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 1;
        }
      }
    }

    final ordenados = tablaPuntos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      primary: false,
      itemCount: ordenados.length,
      itemBuilder: (context, idx) {
        final item = ordenados[idx];
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${idx + 1}. ${item.key}'),
            Text(
              '${item.value} PTS',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _accentColor),
            ),
          ],
        );
      },
    );
  }

  // ==================== CLASIFICADOS DE GRUPO ====================
  List<String> _obtenerClasificadosGrupo(List<QueryDocumentSnapshot> partidos) {
    final Map<String, int> tablaPuntos = {};
    for (var doc in partidos) {
      final p = doc.data() as Map<String, dynamic>;
      final eqA = p['equipoA'] ?? '';
      final eqB = p['equipoB'] ?? '';
      final ptsA = (p['puntosA'] ?? 0) as int;
      final ptsB = (p['puntosB'] ?? 0) as int;

      tablaPuntos.putIfAbsent(eqA, () => 0);
      tablaPuntos.putIfAbsent(eqB, () => 0);

      if (p['estado'] == 'Finalizado') {
        if (ptsA > ptsB) {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 3;
        } else if (ptsB > ptsA) {
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 3;
        } else {
          tablaPuntos[eqA] = tablaPuntos[eqA]! + 1;
          tablaPuntos[eqB] = tablaPuntos[eqB]! + 1;
        }
      }
    }
    final ordenados = tablaPuntos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordenados.take(2).map((e) => e.key).toList();
  }

  // ==================== BRACKET COMPLETO (TODAS LAS FASES) ====================
  Widget _buildBracketCompletoDinamico(
      List<QueryDocumentSnapshot> docs, String deporte) {
    final octavos = docs
        .where((d) => (d.data() as Map)['fase'] == 'Octavos')
        .toList();
    final cuartos = docs
        .where((d) => (d.data() as Map)['fase'] == 'Cuartos')
        .toList();
    final semifinales = docs
        .where((d) => (d.data() as Map)['fase'] == 'Semifinal')
        .toList();
    final finalPartidos = docs
        .where((d) => (d.data() as Map)['fase'] == 'Final')
        .toList();

    String ganador = 'GANADOR DEL TORNEO';
    String? ganadorPenales;
    bool finalFinalizada = false;

    if (finalPartidos.isNotEmpty) {
      final fData = finalPartidos.first.data() as Map;
      final estado = fData['estado'] ?? 'Pendiente';
      if (estado == 'Finalizado') {
        finalFinalizada = true;
        final pA = fData['puntosA'] as int;
        final pB = fData['puntosB'] as int;
        if (pA > pB) {
          ganador = fData['equipoA'] ?? 'GANADOR DEL TORNEO';
        } else if (pB > pA) {
          ganador = fData['equipoB'] ?? 'GANADOR DEL TORNEO';
        } else {
          final penales = fData['ganadorPenales'];
          if (penales != null && penales.toString().isNotEmpty) {
            ganador = penales.toString();
            ganadorPenales = penales;
          } else {
            ganador = 'Por definir (penales pendientes)';
          }
        }
      } else {
        final pA = fData['puntosA'] as int;
        final pB = fData['puntosB'] as int;
        if (pA == pB && pA > 0) {
          ganador = 'Por definir (penales pendientes)';
        } else {
          ganador = 'En juego...';
        }
      }
    }

    return Column(
      children: [
        if (octavos.isNotEmpty) ...[
          const Text(
            '— OCTAVOS DE FINAL —',
            style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: octavos.asMap().entries.map((entry) {
              final idx = entry.key;
              final doc = entry.value;
              final pData = doc.data() as Map<String, dynamic>;
              String canchaPartido = pData['cancha'] ?? '';
              if (canchaPartido.isEmpty ||
                  canchaPartido == 'Por asignar' ||
                  canchaPartido == 'Sin Cancha') {
                canchaPartido = _obtenerCanchaRotativa(deporte, idx);
              }
              return _buildTarjetaPartidoBracket(
                pData['equipoA'] ?? 'Por definir',
                pData['equipoB'] ?? 'Por definir',
                pData['puntosA'] ?? 0,
                pData['puntosB'] ?? 0,
                canchaPartido,
                pData['estado'] == 'Finalizado',
                ganadorPenales: pData['ganadorPenales'],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.arrow_downward, color: _accentColor, size: 28),
          const SizedBox(height: 16),
        ],

        if (cuartos.isNotEmpty) ...[
          const Text(
            '— CUARTOS DE FINAL —',
            style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: cuartos.asMap().entries.map((entry) {
              final idx = entry.key;
              final doc = entry.value;
              final pData = doc.data() as Map<String, dynamic>;
              String canchaPartido = pData['cancha'] ?? '';
              if (canchaPartido.isEmpty ||
                  canchaPartido == 'Por asignar' ||
                  canchaPartido == 'Sin Cancha') {
                canchaPartido =
                    _obtenerCanchaRotativa(deporte, octavos.length + idx);
              }
              return _buildTarjetaPartidoBracket(
                pData['equipoA'] ?? 'Por definir',
                pData['equipoB'] ?? 'Por definir',
                pData['puntosA'] ?? 0,
                pData['puntosB'] ?? 0,
                canchaPartido,
                pData['estado'] == 'Finalizado',
                ganadorPenales: pData['ganadorPenales'],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.arrow_downward, color: _accentColor, size: 28),
          const SizedBox(height: 16),
        ],

        const Text(
          '— SEMIFINALES —',
          style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: semifinales.isEmpty
              ? [
                  _buildTarjetaPartidoBracket(
                    'Por definir',
                    'Por definir',
                    0,
                    0,
                    _obtenerCanchaRotativa(deporte, 0),
                    false,
                  ),
                  _buildTarjetaPartidoBracket(
                    'Por definir',
                    'Por definir',
                    0,
                    0,
                    _obtenerCanchaRotativa(deporte, 1),
                    false,
                  ),
                ]
              : semifinales.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final doc = entry.value;
                  final pData = doc.data() as Map<String, dynamic>;
                  String canchaPartido = pData['cancha'] ?? '';
                  if (canchaPartido.isEmpty ||
                      canchaPartido == 'Por asignar' ||
                      canchaPartido == 'Sin Cancha') {
                    canchaPartido = _obtenerCanchaRotativa(
                        deporte, octavos.length + cuartos.length + idx);
                  }
                  return _buildTarjetaPartidoBracket(
                    pData['equipoA'] ?? 'Por definir',
                    pData['equipoB'] ?? 'Por definir',
                    pData['puntosA'] ?? 0,
                    pData['puntosB'] ?? 0,
                    canchaPartido,
                    pData['estado'] == 'Finalizado',
                    ganadorPenales: pData['ganadorPenales'],
                  );
                }).toList(),
        ),

        const SizedBox(height: 16),
        const Icon(Icons.arrow_downward, color: Colors.amber, size: 28),
        const SizedBox(height: 16),

        const Text(
          '— GRAN FINAL —',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        finalPartidos.isEmpty
            ? _buildTarjetaPartidoBracket(
                'Por definir',
                'Por definir',
                0,
                0,
                _obtenerCanchaRotativa(deporte, 2),
                false,
              )
            : _buildTarjetaPartidoBracket(
                (finalPartidos.first.data() as Map)['equipoA'] ??
                    'Por definir',
                (finalPartidos.first.data() as Map)['equipoB'] ??
                    'Por definir',
                (finalPartidos.first.data() as Map)['puntosA'] ?? 0,
                (finalPartidos.first.data() as Map)['puntosB'] ?? 0,
                (finalPartidos.first.data() as Map)['cancha'] == null ||
                        (finalPartidos.first.data() as Map)['cancha'] ==
                            'Por asignar' ||
                        (finalPartidos.first.data() as Map)['cancha'] ==
                            'Sin Cancha'
                    ? _obtenerCanchaRotativa(deporte, 3)
                    : (finalPartidos.first.data() as Map)['cancha'],
                (finalPartidos.first.data() as Map)['estado'] == 'Finalizado',
                ganadorPenales: (finalPartidos.first.data() as Map)['ganadorPenales'],
              ),

        const SizedBox(height: 20),

        Container(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber, width: 2),
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 36),
              const SizedBox(height: 6),
              Text(
                ganador,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ganador.contains('Por definir') || ganador.contains('En juego')
                      ? Colors.grey
                      : Colors.amber,
                  fontSize: ganador.length > 20 ? 14 : 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (ganadorPenales != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '⚽ Ganador por penales',
                    style: TextStyle(
                      color: Colors.amber.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TARJETA DE PARTIDO (BRACKET) ====================
  Widget _buildTarjetaPartidoBracket(
    String eqA,
    String eqB,
    int pA,
    int pB,
    String cancha,
    bool finalizado, {
    String? ganadorPenales,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: finalizado ? _accentColor : Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            'Cancha: $cancha',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          _buildBracketTeamTile(eqA, pA),
          const Divider(height: 10, color: Colors.white24),
          _buildBracketTeamTile(eqB, pB),
          if (ganadorPenales != null && finalizado)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '⚽ Penales: $ganadorPenales',
                style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBracketTeamTile(String nombre, int puntos) {
    final bool esPorDefinir = nombre == 'Por definir';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            nombre,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: esPorDefinir ? Colors.grey : Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.black26, borderRadius: BorderRadius.circular(4)),
          child: Text(
            '$puntos',
            style: const TextStyle(
                color: _accentColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}