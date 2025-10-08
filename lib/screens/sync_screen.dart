import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:distribuidora/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _unsyncedEmbarques = [];
  final Set<int> _uploadingIds = {}; // Para rastrear qué embarques se están subiendo

  @override
  void initState() {
    super.initState();
    _loadUnsyncedEmbarques();
  }

  Future<void> _loadUnsyncedEmbarques() async {
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

  Future<void> _subirEmbarque(int localId) async {
    if (_uploadingIds.contains(localId)) return; // Ya se está subiendo

    setState(() {
      _uploadingIds.add(localId);
    });

    try {
      final db = DatabaseHelper.instance;
      final payload = await db.getFullEmbarque(localId);

      if (payload.isEmpty) {
        throw Exception('No se pudo construir el payload para el embarque local ID: $localId');
      }

      // Usamos la misma API de la pantalla de embarques
      const String baseUrl = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/';
      final url = Uri.parse('${baseUrl}api_embarques.php');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        // Éxito: borrar el registro local
        await db.deleteLocalEmbarque(localId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Embarque subido y sincronizado!'), backgroundColor: Colors.green),
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error desconocido del servidor');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al subir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingIds.remove(localId);
        });
        // Refrescar la lista para quitar el elemento subido
        await _loadUnsyncedEmbarques();
      }
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
            onPressed: () {
              // TODO: Implementar lógica de subir todo
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar Lista',
            onPressed: _loadUnsyncedEmbarques,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unsyncedEmbarques.isEmpty
              ? _buildEmptyState()
              : _buildListView(),
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
                    onPressed: () => _subirEmbarque(localId),
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
}