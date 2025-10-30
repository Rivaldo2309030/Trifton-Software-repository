import 'dart:convert';
import 'dart:io'; // Import for SocketException
import 'package:distribuidora/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:distribuidora/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import for connectivity_plus

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isLoading = true;
  bool _isBulkUploading = false; // Para el estado de subida masiva
  List<Map<String, dynamic>> _unsyncedEmbarques = [];
  final Set<int> _uploadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadUnsyncedEmbarques();
  }

  Future<void> _loadUnsyncedEmbarques() async {
    if (_isBulkUploading) return; // No refrescar si se está en subida masiva
    setState(() { _isLoading = true; });
    try {
      final db = DatabaseHelper.instance;
      final data = await db.getUnsyncedEmbarques();
      if (mounted) {
        setState(() {
          _unsyncedEmbarques = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar embarques locales: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
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

  Future<bool> _subirEmbarque(int localId, {bool refreshList = true}) async {
    if (_uploadingIds.contains(localId) || _isBulkUploading && refreshList) return false;

    setState(() {
      _uploadingIds.add(localId);
    });

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showConnectivitySnackBar('No hay conexión a internet. No se pudo subir el embarque ID $localId.');
      if (mounted) {
        setState(() {
          _uploadingIds.remove(localId);
        });
      }
      return false;
    }

    bool success = false;
    try {
      final db = DatabaseHelper.instance;
      final payload = await db.getFullEmbarque(localId);

      if (payload.isEmpty) {
        throw Exception('No se pudo construir el payload para el embarque local ID: $localId');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}api_embarques.php');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        await db.deleteLocalEmbarque(localId);
        if (refreshList) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Embarque subido y sincronizado!'), backgroundColor: Colors.green),
            );
          }
        }
        success = true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error desconocido del servidor');
      }
    } on SocketException {
      if (mounted && refreshList) {
        _showConnectivitySnackBar('No se pudo conectar al servidor para subir el embarque ID $localId. Verifica tu conexión a internet.');
      }
    } catch (e) {
      if (mounted && refreshList) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error al subir ID $localId: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingIds.remove(localId);
        });
        if (refreshList) {
          await _loadUnsyncedEmbarques();
        }
      }
    }
    return success;
  }

  Future<void> _subirTodo() async {
    if (_isBulkUploading || _unsyncedEmbarques.isEmpty) return;

    setState(() { _isBulkUploading = true; });

    final idsParaSubir = _unsyncedEmbarques.map((e) => e['idfolioembarque_local'] as int).toList();
    int exitosos = 0;
    int fallidos = 0;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Iniciando subida masiva de ${idsParaSubir.length} embarques...'), backgroundColor: Colors.blue),
      );
    }

    for (final id in idsParaSubir) {
      final success = await _subirEmbarque(id, refreshList: false);
      if (success) {
        exitosos++;
      } else {
        fallidos++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronización completada. Éxito: $exitosos, Fallidos: $fallidos'), backgroundColor: fallidos > 0 ? Colors.orange : Colors.green),
      );
    }

    if (mounted) {
      setState(() { _isBulkUploading = false; });
      await _loadUnsyncedEmbarques();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización Pendiente'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            tooltip: 'Subir Todo',
            onPressed: _isBulkUploading ? null : _subirTodo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar Lista',
            onPressed: _isBulkUploading ? null : _loadUnsyncedEmbarques,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isBulkUploading) const LinearProgressIndicator(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _unsyncedEmbarques.isEmpty
                    ? _buildEmptyState()
                    : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _unsyncedEmbarques.length,
      itemBuilder: (context, index) {
        final embarque = _unsyncedEmbarques[index];
        final int localId = embarque['idfolioembarque_local'];
        final bool isUploading = _uploadingIds.contains(localId);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          child: ListTile(
            leading: const Icon(Icons.cloud_off_rounded, color: Colors.blueGrey, size: 40),
            title: Text('Cliente: ${embarque['nombrecliente'] ?? 'Desconocido'}'),
            subtitle: Text('ID Local: $localId \nFecha: ${_formatTimestamp(embarque['regtimestamp'])}'),
            isThreeLine: true,
            trailing: isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Subir'),
                    onPressed: _isBulkUploading ? null : () => _subirEmbarque(localId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done_rounded, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Todo está sincronizado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text('No hay embarques pendientes por subir.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refrescar'),
            onPressed: _loadUnsyncedEmbarques,
          )
        ],
      ),
    );
  }

  void _showConnectivitySnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}