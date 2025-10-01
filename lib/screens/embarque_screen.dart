import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Model classes for the catalog data
class Almacen {
  final int id;
  final String nombre;
  Almacen({required this.id, required this.nombre});

  factory Almacen.fromJson(Map<String, dynamic> json) {
    final idValue = json['idalmacen'];
    return Almacen(
      id: idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0,
      nombre: json['nombre_almacen'],
    );
  }
}

class Unidad {
  final int id;
  final String nombre;
  Unidad({required this.id, required this.nombre});

  factory Unidad.fromJson(Map<String, dynamic> json) {
    final idValue = json['idunidad'];
    return Unidad(
      id: idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0,
      nombre: json['nombre_unidad'],
    );
  }
}

class Producto {
  final int id;
  final String nombre;
  final double precioStock;

  Producto({required this.id, required this.nombre, required this.precioStock});
}


class EmbarqueScreen extends StatefulWidget {
  const EmbarqueScreen({super.key});

  @override
  State<EmbarqueScreen> createState() => _EmbarqueScreenState();
}

class _EmbarqueScreenState extends State<EmbarqueScreen> {
  // --- Catalogos (dinamicos) ---
  List<Almacen> _almacenes = [];
  List<Unidad> _unidades = [];
  bool _isLoading = true;

  // Mock data for other dropdowns until their APIs are ready
  final List<String> almacenistas = const ['Arturo Gómez', 'María Pérez'];
  final List<String> clientes = const ['Walmart', 'OXXO', 'Chedraui'];

  // --- NUEVOS CATALOGOS DE EJEMPLO ---
  final List<String> camiones = const ['Triton #1 - Juan Perez', 'Torton #5 - Miguel Lopez', 'Camioneta #2 - Luis Angel'];
  final List<String> tiposDeMovimiento = const ['Entrada a Bodega', 'Salida a Cliente', 'Traspaso entre Almacenes'];

  // --- CATALOGO DE PRODUCTOS DE EJEMPLO (Paso 2) ---
  final List<Producto> _productosDeEjemplo = [
    Producto(id: 101, nombre: 'Cemento Gris 50kg', precioStock: 250.00),
    Producto(id: 102, nombre: 'Varilla 3/8"', precioStock: 180.50),
    Producto(id: 103, nombre: 'Arena Fina m³', precioStock: 450.00),
    Producto(id: 104, nombre: 'Grava 3/4 m³', precioStock: 480.00),
    Producto(id: 105, nombre: 'Pintura Vinílica 19L', precioStock: 950.00),
  ];

  // --- Estado de filtros/encabezado ---
  int? _selectedAlmacenId;
  String? almacenista;
  int? _selectedUnidadId;
  String? cliente;

  // --- NUEVOS CAMPOS REQUERIDOS POR JUNTA ---
  String? _selectedCamion;
  String? _selectedTipoMovimiento;
  final TextEditingController _cancelacionCtrl = TextEditingController();

  // --- ESTADO PARA NUEVA SELECCION DE PRODUCTOS ---
  Producto? _selectedProducto;

  // --- Controles para agregar producto ---
  final TextEditingController cantidadCtrl = TextEditingController(text: '1');

  // --- Lista de renglones en la tabla ---
  final List<Map<String, dynamic>> filas = [];

  @override
  void initState() {
    super.initState();
    _fetchCatalogos();
  }

  @override
  void dispose() {
    _cancelacionCtrl.dispose();
    cantidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCatalogos() async {
    setState(() { _isLoading = true; });
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/api_almacenes.php')),
        http.get(Uri.parse('https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/api_unidades.php')),
      ]);

      if (mounted) { // Check if the widget is still in the tree
        if (responses[0].statusCode == 200) {
          final List<dynamic> data = json.decode(responses[0].body);
          _almacenes = data.map((json) => Almacen.fromJson(json)).toList();
        } else {
          throw Exception('Failed to load almacenes');
        }

        if (responses[1].statusCode == 200) {
          final List<dynamic> data = json.decode(responses[1].body);
          _unidades = data.map((json) => Unidad.fromJson(json)).toList();
        } else {
          throw Exception('Failed to load unidades');
        }
      }
    } catch (e) {
       if (mounted) _snack('Error al cargar catálogos: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _snack(String msg, {Color color = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _nextCodigo() {
    final next = filas.length + 1;
    return next.toString().padLeft(3, '0');
  }

  void _agregarFila() {
    // Validaciones de encabezado
    if (_selectedAlmacenId == null || almacenista == null || _selectedUnidadId == null || cliente == null) {
      _snack('Completa todos los campos del encabezado.', color: Colors.red);
      return;
    }
    
    // --- NUEVA LOGICA DE AGREGAR PRODUCTO ---
    if (_selectedProducto == null) {
      _snack('Selecciona un producto de la lista.', color: Colors.red);
      return;
    }

    int cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
    if (cantidad < 1) cantidad = 1;

    // --- PASO 3: LÓGICA DE PRECIOS DINÁMICOS (EJEMPLO) ---
    // TODO: Reemplaza esta función con tus reglas de negocio reales.
    double calcularPrecioFinal() {
      double precio = _selectedProducto!.precioStock; // Precio base
      
      // Ejemplo 1: Descuento porcentual por cliente
      if (cliente == 'Walmart') {
        precio *= 0.90; // 10% de descuento
      } else if (cliente == 'OXXO') {
        precio *= 0.95; // 5% de descuento
      }

      // Ejemplo 2: Aumento de costo fijo por almacén
      final almacenSeleccionado = _almacenes.firstWhere((a) => a.id == _selectedAlmacenId, orElse: () => Almacen(id: 0, nombre: ''));
      if (almacenSeleccionado.nombre.contains('Cancún')) {
          precio += 15.0; // Costo extra de $15 por logística en Cancún
      }

      return precio;
    }

    final precioFinal = calcularPrecioFinal();

    setState(() {
      filas.add({
        'cod': _nextCodigo(),
        'cantidad': cantidad,
        'unidad': _unidades.firstWhere((u) => u.id == _selectedUnidadId, orElse: () => Unidad(id: 0, nombre: 'N/A')).nombre,
        'producto': _selectedProducto!.nombre,
        'precio': precioFinal,
        'idproducto': _selectedProducto!.id, // Guardamos el ID para el envío
      });
      
      // Limpiar controles
      _selectedProducto = null;
      cantidadCtrl.text = '1';
    });
  }

  void _cambiarCantidad(int index, int delta) {
    setState(() {
      final nueva = (filas[index]['cantidad'] as int) + delta;
      filas[index]['cantidad'] = nueva < 1 ? 1 : nueva;
    });
  }

  void _eliminar(int index) {
    setState(() {
      filas.removeAt(index);
      for (int i = 0; i < filas.length; i++) {
        filas[i]['cod'] = (i + 1).toString().padLeft(3, '0');
      }
    });
  }

  double get total => filas.fold<double>(
        0.0,
        (sum, f) => sum + (f['cantidad'] as int) * (f['precio'] as double),
      );

  Future<void> _guardarEmbarqueEnServidor() async {
    // Use the selected IDs directly
    final idalmacen = _selectedAlmacenId;
    final idunidad = _selectedUnidadId;
    
    // These are still based on mock data
    final idalmacenista = almacenistas.indexOf(almacenista!) + 1;
    final idcliente = clientes.indexOf(cliente!) + 1;
    
    if (idalmacen == null ||
        almacenista == null ||
        idunidad == null ||
        cliente == null ||
        _selectedCamion == null ||
        _selectedTipoMovimiento == null ||
        filas.isEmpty) {
      _snack('Faltan datos de encabezado o no hay productos', color: Colors.red);
      return;
    }

    final urlEmbarque = Uri.parse('https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/api_embarques.php');
    
    try {
      final responseEmbarque = await http.post(
        urlEmbarque,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          "idalmacen": idalmacen,
          "idalmacenista": idalmacenista,
          "idunidad": idunidad,
          "idcliente": idcliente,
          "total": total,
          "camion_chofer": _selectedCamion,
          "tipo_movimiento": _selectedTipoMovimiento,
          "motivo_cancelacion": _cancelacionCtrl.text,
        }),
      );

      if (responseEmbarque.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(responseEmbarque.body);
        final int idembarque = data['idembarque'];

        final urlDetalle = Uri.parse('https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/api_embarque_detalle.php');
        
        final List<Map<String, dynamic>> productosPayload = filas.map((fila) => {
          "idproducto": fila['idproducto'], // <-- CAMBIO CLAVE
          "cantidad": fila['cantidad'],
          "precio": fila['precio'],
        }).toList();

        final responseDetalle = await http.post(
          urlDetalle,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            "idembarque": idembarque,
            "productos": productosPayload,
          }),
        );
        
        if (responseDetalle.statusCode == 201) {
          _snack('✅ Embarque guardado exitosamente.', color: Colors.green);
          setState(() {
            filas.clear();
            _selectedAlmacenId = null;
            almacenista = null;
            _selectedUnidadId = null;
            cliente = null;
            _selectedCamion = null;
            _selectedTipoMovimiento = null;
            _cancelacionCtrl.clear();
          });
        } else {
          _snack('❌ Error al guardar detalles: ${responseDetalle.statusCode}', color: Colors.red);
          print('Respuesta del servidor: ${responseDetalle.body}');
        }
      } else {
        _snack('❌ Error al guardar encabezado: ${responseEmbarque.statusCode}', color: Colors.red);
        print('Respuesta del servidor: ${responseEmbarque.body}');
      }
    } catch (e) {
      _snack('❌ Error de conexión: $e', color: Colors.red);
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              const SizedBox(height: 16),

              // Encabezado
              _CardWrap(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final isPhone = w < 700;
                    final isTablet = w >= 700 && w < 1100;
                    final cols = isPhone ? 2 : 3;

                    return GridView.count(
                      crossAxisCount: cols,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isPhone ? 3.2 : (isTablet ? 3.4 : 3.8),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildDropdown<int>(
                          label: 'Almacén',
                          icon: Icons.store_mall_directory_outlined,
                          value: _selectedAlmacenId,
                          items: _almacenes.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.nombre))).toList(),
                          onChanged: (v) => setState(() => _selectedAlmacenId = v),
                        ),
                        _buildDropdown<String>(
                          label: 'Almacenista',
                          icon: Icons.badge_outlined,
                          value: almacenista,
                          items: almacenistas.map((a) => DropdownMenuItem<String>(value: a, child: Text(a))).toList(),
                          onChanged: (v) => setState(() => almacenista = v),
                        ),
                        _buildDropdown<int>(
                          label: 'Unidad',
                          icon: Icons.straighten,
                          value: _selectedUnidadId,
                          items: _unidades.map((u) => DropdownMenuItem<int>(value: u.id, child: Text(u.nombre))).toList(),
                          onChanged: (v) => setState(() => _selectedUnidadId = v),
                        ),
                        _buildDropdown<String>(
                          label: 'Cliente',
                          icon: Icons.person_outline,
                          value: cliente,
                          items: clientes.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => cliente = v),
                        ),
                        _buildDropdown<String>(
                          label: 'Camión (Chofer)',
                          icon: Icons.fire_truck_outlined,
                          value: _selectedCamion,
                          items: camiones.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
                          onChanged: (v) => setState(() => _selectedCamion = v),
                        ),
                        _buildDropdown<String>(
                          label: 'Tipo de Movimiento',
                          icon: Icons.compare_arrows_outlined,
                          value: _selectedTipoMovimiento,
                          items: tiposDeMovimiento.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
                          onChanged: (v) => setState(() => _selectedTipoMovimiento = v),
                        ),
                        TextField(
                          controller: _cancelacionCtrl,
                          decoration: _inputDeco(
                            label: 'Motivo Cancelación',
                            icon: Icons.cancel_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              
              // Captura de productos
              _CardWrap(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Producto'),
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (context, c) {
                      final isSmall = c.maxWidth < 500;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          // Dropdown de productos
                          SizedBox(
                            width: isSmall ? double.infinity : c.maxWidth * 0.5,
                            child: _buildDropdown<Producto>(
                              label: 'Selecciona un Producto',
                              icon: Icons.shopping_basket_outlined,
                              value: _selectedProducto,
                              items: _productosDeEjemplo.map((p) => DropdownMenuItem<Producto>(
                                value: p,
                                child: Text(p.nombre),
                              )).toList(),
                              onChanged: (p) => setState(() => _selectedProducto = p),
                            ),
                          ),
                          // Campo de cantidad
                          SizedBox(
                            width: isSmall ? double.infinity : c.maxWidth * 0.2,
                            child: TextField(
                              controller: cantidadCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco(
                                label: 'Cantidad',
                                icon: Icons.format_list_numbered,
                              ),
                            ),
                          ),
                          // Botón de agregar
                          SizedBox(
                            width: isSmall ? double.infinity : c.maxWidth * 0.2,
                            child: _primaryButton(
                              icon: Icons.add_circle_outline,
                              text: 'Agregar',
                              background: const Color(0xFF1E3A8A),
                              onPressed: _agregarFila,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tabla de productos
              _CardWrap(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Detalle'),
                    const SizedBox(height: 12),
                    filas.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text('Sin productos agregados', style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('cod.')),
                                DataColumn(label: Text('Cantidad')),
                                DataColumn(label: Text('Unidad')),
                                DataColumn(label: Text('Producto')),
                                DataColumn(label: Text('P/U')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: [
                                for (int i = 0; i < filas.length; i++)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(filas[i]['cod'] as String)),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove),
                                            color: Colors.red,
                                            iconSize: 18,
                                            onPressed: () => _cambiarCantidad(i, -1),
                                          ),
                                          Text('${filas[i]['cantidad']}'),
                                          IconButton(
                                            icon: const Icon(Icons.add),
                                            color: Colors.green,
                                            iconSize: 18,
                                            onPressed: () => _cambiarCantidad(i, 1),
                                          ),
                                        ],
                                      )),
                                      DataCell(Text(filas[i]['unidad'].toString())),
                                      DataCell(Text(filas[i]['producto'].toString())),
                                      DataCell(Text('\$${(filas[i]['precio'] as double).toStringAsFixed(2)}')),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red,
                                          onPressed: () => _eliminar(i),
                                        ),
                                      ),
                                    ],
                                  )
                              ],
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Total
              _CardWrap(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botones de acción
              LayoutBuilder(
                builder: (context, c) {
                  return GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3.6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _actionBtnModern(
                        icon: Icons.save_outlined,
                        text: 'GUARDAR LOCALMENTE',
                        background: const Color(0xFF6C757D),
                        border: const Color(0xFF495057),
                        onPressed: () => _snack('Guardado localmente', color: Colors.green),
                      ),
                      _actionBtnModern(
                        icon: Icons.cloud_upload_outlined,
                        text: 'GUARDAR',
                        background: const Color(0xFF1E3A8A),
                        border: const Color(0xFF1D4ED8),
                        onPressed: _guardarEmbarqueEnServidor,
                      ),
                      _actionBtnModern(
                        icon: Icons.print_outlined,
                        text: 'IMPRIMIR',
                        background: const Color(0xFF0F766E),
                        border: const Color(0xFF115E59),
                        onPressed: () => _snack('Enviando a impresión (demo)', color: Colors.teal),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Widget? trailing,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: trailing,
      filled: true,
      fillColor: const Color(0xFFF6F7FB),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8DFEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF6F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DFEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6),
        ),
      ),
      isExpanded: true,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String text,
    required Color background,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        shadowColor: Colors.black.withOpacity(0.25),
      ),
    );
  }

  Widget _actionBtnModern({
    required IconData icon,
    required String text,
    required Color background,
    required Color border,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.2),
        ),
        shadowColor: Colors.black.withOpacity(0.25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// --------- Secciones visuales ---------

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color a = const Color(0xFF0D1B2A);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: a,
          ),
          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Embarques',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        const CircleAvatar(
          radius: 18,
          child: Icon(Icons.person_outline),
        ),
        const SizedBox(width: 8),
        const Text('Hola Arturo', style: TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CardWrap extends StatelessWidget {
  final Widget child;
  const _CardWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }
}
