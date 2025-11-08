import 'dart:convert';
import 'package:distribuidora/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:distribuidora/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for SharedPreferences

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isLoading = true;
  bool _isBulkUploading = false;
  bool _isDownloading = false;
  String? _lastSyncTimestamp;

  // Listas de datos no sincronizados
  List<Map<String, dynamic>> _unsyncedEmbarques = [];
  List<Map<String, dynamic>> _unsyncedPagos = [];

  final Set<int> _uploadingIds = {}; // Para embarques individuales

  @override
  void initState() {
    super.initState();
    _loadLastSyncTimestamp();
    _loadUnsyncedData();
  }

  Future<void> _loadLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lastSyncTimestamp = prefs.getString('lastSyncTimestamp');
      });
    }
  }

  Future<void> _loadUnsyncedData() async {
    if (_isBulkUploading) return;
    setState(() { _isLoading = true; });
    try {
      final db = DatabaseHelper.instance;
      final embarquesData = await db.getUnsyncedEmbarques();
      final pagosData = await db.getPagosParaSincronizar();
      if (mounted) {
        setState(() {
          _unsyncedEmbarques = embarquesData;
          _unsyncedPagos = pagosData;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al cargar datos locales: $e');
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _prepararJornada() async {
    if (_isDownloading || _isBulkUploading) return;

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showConnectivitySnackBar('No hay conexión a internet para preparar la jornada.');
      return;
    }

    setState(() { _isDownloading = true; });
    
    showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) => const Dialog(child: Padding(padding: EdgeInsets.all(20.0), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Descargando datos...")]))));

    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getInt('idusuario');
      if (idUsuario == null) throw Exception('No se encontró el ID de usuario.');

      final url = Uri.parse('${ApiConfig.baseUrl}api_get_all_data_for_offline.php?idusuario=$idUsuario');
      final response = await http.get(url).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final db = DatabaseHelper.instance;

        await db.clearAllNotasData();

        if (data['notas'] != null && (data['notas'] as List).isNotEmpty) {
          for (var nota in (data['notas'] as List)) {
            await db.insertNotaOffline(Map<String, dynamic>.from(nota));
          }
        }
        if (data['detalles'] != null && (data['detalles'] as List).isNotEmpty) {
          await db.insertNotaDetallesOffline(List<Map<String, dynamic>>.from(data['detalles']));
        }
        if (data['pagos'] != null && (data['pagos'] as List).isNotEmpty) {
          await db.insertPagosOffline(List<Map<String, dynamic>>.from(data['pagos']));
        }

        final now = DateTime.now();
        final formattedTimestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
        await prefs.setString('lastSyncTimestamp', formattedTimestamp);
        if (mounted) {
          setState(() { _lastSyncTimestamp = formattedTimestamp; });
          Navigator.of(context).pop();
          _showSuccessSnackBar('✅ Jornada preparada con éxito.');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar('❌ Error al preparar jornada: $e');
      }
    } finally {
      if (mounted) setState(() { _isDownloading = false; });
    }
  }

  Future<bool> _subirEmbarque(int localId) async {
    if (_uploadingIds.contains(localId)) return false;
    setState(() { _uploadingIds.add(localId); });

    try {
      final db = DatabaseHelper.instance;
      final payload = await db.getFullEmbarque(localId);
      if (payload.isEmpty) throw Exception('No se pudo construir el payload para el embarque local ID: $localId');
      
      final url = Uri.parse('${ApiConfig.baseUrl}api_embarques.php');
      final response = await http.post(url, headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        await db.deleteLocalEmbarque(localId);
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error desconocido del servidor');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('❌ Error al subir Embarque ID $localId: $e');
      return false;
    } finally {
      if (mounted) setState(() { _uploadingIds.remove(localId); });
    }
  }

  Future<void> _subirTodoMasivamente() async {
    if (_isBulkUploading || (_unsyncedEmbarques.isEmpty && _unsyncedPagos.isEmpty)) return;

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showConnectivitySnackBar('No hay conexión a internet para sincronizar.');
      return;
    }

    setState(() { _isBulkUploading = true; });
    _showInfoSnackBar('Iniciando sincronización masiva...');

    // Subir Embarques
    int embarquesExitosos = 0;
    if (_unsyncedEmbarques.isNotEmpty) {
      final idsParaSubir = _unsyncedEmbarques.map((e) => e['idfolioembarque_local'] as int).toList();
      for (final id in idsParaSubir) {
        if (await _subirEmbarque(id)) {
          embarquesExitosos++;
        }
      }
    }

    // Subir Pagos
    int pagosExitosos = 0;
    if (_unsyncedPagos.isNotEmpty) {
      if (await _subirPagos()) {
        pagosExitosos = _unsyncedPagos.length;
      }
    }

    String summary = 'Sincronización completada. Embarques: $embarquesExitosos/${_unsyncedEmbarques.length}. Pagos: $pagosExitosos/${_unsyncedPagos.length}.';
    _showSuccessSnackBar(summary);

    if (mounted) {
      setState(() { _isBulkUploading = false; });
      await _loadUnsyncedData();
    }
  }

  Future<bool> _subirPagos() async {
    final db = DatabaseHelper.instance;
    final payload = {'pagos': _unsyncedPagos};

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_subir_pagos.php');
      final response = await http.post(url, headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 30));
      
      final decoded = json.decode(response.body);
      if (response.statusCode == 200 && decoded['success'] == true) {
        for (var pago in _unsyncedPagos) {
          await db.marcarPagoComoSincronizado(pago['id_pago_local']);
        }
        return true;
      } else {
        throw Exception(decoded['error'] ?? 'Error del servidor al subir pagos.');
      }
    } catch (e) {
      if(mounted) _showErrorSnackBar('Error al subir pagos: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasPendientes = _unsyncedEmbarques.isNotEmpty || _unsyncedPagos.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            tooltip: 'Subir Todo',
            onPressed: _isBulkUploading || _isDownloading || !hasPendientes ? null : _subirTodoMasivamente,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar Lista',
            onPressed: _isBulkUploading || _isDownloading ? null : _loadUnsyncedData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDownloadSection(),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !hasPendientes
                    ? _buildEmptyState()
                    : _buildMainList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Preparación de Jornada', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Descarga los datos más recientes del servidor para poder trabajar sin conexión.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download),
              label: const Text('Descargar Datos'),
              onPressed: _isDownloading || _isBulkUploading ? null : _prepararJornada,
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
            if (_isDownloading) const Padding(padding: EdgeInsets.only(top: 8.0), child: LinearProgressIndicator()),
            const SizedBox(height: 8),
            Center(child: Text(_lastSyncTimestamp != null ? 'Última actualización: $_lastSyncTimestamp' : 'Aún no se han descargado datos.', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainList() {
    return ListView(
      children: [
        if (_isBulkUploading) const LinearProgressIndicator(),
        if (_unsyncedEmbarques.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.all(16.0), child: Text('Embarques Pendientes', style: Theme.of(context).textTheme.titleLarge)),
          ..._unsyncedEmbarques.map((embarque) => _buildEmbarqueItem(embarque)).toList(),
        ],
        if (_unsyncedPagos.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text('Pagos Pendientes', style: Theme.of(context).textTheme.titleLarge)),
          ..._unsyncedPagos.map((pago) => _buildPagoItem(pago)).toList(),
        ],
      ],
    );
  }

  Widget _buildEmbarqueItem(Map<String, dynamic> embarque) {
    final int localId = embarque['idfolioembarque_local'];
    final bool isUploading = _uploadingIds.contains(localId);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined, color: Colors.blueGrey, size: 40),
        title: Text('Embarque - Cliente: ${embarque['nombrecliente'] ?? 'Desconocido'}'),
        subtitle: Text('ID Local: $localId \nFecha: ${_formatTimestamp(embarque['regtimestamp'])}'),
        isThreeLine: true,
        trailing: isUploading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
      ),
    );
  }

  Widget _buildPagoItem(Map<String, dynamic> pago) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ListTile(
        leading: const Icon(Icons.monetization_on_outlined, color: Colors.green, size: 40),
        title: Text('Pago para Nota #${pago['idnota']}'),
        subtitle: Text('Monto: ${currencyFormat.format(pago['monto'])} \nFecha: ${_formatTimestamp(pago['regtimestamp'])}'),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done_rounded, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          const Text('Todo está sincronizado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('No hay datos pendientes por subir.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Refrescar'), onPressed: _loadUnsyncedData)
        ],
      ),
    );
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Fecha desconocida';
    try {
      final DateTime date = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  void _showConnectivitySnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }
  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.blue));
  }
}