import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pago_screen.dart';

/// ===== Servicio de persistencia local =====
class _PedidoStore {
  static const _k = 'pedidos_data';

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k);
    if (raw == null || raw.isEmpty) return [];
    final List list = jsonDecode(raw);
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> saveAll(List<Map<String, dynamic>> pedidos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k, jsonEncode(pedidos));
  }

  static Future<void> upsert(Map<String, dynamic> pedido) async {
    final list = await load();
    final idx = list.indexWhere((p) => p['id'] == pedido['id']);
    if (idx >= 0) {
      list[idx] = pedido;
    } else {
      list.add(pedido);
    }
    await saveAll(list);
  }

  static Future<void> removeById(dynamic id) async {
    final list = await load();
    list.removeWhere((p) => p['id'] == id);
    await saveAll(list);
  }
}

/// ===== Catálogos (nombres reales de ejemplo) =====
const List<String> _almacenesCatalogo = <String>[
  'Matriz Cancún',
  'Sucursal Mérida',
  'Centro CDMX',
];

const List<String> _clientesCatalogo = <String>[
  'Grupo Sol Naciente',
  'Ferretería La Paz',
  'Hotel Chichén Resort',
  'Constructora Mayab',
  'Servicios Riviera',
];

const List<String> _unidadesCatalogo = <String>[
  'Bulto',
  'Caja',
  'Pieza',
  'Kilo',
];

/// Productos de referencia (sugerencias para autocompletar)
const List<String> _productosSugeridos = <String>[
  'Cemento Gris 50kg',
  'Varilla 3/8"',
  'Arena Fina m³',
  'Grava 3/4 m³',
  'Pintura Vinílica 19L',
  'Yeso 25kg',
  'Adhesivo cerámico 20kg',
  'Cable THW 12 AWG',
  'Tubo PVC 1"',
  'Mortero Impermeabilizante 20kg',
];

class PedidosScreen extends StatefulWidget {
  final List<Map<String, dynamic>> pedidos;
  const PedidosScreen({super.key, this.pedidos = const []});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  // --- Filtros de listado ---
  String? almacenFiltro = '';
  String? clienteFiltro = '';
  String? unidadFiltro = '';
  String textoBusqueda = '';

  final ScrollController _tableHCtrl = ScrollController();
  final ScrollController _dialogTableHCtrl = ScrollController();

  // --- Estado general ---
  List<Map<String, dynamic>> _pedidos = [];
  bool _cargando = true;

  // --- Constructor de pedido (nuevo pedido en curso) ---
  String? _almacenSel = '';
  String? _clienteSel = '';
  String? _unidadSel = '';

  final TextEditingController _productoCtrl = TextEditingController();
  final TextEditingController _precioCtrl = TextEditingController();

  // Ítems (líneas) del pedido actual
  final List<Map<String, dynamic>> _itemsActuales = [];

  @override
  void initState() {
    super.initState();
    _cargarYFusionar();
  }

  Future<void> _cargarYFusionar() async {
    final guardados = await _PedidoStore.load();

    // Normaliza entrantes
    final entrantes = widget.pedidos
        .map(
          (p) => {
            ...p,
            'estado': (p['estado']?.toString() ?? 'Pendiente'),
            'productos': List<Map<String, dynamic>>.from(
              (p['productos'] as List?) ?? [],
            ),
          },
        )
        .toList();

    // Fusionar por id
    final mapa = <dynamic, Map<String, dynamic>>{
      for (final p in guardados)
        p['id']: {
          ...p,
          'estado': (p['estado']?.toString() ?? 'Pendiente'),
          'productos': List<Map<String, dynamic>>.from(
            (p['productos'] as List?) ?? [],
          ),
        },
    };
    for (final p in entrantes) {
      mapa[p['id']] = p;
    }

    _pedidos = mapa.values.toList();
    await _PedidoStore.saveAll(_pedidos);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _persistir() async => _PedidoStore.saveAll(_pedidos);

  List<String> get almacenes {
    final set = {
      ..._almacenesCatalogo,
      for (var p in _pedidos)
        if (p['almacen'] != null) p['almacen'].toString(),
    };
    return set.toList();
  }

  List<String> get clientes {
    final set = {
      ..._clientesCatalogo,
      for (var p in _pedidos)
        if (p['cliente'] != null) p['cliente'].toString(),
    };
    return set.toList();
  }

  List<String> get unidades {
    final set = {
      ..._unidadesCatalogo,
      for (var p in _pedidos)
        if (p['unidad'] != null) p['unidad'].toString(),
    };
    return set.toList();
  }

  List<Map<String, dynamic>> get pedidosFiltrados {
    return _pedidos.where((pedido) {
      final matchAlmacen =
          almacenFiltro == null ||
          almacenFiltro!.isEmpty ||
          pedido['almacen'] == almacenFiltro;
      final matchCliente =
          clienteFiltro == null ||
          clienteFiltro!.isEmpty ||
          pedido['cliente'] == clienteFiltro;
      final matchUnidad =
          unidadFiltro == null ||
          unidadFiltro!.isEmpty ||
          pedido['unidad'] == unidadFiltro;
      final matchTexto =
          textoBusqueda.isEmpty ||
          pedido['id'].toString().toLowerCase().contains(
            textoBusqueda.toLowerCase(),
          ) ||
          (pedido['cliente']?.toString().toLowerCase().contains(
                textoBusqueda.toLowerCase(),
              ) ??
              false);
      return matchAlmacen && matchCliente && matchUnidad && matchTexto;
    }).toList();
  }

  @override
  void dispose() {
    _tableHCtrl.dispose();
    _dialogTableHCtrl.dispose();
    _productoCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleEstado(Map<String, dynamic> pedido) async {
    setState(() {
      final actual = (pedido['estado'] ?? 'Pendiente').toString();
      pedido['estado'] = actual == 'Pendiente' ? 'Autorizado' : 'Pendiente';
    });
    await _persistir();
  }

  // ==== APLICAR LIMPIEZA TRAS PAGO ====
  Future<void> _aplicarPago({
    required dynamic idPedido,
    required List<Map<String, dynamic>> itemsPagados,
    required double montoPagado,
  }) async {
    final idx = _pedidos.indexWhere((p) => p['id'] == idPedido);
    if (idx < 0) return;

    final pedido = _pedidos[idx];
    final productos = List<Map<String, dynamic>>.from(
      (pedido['productos'] as List?) ?? [],
    );

    // Eliminar productos pagados (match por nombre, unidad, precio y cantidad)
    for (final pag in itemsPagados) {
      productos.removeWhere(
        (p) =>
            (p['nombre'] ?? '') == (pag['nombre'] ?? '') &&
            (p['unidad'] ?? '') == (pag['unidad'] ?? '') &&
            (p['precio'] ?? 0) == (pag['precio'] ?? 0) &&
            (p['cantidad'] ?? 0) == (pag['cantidad'] ?? 0),
      );
    }

    // Recalcular total del pedido
    final nuevoTotal = productos.fold<num>(
      0,
      (s, p) => s + ((p['cantidad'] ?? 0) as num) * ((p['precio'] ?? 0) as num),
    );

    if (productos.isEmpty) {
      final eliminado = _pedidos.removeAt(idx);
      await _PedidoStore.removeById(eliminado['id']);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido liquidado y removido de la lista.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
      return;
    } else {
      _pedidos[idx] = {
        ...pedido,
        'productos': productos,
        'total': (nuevoTotal).toDouble(),
        'estado': 'Autorizado',
      };
    }

    setState(() {});
    await _persistir();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pago aplicado: ${itemsPagados.length} ítem(s).'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  void _goToPago({
    required Map<String, dynamic> pedido,
    required List<Map<String, dynamic>> productosSeleccionados,
  }) async {
    final total = productosSeleccionados.fold<num>(
      0,
      (s, p) => s + ((p['cantidad'] ?? 0) as num) * ((p['precio'] ?? 0) as num),
    );

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => PagoScreen(
          pedido: pedido,
          productosSeleccionados: productosSeleccionados,
          total: total.toDouble(),
        ),
      ),
    );

    if (result != null && result['pagado'] == true) {
      final itemsPagados = (result['itemsPagados'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final monto = (result['monto'] as num?)?.toDouble() ?? 0.0;
      await _aplicarPago(
        idPedido: pedido['id'],
        itemsPagados: itemsPagados,
        montoPagado: monto,
      );
    }
  }

  Future<void> _confirmarEliminar(dynamic id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('¿Seguro que deseas eliminar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _pedidos.removeWhere((p) => p['id'] == id));
      await _PedidoStore.removeById(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido eliminado'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ====== LÓGICA DEL CONSTRUCTOR DE PEDIDO ======
  void _agregarItemActual() {
    final prod = _productoCtrl.text.trim();
    final precioTxt = _precioCtrl.text.trim().replaceAll(',', '.');

    if ((_almacenSel ?? '').isEmpty) {
      _toastWarn('Selecciona un almacén');
      return;
    }
    if ((_clienteSel ?? '').isEmpty) {
      _toastWarn('Selecciona un cliente');
      return;
    }
    if ((_unidadSel ?? '').isEmpty) {
      _toastWarn('Selecciona una unidad');
      return;
    }
    if (prod.isEmpty) {
      _toastWarn('Escribe el nombre del producto');
      return;
    }
    final precio = double.tryParse(precioTxt) ?? -1;
    if (precio <= 0) {
      _toastWarn('Ingresa un precio válido');
      return;
    }

    setState(() {
      _itemsActuales.add({
        'nombre': prod,
        'unidad': _unidadSel,
        'precio': precio,
        'cantidad': 1.0,
      });
      _productoCtrl.clear();
      _precioCtrl.clear();
    });
  }

  void _imprimirTicket() {
    // TODO: genera/abre el ticket y mándalo a imprimir o a PDF
    // Ej: _generarYMostrarPdfTicket(pedidoActual);
  }

  void _guardarPedidoActual() async {
    if ((_almacenSel ?? '').isEmpty || (_clienteSel ?? '').isEmpty) {
      _toastWarn('Selecciona almacén y cliente');
      return;
    }
    if (_itemsActuales.isEmpty) {
      _toastWarn('Agrega al menos un ítem');
      return;
    }

    final total = _itemsActuales.fold<num>(
      0,
      (s, p) => s + ((p['cantidad'] ?? 0) as num) * ((p['precio'] ?? 0) as num),
    );

    final nuevo = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'cliente': _clienteSel,
      'almacen': _almacenSel,
      'unidad': _unidadSel, // unidad general elegida
      'fecha': DateTime.now().toString().substring(0, 19),
      'estado': 'Pendiente',
      'total': (total).toDouble(),
      'productos': _itemsActuales
          .map(
            (e) => {
              'nombre': e['nombre'],
              'unidad': e['unidad'],
              'precio': e['precio'],
              'cantidad': e['cantidad'],
            },
          )
          .toList(),
    };

    setState(() {
      _pedidos.insert(0, nuevo);
      _itemsActuales.clear();
    });
    await _persistir();

    _toastOk('Pedido guardado (#${nuevo['id']})');
  }

  void _cambiarCantidadItem(int index, double delta) {
    setState(() {
      final actual =
          (_itemsActuales[index]['cantidad'] as num?)?.toDouble() ?? 0.0;
      final nuevo = (actual + delta).clamp(0.0, 999999.0);
      _itemsActuales[index]['cantidad'] = nuevo;
      if (nuevo == 0.0) {
        _itemsActuales.removeAt(index);
      }
    });
  }

  double _totalActual() {
    return _itemsActuales.fold<double>(
      0.0,
      (s, p) =>
          s +
          ((p['cantidad'] ?? 0) as num).toDouble() *
              ((p['precio'] ?? 0) as num).toDouble(),
    );
  }

  void _toastWarn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange),
    );
  }

  void _toastOk(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF059669)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // evita overflow con teclado mostrando scroll
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F8FB), Color(0xFFE9EDF3)],
          ),
        ),
        child: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double w = constraints.maxWidth;
                    final bool isSmall = w < 700;
                    final bool isMedium = w >= 700 && w < 1100;
                    final double fieldWidth = isSmall
                        ? w
                        : (isMedium ? (w - 64) / 2 : (w - 96) / 3);

                    // ====== Usamos ListView para evitar overflow vertical ======
                    return ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _HeaderTitlePedidos(),
                        ),
                        const SizedBox(height: 12),

                        // ================= CONSTRUCTOR DE PEDIDO =================
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _CardWrap(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // FILA DE SELECCIONES
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _buildFilterDropdown(
                                        value: _almacenSel ?? '',
                                        items: almacenes,
                                        hint: 'Selecciona un almacén',
                                        label: 'Almacén',
                                        icon:
                                            Icons.store_mall_directory_outlined,
                                        onChanged: (v) =>
                                            setState(() => _almacenSel = v),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _buildFilterDropdown(
                                        value: _clienteSel ?? '',
                                        items: clientes,
                                        hint: 'Selecciona un cliente',
                                        label: 'Cliente',
                                        icon: Icons.person_outline,
                                        onChanged: (v) =>
                                            setState(() => _clienteSel = v),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _buildFilterDropdown(
                                        value: _unidadSel ?? '',
                                        items: unidades,
                                        hint: 'Selecciona una unidad',
                                        label: 'Unidad',
                                        icon: Icons.inventory_2_outlined,
                                        onChanged: (v) =>
                                            setState(() => _unidadSel = v),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // BUSCADOR DE PRODUCTO + PRECIO + AGREGAR
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: isSmall
                                          ? w
                                          : (isMedium
                                                ? fieldWidth
                                                : (fieldWidth * 2 + 16)),
                                      child: _ProductoAutocomplete(
                                        controller: _productoCtrl,
                                        label: 'Producto',
                                        hint: 'Escribe el nombre del producto…',
                                      ),
                                    ),
                                    SizedBox(
                                      width: isSmall ? w : fieldWidth / 2,
                                      child: TextField(
                                        controller: _precioCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: 'Precio',
                                          hintText: '0.00',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                                borderSide: BorderSide(
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          prefixIcon: const Icon(
                                            Icons.sell_outlined,
                                            color: Color(0xFF64748B),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _agregarItemActual,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Agregar ítem'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF3B82F6,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // TABLA DE ÍTEMS ACTUALES
                                if (_itemsActuales.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: const Text(
                                      'Agrega productos para este pedido.',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  )
                                else
                                  _TablaItemsActuales(
                                    items: _itemsActuales,
                                    onInc: (i) => _cambiarCantidadItem(i, 1),
                                    onDec: (i) => _cambiarCantidadItem(i, -1),
                                    onRemove: (i) => setState(
                                      () => _itemsActuales.removeAt(i),
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                // FOOTER DEL CONSTRUCTOR
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Total actual: \$${_totalActual().toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _guardarPedidoActual,
                                      icon: const Icon(Icons.save),
                                      label: const Text('Guardar pedido'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF10B981,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _imprimirTicket,
                                      icon: const Icon(Icons.print),
                                      label: const Text('Imprimir ticket'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1A4F91,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ================= FILTROS + BÚSQUEDA LISTADO =================
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _CardWrap(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _buildFilterDropdown(
                                        value: clienteFiltro ?? '',
                                        items: clientes,
                                        hint: 'Todos los clientes',
                                        label: 'Cliente (filtro)',
                                        icon: Icons.person_outline,
                                        onChanged: (v) =>
                                            setState(() => clienteFiltro = v),
                                      ),
                                    ),
                                    SizedBox(
                                      width: isSmall
                                          ? w
                                          : (isMedium
                                                ? fieldWidth * 2 + 16
                                                : fieldWidth * 3 + 32),
                                      child: TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Buscar pedido',
                                          hintText: 'ID o nombre de cliente...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                                borderSide: BorderSide(
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Color(0xFF64748B),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                        ),
                                        onChanged: (v) =>
                                            setState(() => textoBusqueda = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // RESUMEN + LIMPIAR
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${pedidosFiltrados.length} pedido${pedidosFiltrados.length != 1 ? 's' : ''} encontrado${pedidosFiltrados.length != 1 ? 's' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if ((almacenFiltro ?? '').isNotEmpty ||
                                  (clienteFiltro ?? '').isNotEmpty ||
                                  (unidadFiltro ?? '').isNotEmpty ||
                                  textoBusqueda.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    almacenFiltro = '';
                                    clienteFiltro = '';
                                    unidadFiltro = '';
                                    textoBusqueda = '';
                                  }),
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Limpiar filtros'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ================= TABLA DE PEDIDOS GUARDADOS =================
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: pedidosFiltrados.isEmpty
                              ? _buildEmptyState()
                              : _CardWrap(
                                  child: Scrollbar(
                                    controller: _tableHCtrl,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      controller: _tableHCtrl,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: w,
                                        ),
                                        child: DataTable(
                                          columnSpacing: 24,
                                          horizontalMargin: 16,
                                          dataRowMinHeight: 60,
                                          dataRowMaxHeight: 72,
                                          headingRowHeight: 56,
                                          headingRowColor:
                                              WidgetStateProperty.resolveWith(
                                                (_) => const Color(0xFFF1F5F9),
                                              ),
                                          headingTextStyle: const TextStyle(
                                            color: Color(0xFF334155),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          columns: const [
                                            DataColumn(label: Text('ID')),
                                            DataColumn(label: Text('Cliente')),
                                            DataColumn(label: Text('Almacén')),
                                            DataColumn(label: Text('Unidad')),
                                            DataColumn(label: Text('Fecha')),
                                            DataColumn(label: Text('Estado')),
                                            DataColumn(label: Text('Total')),
                                            DataColumn(
                                              label: Text('Productos'),
                                            ),
                                            DataColumn(label: Text('Acciones')),
                                          ],
                                          rows: pedidosFiltrados.map((pedido) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    '#${pedido['id']}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    pedido['cliente']
                                                            ?.toString() ??
                                                        'N/A',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    pedido['almacen']
                                                            ?.toString() ??
                                                        'N/A',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    pedido['unidad']
                                                            ?.toString() ??
                                                        'N/A',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    pedido['fecha']
                                                            ?.toString() ??
                                                        'N/A',
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () =>
                                                        _toggleEstado(pedido),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _getEstadoColor(
                                                          pedido['estado'],
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            (pedido['estado'] ??
                                                                        '') ==
                                                                    'Autorizado'
                                                                ? Icons.verified
                                                                : Icons
                                                                      .hourglass_bottom,
                                                            size: 16,
                                                            color: _getEstadoColor(
                                                              pedido['estado'],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            (pedido['estado'] ??
                                                                    'N/A')
                                                                .toString(),
                                                            style: TextStyle(
                                                              color: _getEstadoColor(
                                                                pedido['estado'],
                                                              ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '\$${(pedido['total'] is num) ? (pedido['total'] as num).toStringAsFixed(2) : '0.00'}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF059669),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Tooltip(
                                                    message: 'Ver productos',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.inventory_2,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF3B82F6,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '${(pedido['productos'] as List?)?.length ?? 0}',
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF3B82F6,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.remove_red_eye,
                                                          size: 20,
                                                        ),
                                                        color: const Color(
                                                          0xFF3B82F6,
                                                        ),
                                                        onPressed: () =>
                                                            _mostrarDetallePedido(
                                                              context,
                                                              pedido,
                                                            ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.attach_money,
                                                          size: 20,
                                                        ),
                                                        color: const Color(
                                                          0xFF059669,
                                                        ),
                                                        tooltip: 'Pagar',
                                                        onPressed: () =>
                                                            _mostrarDetallePedido(
                                                              context,
                                                              pedido,
                                                              abrirPagoDirecto:
                                                                  true,
                                                            ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 20,
                                                        ),
                                                        color: const Color(
                                                          0xFFEF4444,
                                                        ),
                                                        tooltip: 'Eliminar',
                                                        onPressed: () =>
                                                            _confirmarEliminar(
                                                              pedido['id'],
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
    );
  }

  // ------- Widgets auxiliares -------
  Widget _buildFilterDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required String label,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: (value == null || value.isEmpty) ? '' : value,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
          ),
          items: [
            DropdownMenuItem(value: '', child: Text(hint)),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron pedidos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Intenta ajustar los filtros o términos de búsqueda',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                almacenFiltro = '';
                clienteFiltro = '';
                unidadFiltro = '';
                textoBusqueda = '';
              }),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Restablecer filtros'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getEstadoColor(String? estado) {
    switch (estado) {
      case 'Autorizado':
      case 'Completado':
        return const Color(0xFF059669);
      case 'Pendiente':
        return const Color(0xFFF59E0B);
      case 'Cancelado':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _mostrarDetallePedido(
    BuildContext context,
    Map<String, dynamic> pedido, {
    bool abrirPagoDirecto = false,
  }) {
    final size = MediaQuery.of(context).size;

    final productos = List<Map<String, dynamic>>.from(
      (pedido['productos'] as List?) ?? [],
    );
    final seleccionados = <int>{};

    num calcularTotalSel() {
      return seleccionados.fold<num>(
        0,
        (s, idx) =>
            s +
            (((productos[idx]['cantidad'] ?? 0) as num) *
                ((productos[idx]['precio'] ?? 0) as num)),
      );
    }

    void abrirPago() {
      final itemsSeleccionados = seleccionados
          .map((i) => productos[i])
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      if (itemsSeleccionados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona al menos un producto para pagar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      Navigator.pop(context);
      _goToPago(pedido: pedido, productosSeleccionados: itemsSeleccionados);
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) {
          if (abrirPagoDirecto &&
              productos.isNotEmpty &&
              seleccionados.isEmpty) {
            for (var i = 0; i < productos.length; i++) {
              seleccionados.add(i);
            }
          }
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 760,
                maxHeight: size.height * 0.9,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: double.maxFinite,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Pedido #${pedido['id']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Estado: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            await _toggleEstado(pedido);
                            setDialog(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getEstadoColor(
                                pedido['estado'],
                              ).withOpacity(.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (pedido['estado'] ?? '') == 'Autorizado'
                                      ? Icons.verified
                                      : Icons.hourglass_bottom,
                                  size: 16,
                                  color: _getEstadoColor(pedido['estado']),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (pedido['estado'] ?? '').toString(),
                                  style: TextStyle(
                                    color: _getEstadoColor(pedido['estado']),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            await _toggleEstado(pedido);
                            setDialog(() {});
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(
                            (pedido['estado'] ?? '') == 'Pendiente'
                                ? 'Quitar Pendiente → Autorizado'
                                : 'Quitar Autorizado → Pendiente',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'SELECCIONA LO QUE COMPRARÁS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Scrollbar(
                        controller: _dialogTableHCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _dialogTableHCtrl,
                          child: Column(
                            children: [
                              Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(44),
                                  1: FlexColumnWidth(3),
                                  2: FlexColumnWidth(1),
                                  3: FlexColumnWidth(1.2),
                                  4: FlexColumnWidth(1.2),
                                },
                                children: [
                                  const TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE5E7EB),
                                        ),
                                      ),
                                    ),
                                    children: [
                                      SizedBox(),
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Producto',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Cantidad',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Precio',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Total',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ...List.generate(productos.length, (i) {
                                    final p = productos[i];
                                    final cantidad =
                                        (p['cantidad'] ?? 0) as num;
                                    final precio = (p['precio'] ?? 0) as num;
                                    final total = cantidad * precio;
                                    return TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFF1F5F9),
                                          ),
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Checkbox(
                                            value: seleccionados.contains(i),
                                            onChanged: (v) => setDialog(() {
                                              if (v == true) {
                                                seleccionados.add(i);
                                              } else {
                                                seleccionados.remove(i);
                                              }
                                            }),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            p['nombre']?.toString() ??
                                                'Producto',
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(cantidad.toString()),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            '\$${precio.toStringAsFixed(2)}',
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            '\$${total.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Footer
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total seleccionado: \$${calcularTotalSel().toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setDialog(() {
                            if (seleccionados.length == productos.length) {
                              seleccionados.clear();
                            } else {
                              seleccionados
                                ..clear()
                                ..addAll(
                                  List.generate(productos.length, (i) => i),
                                );
                            }
                          }),
                          child: Text(
                            seleccionados.length == productos.length
                                ? 'Deseleccionar todo'
                                : 'Seleccionar todo',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: abrirPago,
                          icon: const Icon(Icons.payment),
                          label: const Text('Pagar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ======= Autocomplete de Producto =======
class _ProductoAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _ProductoAutocomplete({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue v) {
        final q = v.text.toLowerCase().trim();
        if (q.isEmpty) return const Iterable<String>.empty();
        return _productosSugeridos.where((p) => p.toLowerCase().contains(q));
      },
      onSelected: (s) => controller.text = s,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // Mantén el controller externo
            textEditingController.value = controller.value;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final opt = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(opt),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======= Tabla de ítems actuales (cantidad editable) =======
class _TablaItemsActuales extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(int) onInc;
  final void Function(int) onDec;
  final void Function(int) onRemove;

  const _TablaItemsActuales({
    required this.items,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Producto',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Unidad',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Precio',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Cantidad',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),
          ...List.generate(items.length, (i) {
            final it = items[i];
            final precio = (it['precio'] as num?)?.toDouble() ?? 0.0;
            final cant = (it['cantidad'] as num?)?.toDouble() ?? 0.0;
            final total = precio * cant;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(it['nombre']?.toString() ?? ''),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(it['unidad']?.toString() ?? ''),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('\$${precio.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => onDec(i),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(cant.toStringAsFixed(cant % 1 == 0 ? 0 : 2)),
                        IconButton(
                          onPressed: () => onInc(i),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${total.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemove(i),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF4444),
                    ),
                    tooltip: 'Quitar',
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ======= Título moderno =======
class _HeaderTitlePedidos extends StatelessWidget {
  const _HeaderTitlePedidos();

  @override
  Widget build(BuildContext context) {
    final Color a = const Color(0xFF4C6FFF);
    final Color b = const Color(0xFF22C1C3);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [a, b]),
            boxShadow: [
              BoxShadow(
                color: a.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.assignment_turned_in_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GradientText(
                'Pedidos',
                gradient: LinearGradient(colors: [a, b]),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Arma pedidos rápidos y gestiona pagos',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  const _GradientText(
    this.text, {
    required this.gradient,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

class _CardWrap extends StatelessWidget {
  final Widget child;
  const _CardWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
