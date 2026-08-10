import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import '../screens/login_screen.dart';

class EspectadorPanel extends StatefulWidget {
  const EspectadorPanel({super.key});

  @override
  State<EspectadorPanel> createState() => _EspectadorPanelState();
}

class _EspectadorPanelState extends State<EspectadorPanel> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Color _accentColor = Color(0xFF00FF87);

  String? _torneoIdSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Resultados (Espectador)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SessionService().clearSession();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _db.collection('torneos').orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        final torneos = snapshot.data?.docs ?? [];
                        if (torneos.isEmpty) {
                          return const Text('No hay torneos activos en este momento.', style: TextStyle(color: Colors.grey));
                        }

                        return DropdownButtonFormField<String>(
                          value: _torneoIdSeleccionado,
                          decoration: const InputDecoration(
                            labelText: 'Selecciona el Torneo a Consultar',
                            prefixIcon: Icon(Icons.emoji_events, color: _accentColor),
                          ),
                          items: torneos.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(data['nombre'] ?? 'Torneo Sin Nombre'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _torneoIdSeleccionado = val);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_torneoIdSeleccionado == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.sports_score, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'Elige un torneo arriba para consultar el fixture y marcadores en vivo',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  StreamBuilder<DocumentSnapshot>(
                    stream: _db.collection('torneos').doc(_torneoIdSeleccionado).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const Center(child: Text('Cargando torneo...'));
                      }

                      final tData = snapshot.data!.data() as Map<String, dynamic>;
                      final deportes = List<dynamic>.from(tData['deportes'] ?? []);
                      final modalidad = tData['modalidad'] ?? 'Todos contra Todos';

                      if (deportes.isEmpty) {
                        return const Center(child: Text('Sin deportes registrados'));
                      }

                      return DefaultTabController(
                        length: deportes.length,
                        child: Column(
                          children: [
                            TabBar(
                              isScrollable: true,
                              indicatorColor: _accentColor,
                              labelColor: _accentColor,
                              unselectedLabelColor: Colors.grey,
                              tabs: deportes.map((d) => Tab(text: d.toString())).toList(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 650,
                              child: TabBarView(
                                children: deportes.map((deporteObj) {
                                  final deporte = deporteObj.toString();
                                  return _buildSubSeccionDeporte(_torneoIdSeleccionado!, deporte, modalidad);
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSubSeccionDeporte(String torneoId, String deporte, String modalidad) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF131B33),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const TabBar(
              indicatorColor: _accentColor,
              labelColor: _accentColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Marcadores en Vivo'),
                Tab(text: 'Árbol Fixture y Posiciones'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildMarcadoresEnVivo(torneoId, deporte),
                _buildFixtureSegunModalidad(torneoId, deporte, modalidad),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MARCADORES EN VIVO ====================
  Widget _buildMarcadoresEnVivo(String torneoId, String deporte) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('partidos')
          .where('torneoId', isEqualTo: torneoId)
          .where('deporte', isEqualTo: deporte)
          .snapshots(),
      builder: (context, snapshot) {
        final partidos = snapshot.data?.docs ?? [];

        if (partidos.isEmpty) {
          return const Center(
            child: Text('No hay partidos programados para este deporte.', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: partidos.length,
          itemBuilder: (context, idx) {
            final pData = partidos[idx].data() as Map<String, dynamic>;
            final estado = pData['estado'] ?? 'Pendiente';
            final enJuego = estado == 'En Juego';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cancha: ${pData['cancha'] ?? "Por Definir"}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: enJuego
                                ? Colors.green
                                : (estado == 'Finalizado' ? Colors.blueGrey : Colors.orange),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            enJuego ? '● EN VIVO' : estado,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Text(
                            pData['equipoA'] ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B33),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: enJuego ? _accentColor : Colors.white24),
                          ),
                          child: Text(
                            '${pData['puntosA']}  -  ${pData['puntosB']}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: enJuego ? _accentColor : Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            pData['equipoB'] ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (pData['ganadorPenales'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ganador por penales: ${pData['ganadorPenales']}',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (pData['fase'] == 'Desempate')
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '⚽ Desempate',
                            style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== FIXTURE SEGÚN MODALIDAD ====================
  Widget _buildFixtureSegunModalidad(String torneoId, String deporte, String modalidad) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('partidos')
          .where('torneoId', isEqualTo: torneoId)
          .where('deporte', isEqualTo: deporte)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No hay fixture generado aún.', style: TextStyle(color: Colors.grey)));
        }

        if (modalidad == 'Eliminación Directa') {
          return SingleChildScrollView(child: _buildBracketVerticalTree(docs));
        }

        if (modalidad == 'Grupos') {
          final docsGrupoA = docs.where((d) => (d.data() as Map)['grupo'] == 'Grupo A').toList();
          final docsGrupoB = docs.where((d) => (d.data() as Map)['grupo'] == 'Grupo B').toList();
          final docsEliminatoria = docs.where((d) => (d.data() as Map)['fase'] == 'Semifinal' || (d.data() as Map)['fase'] == 'Final').toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildSeccionGrupoCompleta('GRUPO A', docsGrupoA),
                const SizedBox(height: 16),
                _buildSeccionGrupoCompleta('GRUPO B', docsGrupoB),
                if (docsEliminatoria.isNotEmpty) ...[
                  const Divider(height: 30),
                  const Text(
                    '— FASE FINAL (ELIMINACIÓN DIRECTA) —',
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildBracketVerticalTree(docsEliminatoria),
                ]
              ],
            ),
          );
        }

        // TODOS CONTRA TODOS (con desempate)
        if (modalidad == 'Todos contra Todos') {
          final partidosLiga = docs.where((d) {
            final fase = (d.data() as Map)['fase'] ?? '';
            return fase != 'Desempate';
          }).toList();

          final partidosDesempate = docs.where((d) {
            final fase = (d.data() as Map)['fase'] ?? '';
            return fase == 'Desempate';
          }).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildSeccionGrupoCompleta('LIGA - TODOS CONTRA TODOS', partidosLiga),
                if (partidosDesempate.isNotEmpty) ...[
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

                  // Mostrar ganador del desempate si todos están finalizados
                  if (partidosDesempate.every((d) {
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
                          const Text(
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
            ),
          );
        }

        return const SizedBox();
      },
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

  // ==================== BRACKET DE ELIMINACIÓN DIRECTA ====================
  Widget _buildBracketVerticalTree(List<QueryDocumentSnapshot> docs) {
    const ordenFases = ['Octavos', 'Cuartos', 'Semifinal', 'Final'];

    Map<String, List<QueryDocumentSnapshot>> partidosPorFase = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fase = data['fase'] ?? 'Cuartos';
      partidosPorFase.putIfAbsent(fase, () => []).add(doc);
    }

    final fasesExistentes = ordenFases.where((f) => partidosPorFase.containsKey(f)).toList();

    if (fasesExistentes.isEmpty) {
      return const Center(
        child: Text('No hay fases definidas para este deporte.', style: TextStyle(color: Colors.grey)),
      );
    }

    List<Widget> faseWidgets = [];

    for (int i = 0; i < fasesExistentes.length; i++) {
      final fase = fasesExistentes[i];
      final partidos = partidosPorFase[fase]!;

      faseWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '— $fase —',
            style: const TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );

      if (partidos.isEmpty) {
        faseWidgets.add(
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Sin partidos aún', style: TextStyle(color: Colors.grey)),
          ),
        );
      } else {
        faseWidgets.add(
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: partidos.map((doc) {
              final pData = doc.data() as Map<String, dynamic>;
              return _buildTarjetaPartidoBracket(
                pData['equipoA'] ?? 'Por definir',
                pData['equipoB'] ?? 'Por definir',
                pData['puntosA'] ?? 0,
                pData['puntosB'] ?? 0,
                pData['cancha'] ?? 'Sin Cancha',
                pData['estado'] == 'Finalizado',
                ganadorPenales: pData['ganadorPenales'],
              );
            }).toList(),
          ),
        );
      }

      if (i < fasesExistentes.length - 1) {
        faseWidgets.add(const SizedBox(height: 16));
        faseWidgets.add(const Icon(Icons.arrow_downward, color: _accentColor, size: 28));
        faseWidgets.add(const SizedBox(height: 16));
      }
    }

    // --- GANADOR ---
    String ganador = 'GANADOR DEL TORNEO';
    if (fasesExistentes.isNotEmpty && fasesExistentes.last == 'Final') {
      final partidosFinal = partidosPorFase['Final']!;
      if (partidosFinal.isNotEmpty) {
        final pData = partidosFinal.first.data() as Map<String, dynamic>;
        if (pData['estado'] == 'Finalizado') {
          final pA = (pData['puntosA'] ?? 0) as int;
          final pB = (pData['puntosB'] ?? 0) as int;
          if (pA > pB) {
            ganador = pData['equipoA'] ?? 'GANADOR DEL TORNEO';
          } else if (pB > pA) {
            ganador = pData['equipoB'] ?? 'GANADOR DEL TORNEO';
          } else {
            final penales = pData['ganadorPenales'];
            if (penales != null && penales.toString().isNotEmpty) {
              ganador = penales.toString();
            }
          }
        }
      }
    }

    faseWidgets.add(const SizedBox(height: 20));
    faseWidgets.add(
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return Column(children: faseWidgets);
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
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$puntos',
            style: const TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SECCIÓN DE GRUPO (TABLA + PARTIDOS) ====================
  Widget _buildSeccionGrupoCompleta(String titulo, List<QueryDocumentSnapshot> partidosDocs) {
    if (partidosDocs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _accentColor)),
              const Divider(height: 16),
              const Text('Sin partidos registrados.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _accentColor)),
                Text('${partidosDocs.length} Partidos Totales', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(height: 16),
            const Text('Enfrentamientos:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: partidosDocs.length,
              itemBuilder: (context, idx) {
                final pData = partidosDocs[idx].data() as Map<String, dynamic>;
                final bool finalizado = pData['estado'] == 'Finalizado';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B33),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: finalizado ? _accentColor.withOpacity(0.3) : Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Partido ${idx + 1}: ${pData['equipoA']} vs ${pData['equipoB']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text('Cancha: ${pData['cancha'] ?? "Por definir"}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (pData['ganadorPenales'] != null)
                              Text('Ganador por penales: ${pData['ganadorPenales']}',
                                  style: const TextStyle(fontSize: 10, color: Colors.amber)),
                            if (pData['fase'] == 'Desempate')
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Desempate',
                                  style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: finalizado ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          finalizado ? '${pData['puntosA']} - ${pData['puntosB']}' : 'Pendiente',
                          style: TextStyle(
                            color: finalizado ? Colors.greenAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 20),
            const Text('Tabla de Posiciones:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildTablaPosicionesCalculada(partidosDocs),
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

    final equiposOrdenados = tablaPuntos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: equiposOrdenados.length,
      itemBuilder: (context, idx) {
        final item = equiposOrdenados[idx];
        final esPrimerLugar = idx == 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: esPrimerLugar ? _accentColor.withOpacity(0.1) : const Color(0xFF131B33),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${idx + 1}. ${item.key}', style: TextStyle(fontWeight: FontWeight.bold, color: esPrimerLugar ? _accentColor : Colors.white)),
              Text('${item.value} PTS', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}