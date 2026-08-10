import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pin_service.dart';
import '../services/session_service.dart';
import '../screens/login_screen.dart';

class MesaPanel extends StatefulWidget {
  const MesaPanel({super.key});

  @override
  State<MesaPanel> createState() => _MesaPanelState();
}

class _MesaPanelState extends State<MesaPanel> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PinService _pinService = PinService();

  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _newCamisetaController = TextEditingController();
  final TextEditingController _newNombreController = TextEditingController();

  bool _pinVerificado = false;
  String? _pinError;

  String? _torneoIdSeleccionado;
  String? _torneoNombreSeleccionado;
  String _deporteSeleccionado = 'Fútbol';
  String? _partidoIdSeleccionado;

  // Fase actual (se recalcula automáticamente según modalidad)
  String? _faseActual;
  List<String> _ordenFases = ['Octavos', 'Cuartos', 'Semifinal', 'Final'];

  String? _camisetaSeleccionadaA;
  String? _camisetaSeleccionadaB;

  // Vóley
  int _currentSetIndex = 1;
  int _puntosLiveA = 0;
  int _puntosLiveB = 0;
  int _setsGanadosA = 0;
  int _setsGanadosB = 0;
  String _resSet1 = '-';
  String _resSet2 = '-';
  String _resSet3 = '-';

  String? _ganadorPenales;

  final List<String> _deportes = ['Fútbol', 'Vóley', 'Básquet', 'Fútbol 11'];

  @override
  void dispose() {
    _pinController.dispose();
    _newCamisetaController.dispose();
    _newNombreController.dispose();
    super.dispose();
  }

  Color _getDeporteColor(String deporte) {
    switch (deporte) {
      case 'Fútbol 11':
        return const Color(0xFF00E5FF);
      case 'Fútbol':
        return const Color(0xFF0066FF);
      case 'Vóley':
        return const Color(0xFF00FF87);
      case 'Básquet':
        return const Color(0xFFFF5500);
      default:
        return const Color(0xFF00FF87);
    }
  }

  void _resetearEstadoLocal() {
    setState(() {
      _partidoIdSeleccionado = null;
      _camisetaSeleccionadaA = null;
      _camisetaSeleccionadaB = null;
      _ganadorPenales = null;
      _currentSetIndex = 1;
      _puntosLiveA = 0;
      _puntosLiveB = 0;
      _setsGanadosA = 0;
      _setsGanadosB = 0;
      _resSet1 = '-';
      _resSet2 = '-';
      _resSet3 = '-';
    });
  }

  // ==================== DETERMINAR ÓRDEN DE FASES SEGÚN MODALIDAD ====================
  List<String> _obtenerOrdenFases(String modalidad) {
    switch (modalidad) {
      case 'Eliminación Directa':
        return ['Octavos', 'Cuartos', 'Semifinal', 'Final'];
      case 'Grupos':
        return ['Grupos', 'Cuartos', 'Semifinal', 'Final'];
      case 'Todos contra Todos':
        return ['Todos contra Todos', 'Desempate'];  // <--- AHORA INCLUYE DESEMPATE
      default:
        return ['Octavos', 'Cuartos', 'Semifinal', 'Final'];
    }
  }

  // ==================== DETERMINAR FASE ACTUAL ====================
  String _determinarFaseActual(List<QueryDocumentSnapshot> partidos, String modalidad) {
    if (partidos.isEmpty) return _obtenerOrdenFases(modalidad).first;

    final ordenFases = _obtenerOrdenFases(modalidad);

    Set<String> fasesSet = {};
    for (var doc in partidos) {
      final fase = (doc.data() as Map<String, dynamic>)['fase'] ?? 'Cuartos';
      fasesSet.add(fase);
    }

    List<String> fasesOrdenadas = ordenFases.where((f) => fasesSet.contains(f)).toList();
    if (fasesOrdenadas.isEmpty) return ordenFases.first;

    for (var fase in fasesOrdenadas) {
      final partidosFase = partidos.where((doc) {
        final f = (doc.data() as Map<String, dynamic>)['fase'] ?? 'Cuartos';
        return f == fase;
      }).toList();
      final hayPendientes = partidosFase.any((doc) {
        final estado = (doc.data() as Map<String, dynamic>)['estado'] ?? 'Pendiente';
        return estado != 'Finalizado';
      });
      if (hayPendientes) {
        return fase;
      }
    }

    return fasesOrdenadas.last;
  }

  // ==================== OBTENER MODALIDAD DEL TORNEO ====================
  Future<String> _obtenerModalidadTorneo(String torneoId) async {
    try {
      final doc = await _db.collection('torneos').doc(torneoId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['modalidad'] ?? 'Eliminación Directa';
      }
      return 'Eliminación Directa';
    } catch (e) {
      return 'Eliminación Directa';
    }
  }

  // ==================== AUTENTICACIÓN PIN ====================
  Future<void> _verificarPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _pinError = 'El PIN debe tener 4 dígitos');
      return;
    }

    final esValido = await _pinService.validarPin(pin);
    if (esValido) {
      setState(() {
        _pinVerificado = true;
        _pinError = null;
      });
    } else {
      setState(() => _pinError = 'PIN incorrecto. Solicita el código al Admin');
    }
  }

  // ==================== PLANTILLAS ====================
  void _abrirModalRegistroPlantilla(String partidoId, String nombreEquipo, String claveEquipo) {
    final themeColor = _getDeporteColor(_deporteSeleccionado);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131B33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: themeColor, width: 2),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plantilla Inicial: $nombreEquipo', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  const Text('Registra número de camiseta y nombre', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C2541),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: themeColor, width: 1.5),
                            ),
                            child: TextField(
                              controller: _newCamisetaController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'N.º',
                                labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                                hintText: '10',
                                hintStyle: TextStyle(color: Colors.white24),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C2541),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: themeColor, width: 1.5),
                            ),
                            child: TextField(
                              controller: _newNombreController,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Nombre de Jugador',
                                labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                                hintText: 'Ej: Carlos Pérez',
                                hintStyle: TextStyle(color: Colors.white24),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: themeColor, size: 38),
                          onPressed: () async {
                            final cam = _newCamisetaController.text.trim();
                            final nom = _newNombreController.text.trim();

                            if (cam.isEmpty || nom.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ingresa número de camiseta y nombre'), backgroundColor: Colors.orangeAccent),
                              );
                              return;
                            }

                            final docSnap = await _db.collection('partidos').doc(partidoId).get();
                            final pData = docSnap.data() as Map<String, dynamic>? ?? {};
                            final List plantillaActual = List.from(pData['plantilla_$claveEquipo'] ?? []);

                            final existeCamiseta = plantillaActual.any((j) => j['camiseta']?.toString() == cam);
                            if (existeCamiseta) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('⚠️ La camiseta #$cam ya está registrada en $nombreEquipo'), backgroundColor: Colors.redAccent),
                                );
                              }
                              return;
                            }

                            final jugMap = {'camiseta': cam, 'nombre': nom};

                            await _db.collection('partidos').doc(partidoId).update({
                              'plantilla_$claveEquipo': FieldValue.arrayUnion([jugMap])
                            });

                            final equipoDocRef = _db.collection('plantillas_equipos').doc('${_torneoIdSeleccionado}_$nombreEquipo');
                            await equipoDocRef.set({
                              'torneoId': _torneoIdSeleccionado,
                              'equipo': nombreEquipo,
                              'jugadores': FieldValue.arrayUnion([jugMap]),
                            }, SetOptions(merge: true));

                            _newCamisetaController.clear();
                            _newNombreController.clear();
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const Text('Jugadores Registrados en este Partido:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _db.collection('partidos').doc(partidoId).snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        final pData = snap.data!.data() as Map<String, dynamic>? ?? {};
                        final List plantilla = List.from(pData['plantilla_$claveEquipo'] ?? []);

                        if (plantilla.isEmpty) {
                          return const Text('Sin jugadores registrados aún.', style: TextStyle(color: Colors.grey, fontSize: 12));
                        }

                        return SizedBox(
                          height: 160,
                          child: ListView.builder(
                            itemCount: plantilla.length,
                            itemBuilder: (context, idx) {
                              final j = plantilla[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C2541),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: themeColor,
                                    child: Text('#${j['camiseta']}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  title: Text(j['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
                  child: const Text('Listo / Guardar Plantilla', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cargarPlantillaGuardadaSiExiste(String partidoId, String nombreEquipo, String claveEquipo) async {
    final equipoDoc = await _db.collection('plantillas_equipos').doc('${_torneoIdSeleccionado}_$nombreEquipo').get();

    if (equipoDoc.exists) {
      final data = equipoDoc.data();
      final List jugadoresPrevios = data?['jugadores'] ?? [];

      if (jugadoresPrevios.isNotEmpty) {
        await _db.collection('partidos').doc(partidoId).update({
          'plantilla_$claveEquipo': jugadoresPrevios,
        });
      }
    }
  }

  // ==================== PARTIDO ====================
  Future<void> _empezarPartido(String partidoId) async {
    await _db.collection('partidos').doc(partidoId).update({'estado': 'En Juego'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Partido Iniciado!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _registrarGolPunto(String partidoId, String equipoKey, int puntosActuales, {bool esVoley = false, bool esEquipoA = true}) async {
    if (esVoley) {
      if (esEquipoA) {
        if (_puntosLiveA < 25) {
          setState(() => _puntosLiveA++);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Límite de 25 puntos alcanzado para este Set.'), backgroundColor: Colors.orangeAccent),
          );
          return;
        }
      } else {
        if (_puntosLiveB < 25) {
          setState(() => _puntosLiveB++);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Límite de 25 puntos alcanzado para este Set.'), backgroundColor: Colors.orangeAccent),
          );
          return;
        }
      }
      await _db.collection('partidos').doc(partidoId).update({
        'puntosA': _setsGanadosA,
        'puntosB': _setsGanadosB,
        'estado': 'En Juego',
      });
    } else {
      await _db.collection('partidos').doc(partidoId).update({
        equipoKey: puntosActuales + 1,
        'estado': 'En Juego',
      });
    }
  }

  void _terminarSetVoley(String partidoId) async {
    if (_puntosLiveA == 0 && _puntosLiveB == 0) return;

    final String resultadoSet = '$_puntosLiveA - $_puntosLiveB';

    if (_puntosLiveA > _puntosLiveB) {
      _setsGanadosA++;
    } else if (_puntosLiveB > _puntosLiveA) {
      _setsGanadosB++;
    }

    setState(() {
      if (_currentSetIndex == 1) {
        _resSet1 = resultadoSet;
      } else if (_currentSetIndex == 2) {
        _resSet2 = resultadoSet;
      } else if (_currentSetIndex == 3) {
        _resSet3 = resultadoSet;
      }

      _puntosLiveA = 0;
      _puntosLiveB = 0;
      _currentSetIndex++;
    });

    await _db.collection('partidos').doc(partidoId).update({
      'puntosA': _setsGanadosA,
      'puntosB': _setsGanadosB,
      'setsData': {
        'set1': _resSet1,
        'set2': _resSet2,
        'set3': _resSet3,
      },
      'estado': 'En Juego',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Set ${_currentSetIndex - 1} finalizado: $resultadoSet'),
        backgroundColor: _getDeporteColor('Vóley'),
      ),
    );
  }

  // ==================== INCIDENCIAS ====================
  Future<void> _registrarIncidenciaSeleccionada(
      String partidoId, String torneoId, String equipo, String? camisetaSeleccionada, List plantilla, String tipo) async {
    if (camisetaSeleccionada == null || camisetaSeleccionada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona primero un jugador de la lista'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    String nombreJugador = 'Sin Nombre';
    for (var j in plantilla) {
      if (j['camiseta']?.toString() == camisetaSeleccionada) {
        nombreJugador = j['nombre']?.toString() ?? 'Sin Nombre';
        break;
      }
    }

    final incidenciasQuery = await _db
        .collection('incidencias')
        .where('torneoId', isEqualTo: torneoId)
        .where('equipo', isEqualTo: equipo)
        .where('camiseta', isEqualTo: camisetaSeleccionada)
        .get();

    int amarillasPrevias = 0;
    bool tieneRoja = false;
    for (var doc in incidenciasQuery.docs) {
      final data = doc.data();
      if (data['tipo'] == 'Tarjeta Amarilla') amarillasPrevias++;
      if (data['tipo']?.toString().contains('Roja') == true || data['tipo']?.toString().contains('Falta') == true) {
        tieneRoja = true;
      }
    }

    if (tieneRoja || amarillasPrevias >= 2) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1C2541),
            title: const Text('⚠️ JUGADOR SUSPENDIDO', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            content: Text('El jugador #$camisetaSeleccionada ($nombreJugador) ya está suspendido por acumulación de tarjetas y no puede recibir más sanciones ni participar.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido', style: TextStyle(color: Colors.white))),
            ],
          ),
        );
      }
      return;
    }

    if (tipo == 'Tarjeta Amarilla' && amarillasPrevias == 1 && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1C2541),
          title: const Text('⚠️ ALERTA: SEGUNDA AMARILLA', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          content: Text('El jugador #$camisetaSeleccionada ($nombreJugador) ha recibido su segunda tarjeta amarilla y quedará suspendido para el próximo partido.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aceptar', style: TextStyle(color: Colors.white))),
          ],
        ),
      );
    }

    await _db.collection('incidencias').add({
      'partidoId': partidoId,
      'torneoId': torneoId,
      'equipo': equipo,
      'camiseta': camisetaSeleccionada,
      'nombreJugador': nombreJugador,
      'tipo': tipo,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$tipo registrada para #$camisetaSeleccionada - $nombreJugador'),
        backgroundColor: _getDeporteColor(_deporteSeleccionado),
      ),
    );
  }

  // ==================== FINALIZAR PARTIDO (CON PENALES) ====================
  Future<void> _finalizarPartido(String partidoId, String torneoId, String deporte, String equipoA, String equipoB, int puntosA, int puntosB, String? fase, String? grupo) async {
    bool esEliminacionDirecta = (fase == 'Semifinal' || fase == 'Final' || fase == 'Cuartos' || fase == 'Octavos');
    bool hayEmpate = puntosA == puntosB;

    String? ganadorPorPenales;

    if (esEliminacionDirecta && hayEmpate) {
      final seleccion = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF131B33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('⚽ ¡EMPATE!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('El partido terminó empatado. Selecciona al ganador por penales:', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, equipoA),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      icon: const Icon(Icons.emoji_events),
                      label: Text(equipoA, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, equipoB),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      icon: const Icon(Icons.emoji_events),
                      label: Text(equipoB, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

      if (seleccion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finalización cancelada. Debes seleccionar un ganador por penales.'), backgroundColor: Colors.orange),
        );
        return;
      }

      ganadorPorPenales = seleccion;
      setState(() {
        _ganadorPenales = ganadorPorPenales;
      });
    }

    final Map<String, dynamic> updateData = {'estado': 'Finalizado'};

    if (_deporteSeleccionado == 'Vóley') {
      updateData['setsData'] = {
        'set1': _resSet1,
        'set2': _resSet2,
        'set3': _resSet3,
      };
      updateData['puntosA'] = _setsGanadosA;
      updateData['puntosB'] = _setsGanadosB;
    }

    if (ganadorPorPenales != null) {
      updateData['ganadorPenales'] = ganadorPorPenales;
    }

    await _db.collection('partidos').doc(partidoId).update(updateData);

    // Promoción a siguiente fase (solo para fases de eliminación directa)
    if (fase != null && esEliminacionDirecta) {
      String ganador;
      if (ganadorPorPenales != null) {
        ganador = ganadorPorPenales!;
      } else {
        ganador = puntosA > puntosB ? equipoA : (puntosB > puntosA ? equipoB : equipoA);
      }

      String siguienteFase = '';
      if (fase.contains('Octavos') || fase == 'Octavos') siguienteFase = 'Cuartos';
      else if (fase.contains('Cuartos') || fase == 'Cuartos') siguienteFase = 'Semifinal';
      else if (fase.contains('Semifinal') || fase == 'Semifinal') siguienteFase = 'Final';

      if (siguienteFase.isNotEmpty) {
        final nextMatchesQuery = await _db
            .collection('partidos')
            .where('torneoId', isEqualTo: torneoId)
            .where('deporte', isEqualTo: deporte)
            .where('fase', isEqualTo: siguienteFase)
            .get();

        if (nextMatchesQuery.docs.isNotEmpty) {
          for (var doc in nextMatchesQuery.docs) {
            final data = doc.data();
            if (data['equipoA'] == 'Por definir' || data['equipoA'] == null || data['equipoA'].toString().isEmpty) {
              await doc.reference.update({'equipoA': ganador});
              break;
            } else if (data['equipoB'] == 'Por definir' || data['equipoB'] == null || data['equipoB'].toString().isEmpty) {
              await doc.reference.update({'equipoB': ganador});
              break;
            }
          }
        }
      }
    }

    setState(() {
      _partidoIdSeleccionado = null;
      _ganadorPenales = null;
      _currentSetIndex = 1;
      _puntosLiveA = 0;
      _puntosLiveB = 0;
      _setsGanadosA = 0;
      _setsGanadosB = 0;
      _resSet1 = '-';
      _resSet2 = '-';
      _resSet3 = '-';
      _camisetaSeleccionadaA = null;
      _camisetaSeleccionadaB = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Partido finalizado y ganador promovido a la siguiente etapa! ✅'), backgroundColor: Colors.green),
      );
    }
  }

  // ==================== OBTENER GANADOR DEL DESEMPATE ====================
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

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final themeColor = _getDeporteColor(_deporteSeleccionado);

    if (!_pinVerificado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel de Mesa - Autenticación PIN')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 56, color: Color(0xFF00FF87)),
                      const SizedBox(height: 16),
                      const Text('Ingresa el PIN de 4 dígitos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Solicita el PIN activo al Administrador.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, letterSpacing: 10, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(hintText: '0000', errorText: _pinError),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _verificarPin,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF87), foregroundColor: Colors.black),
                        child: const Text('Verificar e Ingresar', style: TextStyle(fontWeight: FontWeight.bold)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Mesa de Control - $_deporteSeleccionado'),
        backgroundColor: const Color(0xFF0B132B),
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
                // ---- SELECTOR DE TORNEO Y DEPORTE ----
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeColor, width: 2),
                  ),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: _db.collection('torneos').orderBy('createdAt', descending: true).snapshots(),
                            builder: (context, snapshot) {
                              final torneosDocs = snapshot.data?.docs ?? [];
                              if (torneosDocs.isEmpty) {
                                return const Text('No hay torneos activos.', style: TextStyle(color: Colors.grey));
                              }

                              return DropdownButtonFormField<String>(
                                value: _torneoIdSeleccionado,
                                decoration: const InputDecoration(labelText: 'Selecciona el Torneo Activo'),
                                items: torneosDocs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text(data['nombre'] ?? 'Torneo Sin Nombre'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final docEncontrado = torneosDocs.firstWhere((d) => d.id == val);
                                    final data = docEncontrado.data() as Map<String, dynamic>;
                                    setState(() {
                                      _torneoIdSeleccionado = val;
                                      _torneoNombreSeleccionado = data['nombre'];
                                      _resetearEstadoLocal();
                                      _faseActual = null;
                                    });
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _deporteSeleccionado,
                            decoration: InputDecoration(
                              labelText: 'Selecciona Deporte',
                              prefixIcon: Icon(Icons.sports, color: themeColor),
                            ),
                            items: _deportes.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _deporteSeleccionado = val;
                                  _resetearEstadoLocal();
                                  _faseActual = null;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ---- STREAM DE PARTIDOS ----
                if (_torneoIdSeleccionado == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Selecciona un Torneo arriba para cargar los encuentros.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  FutureBuilder<String>(
                    future: _obtenerModalidadTorneo(_torneoIdSeleccionado!),
                    builder: (context, modalidadSnapshot) {
                      if (!modalidadSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final modalidad = modalidadSnapshot.data!;
                      final ordenFases = _obtenerOrdenFases(modalidad);

                      return StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('partidos')
                            .where('torneoId', isEqualTo: _torneoIdSeleccionado)
                            .where('deporte', isEqualTo: _deporteSeleccionado)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final allPartidos = snapshot.data?.docs ?? [];

                          if (allPartidos.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  'No hay partidos registrados de $_deporteSeleccionado en "$_torneoNombreSeleccionado".\n¿Ya generaste el fixture desde el administrador?',
                                  style: const TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          // ---- CALCULAR FASE ACTUAL ----
                          final faseCalculada = _determinarFaseActual(allPartidos, modalidad);

                          if (_faseActual != faseCalculada) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _faseActual = faseCalculada;
                                  _ordenFases = ordenFases;
                                });
                              }
                            });
                          }

                          final faseActual = _faseActual ?? ordenFases.first;

                          // Filtrar partidos por fase actual
                          final partidosFaseActual = allPartidos.where((doc) {
                            final fase = (doc.data() as Map<String, dynamic>)['fase'] ?? 'Cuartos';
                            return fase == faseActual;
                          }).toList();

                          final bool todosFinalizados = partidosFaseActual.isNotEmpty &&
                              partidosFaseActual.every((d) {
                                final estado = (d.data() as Map<String, dynamic>)['estado'] ?? 'Pendiente';
                                return estado == 'Finalizado';
                              });

                          final int indexActual = ordenFases.indexOf(faseActual);
                          final bool esUltimaFase = indexActual == ordenFases.length - 1;

                          // ---- VISTA LISTA DE PARTIDOS ----
                          if (_partidoIdSeleccionado == null) {
                            final bool esTodosContraTodos = modalidad == 'Todos contra Todos';

                            // Calcular ganador del torneo si es "Todos contra Todos" y hay desempate finalizado
                            String ganador = '';
                            if (esTodosContraTodos && ordenFases.contains('Desempate')) {
                              final partidosDesempate = allPartidos.where((doc) {
                                final fase = (doc.data() as Map<String, dynamic>)['fase'] ?? '';
                                return fase == 'Desempate';
                              }).toList();
                              if (partidosDesempate.isNotEmpty &&
                                  partidosDesempate.every((d) {
                                    final estado = (d.data() as Map<String, dynamic>)['estado'] ?? 'Pendiente';
                                    return estado == 'Finalizado';
                                  })) {
                                ganador = _obtenerGanadorDesempate(partidosDesempate);
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Partidos de $_deporteSeleccionado (${esTodosContraTodos ? 'Liga' : faseActual}):',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor),
                                ),
                                const SizedBox(height: 12),

                                partidosFaseActual.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Center(
                                          child: Text(
                                            'No hay partidos generados para la etapa "${esTodosContraTodos ? 'Liga' : faseActual}".',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        primary: false,
                                        itemCount: partidosFaseActual.length,
                                        itemBuilder: (context, idx) {
                                          final pData = partidosFaseActual[idx].data() as Map<String, dynamic>;
                                          final pId = partidosFaseActual[idx].id;
                                          final estadoPartido = pData['estado'] ?? 'Pendiente';
                                          final bool esFinalizado = estadoPartido == 'Finalizado';
                                          final String etiquetaFase = pData['fase'] ?? '';

                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            child: ListTile(
                                              title: Text(
                                                '${pData['equipoA']} vs ${pData['equipoB']}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Cancha: ${pData['cancha'] ?? "Sin Asignar"} • Estado: $estadoPartido',
                                                  ),
                                                  if (etiquetaFase == 'Desempate')
                                                    Container(
                                                      margin: const EdgeInsets.only(top: 2),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        '⚽ Desempate',
                                                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              trailing: ElevatedButton(
                                                onPressed: esFinalizado
                                                    ? null
                                                    : () async {
                                                        await _cargarPlantillaGuardadaSiExiste(pId, pData['equipoA'], 'equipoA');
                                                        await _cargarPlantillaGuardadaSiExiste(pId, pData['equipoB'], 'equipoB');

                                                        setState(() {
                                                          _partidoIdSeleccionado = pId;
                                                          _camisetaSeleccionadaA = null;
                                                          _camisetaSeleccionadaB = null;
                                                        });
                                                      },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: esFinalizado ? Colors.grey : themeColor,
                                                  foregroundColor: esFinalizado ? Colors.white70 : Colors.black,
                                                ),
                                                child: Text(
                                                  esFinalizado ? 'Finalizado' : 'Iniciar Mesa',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                const SizedBox(height: 24),

                                // ---- BOTÓN SIGUIENTE ETAPA ----
                                if (!esTodosContraTodos) ...[
                                  if (!esUltimaFase)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: todosFinalizados && partidosFaseActual.isNotEmpty
                                            ? () {
                                                final siguienteFase = ordenFases[indexActual + 1];
                                                setState(() {
                                                  _faseActual = siguienteFase;
                                                  _partidoIdSeleccionado = null;
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('¡Avanzando a la etapa "$siguienteFase"! 🚀'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: todosFinalizados ? const Color(0xFF00FF87) : Colors.grey,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        child: Text(
                                          todosFinalizados
                                              ? 'SIGUIENTE ETAPA (${ordenFases[indexActual + 1]})'
                                              : 'Esperando que todos los partidos finalicen...',
                                        ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        child: const Text('🏆 TORNEO FINALIZADO 🏆'),
                                      ),
                                    ),
                                ],

                                // ---- CONTENEDOR DEL GANADOR (TODOS CONTRA TODOS) ----
                                if (esTodosContraTodos && ganador.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
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
                                          ganador,
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
                            );
                          }

                          // ---- VISTA MESA DE CONTROL (PARTIDO SELECCIONADO) ----
                          QueryDocumentSnapshot? partidoDoc;
                          for (var doc in allPartidos) {
                            if (doc.id == _partidoIdSeleccionado) {
                              partidoDoc = doc;
                              break;
                            }
                          }
                          partidoDoc ??= allPartidos.first;
                          final pData = partidoDoc.data() as Map<String, dynamic>;
                          final estadoPartido = pData['estado'] ?? 'Pendiente';

                          final List plantillaA = List.from(pData['plantilla_equipoA'] ?? []);
                          final List plantillaB = List.from(pData['plantilla_equipoB'] ?? []);

                          final listaCamisetasA = plantillaA.map((j) => j['camiseta']?.toString() ?? '').where((c) => c.isNotEmpty).toSet().toList();
                          final listaCamisetasB = plantillaB.map((j) => j['camiseta']?.toString() ?? '').where((c) => c.isNotEmpty).toSet().toList();

                          if (_camisetaSeleccionadaA != null && !listaCamisetasA.contains(_camisetaSeleccionadaA)) {
                            _camisetaSeleccionadaA = null;
                          }
                          if (_camisetaSeleccionadaB != null && !listaCamisetasB.contains(_camisetaSeleccionadaB)) {
                            _camisetaSeleccionadaB = null;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: themeColor, width: 2),
                            ),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$_torneoNombreSeleccionado • ${pData['fase'] ?? "Partido"} • Cancha: ${pData['cancha'] ?? "Sin Asignar"}',
                                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _partidoIdSeleccionado = null;
                                              _camisetaSeleccionadaA = null;
                                              _camisetaSeleccionadaB = null;
                                            });
                                          },
                                          icon: const Icon(Icons.swap_horiz, size: 18),
                                          label: const Text('Volver a la Lista'),
                                        )
                                      ],
                                    ),
                                    const Divider(height: 24),

                                    if (estadoPartido == 'Pendiente') ...[
                                      ElevatedButton.icon(
                                        onPressed: () => _empezarPartido(partidoDoc!.id),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(45)),
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Empezar Partido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF131B33),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text('📋 Lista Inicial de Jugadores', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _abrirModalRegistroPlantilla(partidoDoc!.id, pData['equipoA'], 'equipoA'),
                                                  icon: const Icon(Icons.person_add, size: 16),
                                                  label: Text('${pData['equipoA']} (${plantillaA.length} jug.)', style: const TextStyle(fontSize: 11)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _abrirModalRegistroPlantilla(partidoDoc!.id, pData['equipoB'], 'equipoB'),
                                                  icon: const Icon(Icons.person_add, size: 16),
                                                  label: Text('${pData['equipoB']} (${plantillaB.length} jug.)', style: const TextStyle(fontSize: 11)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // ---- MARCADOR ----
                                    if (_deporteSeleccionado == 'Vóley') ...[
                                      // Vóley (sin cambios)
                                      Text('Set $_currentSetIndex (Puntos del Set: Máx 25)', style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16)),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Column(
                                            children: [
                                              Text(pData['equipoA'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Text('$_puntosLiveA', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: themeColor)),
                                              ElevatedButton.icon(
                                                onPressed: () => _registrarGolPunto(partidoDoc!.id, 'puntosA', 0, esVoley: true, esEquipoA: true),
                                                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
                                                icon: const Icon(Icons.add),
                                                label: const Text('+1 Punto'),
                                              ),
                                            ],
                                          ),
                                          const Text('VS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
                                          Column(
                                            children: [
                                              Text(pData['equipoB'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Text('$_puntosLiveB', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: themeColor)),
                                              ElevatedButton.icon(
                                                onPressed: () => _registrarGolPunto(partidoDoc!.id, 'puntosB', 0, esVoley: true, esEquipoA: false),
                                                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
                                                icon: const Icon(Icons.add),
                                                label: const Text('+1 Punto'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () => _terminarSetVoley(partidoDoc!.id),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: Text('Terminar Set $_currentSetIndex', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          Text('Set 1: $_resSet1', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('Set 2: $_resSet2', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('Set 3: $_resSet3', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ] else ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Column(
                                            children: [
                                              Text(pData['equipoA'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Text('${pData['puntosA'] ?? 0}', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: themeColor)),
                                              ElevatedButton.icon(
                                                onPressed: () => _registrarGolPunto(partidoDoc!.id, 'puntosA', pData['puntosA'] ?? 0),
                                                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
                                                icon: const Icon(Icons.add),
                                                label: Text(_deporteSeleccionado.contains('Fútbol') ? '+1 Gol' : '+1 Punto'),
                                              ),
                                            ],
                                          ),
                                          const Text('VS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
                                          Column(
                                            children: [
                                              Text(pData['equipoB'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Text('${pData['puntosB'] ?? 0}', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: themeColor)),
                                              ElevatedButton.icon(
                                                onPressed: () => _registrarGolPunto(partidoDoc!.id, 'puntosB', pData['puntosB'] ?? 0),
                                                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
                                                icon: const Icon(Icons.add),
                                                label: Text(_deporteSeleccionado.contains('Fútbol') ? '+1 Gol' : '+1 Punto'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],

                                    // ---- INCIDENCIAS ----
                                    const Divider(height: 32),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Registrar Incidencia / Falta / Tarjeta:', style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                                    ),
                                    const SizedBox(height: 12),

                                    StreamBuilder<QuerySnapshot>(
                                      stream: _db.collection('incidencias').where('torneoId', isEqualTo: _torneoIdSeleccionado).snapshots(),
                                      builder: (context, incidenciasSnap) {
                                        final todasIncidencias = incidenciasSnap.data?.docs ?? [];

                                        String obtenerEstadoTarjetas(String equipo, String camiseta) {
                                          int amarillas = 0;
                                          bool tieneRoja = false;

                                          for (var inc in todasIncidencias) {
                                            final data = inc.data() as Map<String, dynamic>;
                                            if (data['equipo'] == equipo && data['camiseta']?.toString() == camiseta) {
                                              if (data['tipo'] == 'Tarjeta Amarilla') {
                                                amarillas++;
                                              } else if (data['tipo']?.toString().contains('Roja') == true || data['tipo']?.toString().contains('Falta') == true) {
                                                tieneRoja = true;
                                              }
                                            }
                                          }

                                          if (tieneRoja || amarillas >= 2) return ' 🟥 (Sancionado)';
                                          if (amarillas == 1) return ' 🟨 (1 Amarilla)';
                                          return '';
                                        }

                                        return Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                value: _camisetaSeleccionadaA,
                                                isExpanded: true,
                                                decoration: InputDecoration(labelText: 'Jugador ${pData['equipoA']}'),
                                                items: plantillaA.map<DropdownMenuItem<String>>((j) {
                                                  final cam = j['camiseta']?.toString() ?? '';
                                                  final nom = j['nombre']?.toString() ?? '';
                                                  final estadoSancion = obtenerEstadoTarjetas(pData['equipoA'], cam);
                                                  return DropdownMenuItem<String>(
                                                    value: cam,
                                                    child: Text('#$cam - $nom$estadoSancion', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                                  );
                                                }).toList(),
                                                onChanged: (val) => setState(() => _camisetaSeleccionadaA = val),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                value: _camisetaSeleccionadaB,
                                                isExpanded: true,
                                                decoration: InputDecoration(labelText: 'Jugador ${pData['equipoB']}'),
                                                items: plantillaB.map<DropdownMenuItem<String>>((j) {
                                                  final cam = j['camiseta']?.toString() ?? '';
                                                  final nom = j['nombre']?.toString() ?? '';
                                                  final estadoSancion = obtenerEstadoTarjetas(pData['equipoB'], cam);
                                                  return DropdownMenuItem<String>(
                                                    value: cam,
                                                    child: Text('#$cam - $nom$estadoSancion', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                                  );
                                                }).toList(),
                                                onChanged: (val) => setState(() => _camisetaSeleccionadaB = val),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => _registrarIncidenciaSeleccionada(
                                              partidoDoc!.id, _torneoIdSeleccionado!, pData['equipoA'], _camisetaSeleccionadaA, plantillaA, 'Tarjeta Amarilla'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                          child: Text('Amarilla (${pData['equipoA']})'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _registrarIncidenciaSeleccionada(
                                              partidoDoc!.id, _torneoIdSeleccionado!, pData['equipoB'], _camisetaSeleccionadaB, plantillaB, 'Tarjeta Amarilla'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                          child: Text('Amarilla (${pData['equipoB']})'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _registrarIncidenciaSeleccionada(
                                              partidoDoc!.id, _torneoIdSeleccionado!, pData['equipoA'], _camisetaSeleccionadaA, plantillaA, 'Falta / Roja'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                          child: Text('Falta (${pData['equipoA']})'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _registrarIncidenciaSeleccionada(
                                              partidoDoc!.id, _torneoIdSeleccionado!, pData['equipoB'], _camisetaSeleccionadaB, plantillaB, 'Falta / Roja'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                          child: Text('Falta (${pData['equipoB']})'),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => _finalizarPartido(
                                        partidoDoc!.id,
                                        _torneoIdSeleccionado!,
                                        _deporteSeleccionado,
                                        pData['equipoA'],
                                        pData['equipoB'],
                                        pData['puntosA'] ?? 0,
                                        pData['puntosB'] ?? 0,
                                        pData['fase'],
                                        pData['grupo'],
                                      ),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      icon: const Icon(Icons.stop_circle),
                                      label: const Text('Terminar / Finalizar Partido', style: TextStyle(fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
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