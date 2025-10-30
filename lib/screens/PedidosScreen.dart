import 'dart:convert';
import 'dart:io'; // Import for SocketException
import 'dart:async'; // Import for TimeoutException
import 'package:flutter/material.dart';
import 'package:distribuidora/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:distribuidora/screens/nota_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:distribuidora/models/nota_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import for connectivity_plus
import 'package:distribuidora/models/offline_note_model.dart';
import 'package:distribuidora/services/database_helper.dart';

// --- Modelo para la nueva vista de Clientes con Saldo ---
class ClienteConSaldo {
  final int id;
  final String nombre;

  ClienteConSaldo({required this.id, required this.nombre});

  factory ClienteConSaldo.fromJson(Map<String, dynamic> json) {
    return ClienteConSaldo(
      id: int.tryParse(json['idcliente'].toString()) ?? 0,
      nombre: json['nombrecliente'] ?? 'N/A',
    );
  }
}

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  PedidosScreenState createState() => PedidosScreenState();
}

class PedidosScreenState extends State<PedidosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Estado para la pestaña de Notas de Venta (Refactorizado) ---
  bool _isLoadingNotas = true;
  List<Nota> _notas = [];
  List<ClienteConSaldo> _clientesConSaldo = [];
  ClienteConSaldo? _selectedClient;

  // --- Estado para la pestaña de Historial (Refactorizado) ---
  bool _isLoadingHistorial = true;
  List<Nota> _todasLasNotas = [];

  void refreshAllData() {
    _fetchDataNotas();
    _fetchHistorial();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDataNotas(); 
    _fetchHistorial();

    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _fetchHistorial(); // Refresca el historial cada vez que se visita la pestaña
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

    // --- LÓGICA REFACTORIZADA PARA NOTAS DE VENTA ---

    Future<void> _fetchDataNotas() async {
      setState(() { _isLoadingNotas = true; });

      var connectivityResult = await (Connectivity().checkConnectivity());
      final isOffline = connectivityResult == ConnectivityResult.none;

      if (isOffline) {
        // _showConnectivitySnackBar('No hay conexión a internet. Intentando cargar notas guardadas localmente.');
        await _loadNotasFromOffline();
        if (mounted) setState(() { _isLoadingNotas = false; });
        return;
      }

      try {
        String urlString;
        if (_selectedClient == null) {
          urlString = '${ApiConfig.baseUrl}api_consulta_notas_v2.php';
        } else {
          urlString = '${ApiConfig.baseUrl}api_consulta_notas_v2.php?idcliente=${_selectedClient!.id}';
        }

        final url = Uri.parse(urlString);
        final response = await http.get(url).timeout(const Duration(seconds: 15));

        if (mounted) {
          final decoded = json.decode(response.body);
          if (decoded['success'] == true) {
            final responseData = decoded['response'];
            final type = responseData['type'];
            final data = responseData['data'] as List;

            setState(() {
              if (type == 'clientes') {
                _clientesConSaldo = data.map((json) => ClienteConSaldo.fromJson(json)).toList();
                // No guardar clientes en offline por ahora, solo notas
              } else if (type == 'notas') {
                _notas = data.map((json) => Nota.fromJson(json)).toList();
                // No guardar en offline aquí para evitar sobreescribir el historial completo
              }
            });
          } else {
            throw Exception(decoded['error'] ?? 'Error al cargar datos');
          }
        }
      } on SocketException {
        if (mounted) {
          // _showConnectivitySnackBar('No se pudo conectar al servidor. Intentando cargar notas guardadas localmente.');
          await _loadNotasFromOffline(); // Fallback a offline
        }
      } on TimeoutException {
        if (mounted) {
          // _showConnectivitySnackBar('La conexión es lenta o inestable. Intentando cargar notas guardadas localmente.');
          await _loadNotasFromOffline(); // Fallback a offline
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en Notas: $e')));
          await _loadNotasFromOffline(); // Fallback a offline
        }
      } finally {
        if (mounted) setState(() { _isLoadingNotas = false; });
      }
    }

    Future<void> _loadNotasFromOffline() async {
      final dbHelper = DatabaseHelper.instance;
      final List<Map<String, dynamic>> notasMaps = await dbHelper.getNotasOffline();
      final List<Nota> loadedNotas = [];

      for (var notaMap in notasMaps) {
        // Convert NotaOffline map back to Nota object for UI display
        loadedNotas.add(Nota(
          idnota: notaMap['idnota'],
          total: notaMap['total'],
          saldo: notaMap['saldo'],
          regtimestamp: notaMap['regtimestamp'],
          nombreCliente: notaMap['nombre_cliente'],
          idalmacen: notaMap['idalmacen'],
          nombreAlmacenSalida: notaMap['nombre_almacen_salida'],
          nombreAlmacenOrigen: notaMap['nombre_almacen_origen'],
          montoPagadoAcumulado: notaMap['monto_pagado_acumulado'],
          nombreVendedor: notaMap['nombre_vendedor'], // <-- AÑADIDO
        ));
      }

      if (mounted) {
        setState(() {
          _notas = loadedNotas;
          _todasLasNotas = loadedNotas; // Also update for historial tab
        });
        if (loadedNotas.isEmpty) {
          // _showConnectivitySnackBar('No hay conexión a internet y no se encontraron notas guardadas localmente.');
        } else {
          // _showConnectivitySnackBar('Mostrando notas guardadas localmente (sin conexión).');
        }
      }
    }

    Future<void> _saveNotasToOffline(List<Nota> notas) async {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.clearAllNotasOffline(); // Clear old cache

      for (final nota in notas) {
        await dbHelper.insertNotaOffline(NotaOffline.fromNota(nota).toMap());
        // Fetch and save details for each note
      }
    }



  

    // --- LÓGICA REFACTORIZADA PARA HISTORIAL ---

        Future<void> _fetchHistorial() async {

          setState(() { _isLoadingHistorial = true; });

    

          var connectivityResult = await (Connectivity().checkConnectivity());

          final isOffline = connectivityResult == ConnectivityResult.none;

    

          if (isOffline) {

            // _showConnectivitySnackBar('No hay conexión a internet. Intentando cargar historial guardado localmente.');

            await _loadNotasFromOffline(); // Reutilizamos la misma lógica de carga

            if (mounted) setState(() { _isLoadingHistorial = false; });

            return;

          }

    

          try {

            final url = Uri.parse('${ApiConfig.baseUrl}api_todas_las_notas.php');

            final response = await http.get(url).timeout(const Duration(seconds: 15)); // Added timeout

    

            if (mounted) {

              final decoded = json.decode(response.body);

              if (decoded['success'] == true) {

                final data = decoded['data'] as List;

                setState(() {

                  _todasLasNotas = data.map((json) => Nota.fromJson(json)).toList();

                  // Guardar historial en SQLite local

                  _saveNotasToOffline(_todasLasNotas);

                });

              } else {

                throw Exception(decoded['error'] ?? 'Error al cargar historial');

              }

            }

          } on SocketException {

            if (mounted) {

              // _showConnectivitySnackBar('No se pudo conectar al servidor. Intentando cargar historial guardado localmente.');

              await _loadNotasFromOffline(); // Fallback a offline

            }

          } on TimeoutException { // Catch TimeoutException specifically

            if (mounted) {

              // _showConnectivitySnackBar('La conexión es lenta o inestable. Intentando cargar historial guardado localmente.');

              await _loadNotasFromOffline(); // Fallback a offline

            }

          } catch (e) {

            if (mounted) {

              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en Historial: $e')));

              await _loadNotasFromOffline(); // Fallback a offline

            }

          } finally {

            if (mounted) setState(() { _isLoadingHistorial = false; });

          }

        }

  



  

    String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Fecha desconocida';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(isoString));
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.payment), SizedBox(width: 8), Text('Notas de Venta')])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history), SizedBox(width: 8), Text('Historial')])),
            ],
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.blueGrey,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3.0,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotasDeVentaView(),
              _buildHistorialView(),
            ],
          ),
        ),
      ],
    );
  }

  // --- UI REFACTORIZADA para Pestaña 1: Notas de Venta ---
  Widget _buildNotasDeVentaView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: Column(
        children: [
          if (_selectedClient != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Card(
                elevation: 2,
                child: ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A)),
                    onPressed: () {
                      setState(() {
                        _selectedClient = null;
                        _clientesConSaldo = []; // Limpiar para forzar recarga
                      });
                      _fetchDataNotas(); // Cargar la lista de clientes de nuevo
                    },
                  ),
                  title: Text(
                    'Notas de: ${_selectedClient!.nombre}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isLoadingNotas
                ? const Center(child: CircularProgressIndicator())
                : _selectedClient == null
                    ? _buildClientList()
                    : _notas.isEmpty
                        ? const Center(child: Text('Este cliente no tiene notas pendientes.'))
                        : _buildNotaslist(),
          ),
        ],
      ),
    );
  }

  Widget _buildClientList() {
    if (_clientesConSaldo.isEmpty) {
      return const Center(child: Text('No hay clientes con notas pendientes de pago.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _clientesConSaldo.length,
      itemBuilder: (context, index) {
        final cliente = _clientesConSaldo[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              child: Icon(Icons.person_outline),
            ),
            title: Text(cliente.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueGrey),
            onTap: () {
              setState(() {
                _selectedClient = cliente;
                _notas = []; // Limpiar notas anteriores
              });
              _fetchDataNotas();
            },
          ),
        );
      },
    );
  }

  Widget _buildNotaslist() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _notas.length,
      itemBuilder: (context, index) {
        final nota = _notas[index];
        final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
        final bool conSaldo = nota.saldo > 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: conSaldo ? Colors.orange.shade700 : Colors.green, foregroundColor: Colors.white, child: Text('#${nota.idnota}')),
            title: Text(nota.nombreCliente, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('''Total: ${currencyFormat.format(nota.total)} | Saldo: ${currencyFormat.format(nota.saldo)} | Pagado: ${currencyFormat.format(nota.montoPagadoAcumulado)}
${_formatTimestamp(nota.regtimestamp)}'''),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final shouldRefresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => NotaDetailScreen(nota: nota)));
              if (shouldRefresh == true) {
                _fetchDataNotas(); // Refresca las notas del cliente actual
              }
            },
          ),
        );
      },
    );
  }

  // --- UI REFACTORIZADA para Pestaña 2: Historial ---
  Widget _buildHistorialView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: _isLoadingHistorial
          ? const Center(child: CircularProgressIndicator())
          : _todasLasNotas.isEmpty
              ? const Center(child: Text('No se encontraron notas en el historial.'))
              : _buildHistorialList(),
    );
  }

  Widget _buildHistorialList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _todasLasNotas.length,
      itemBuilder: (context, index) {
        final nota = _todasLasNotas[index];
        final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
        final bool conSaldo = nota.saldo > 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: conSaldo ? Colors.orange.shade700 : Colors.green, foregroundColor: Colors.white, child: Text('#${nota.idnota}')),
            title: Text(nota.nombreCliente, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('''Total: ${currencyFormat.format(nota.total)} | Saldo: ${currencyFormat.format(nota.saldo)} | Pagado: ${currencyFormat.format(nota.montoPagadoAcumulado)}
${_formatTimestamp(nota.regtimestamp)}'''),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => NotaDetailScreen(nota: nota)));
              // Al volver del detalle, refrescamos ambas listas por si hubo un pago
              _fetchDataNotas();
              _fetchHistorial();
            },
          ),
        );
      },
    );
  }
}
