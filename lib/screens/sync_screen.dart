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
      return isoString; // Devuelve el original si falla el parseo
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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          child: ListTile(
            leading: const Icon(Icons.cloud_off_rounded, color: Colors.blueGrey, size: 40),
            title: Text('Cliente: ${embarque['nombrecliente'] ?? 'Desconocido'}'),
            subtitle: Text('ID Local: ${embarque['idfolioembarque_local']} \nFecha: ${_formatTimestamp(embarque['regtimestamp'])}'),
            isThreeLine: true,
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.upload, size: 18),
              label: const Text('Subir'),
              onPressed: () {
                // TODO: Implementar lógica para subir un solo embarque
              },
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