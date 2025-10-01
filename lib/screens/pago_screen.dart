// pago_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

// =================== PAGO SCREEN ===================
class PagoScreen extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final List<Map<String, dynamic>> productosSeleccionados;
  final double total;

  const PagoScreen({
    super.key,
    required this.pedido,
    required this.productosSeleccionados,
    required this.total,
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String? metodoPago;
  final TextEditingController referenciaCtrl = TextEditingController();
  late final AnimationController _btnCtrl;

  final metodos = const ['Efectivo', 'Tarjeta de Débito', 'Tarjeta de Crédito', 'Transferencia', 'Depósito'];

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  }

  @override
  void dispose() {
    referenciaCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarPago() async {
    if (!_formKey.currentState!.validate()) return;

    _btnCtrl.forward(from: 0);

    // Generar datos para el comprobante
    final now = DateTime.now();
    final fecha = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hora = TimeOfDay.fromDateTime(now).format(context);
    final codOperacion = now.millisecondsSinceEpoch.toString();

    // Abrir comprobante y esperar respuesta
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ComprobantePagoScreen(
          empresa: widget.pedido['empresa'] ?? 'Mi Empresa',
          servicio: widget.pedido['servicio'] ?? 'Productos',
          numeroSuministro: widget.pedido['id'].toString(),
          titular: widget.pedido['cliente']?.toString() ?? '',
          cuentaCargo: metodoPago ?? 'Método de pago',
          codigoOperacion: codOperacion,
          fecha: fecha,
          hora: hora,
          monto: widget.total,
        ),
      ),
    );

    // Si cerró el comprobante con "Ir al inicio", devolvemos resultado al caller
    if (res != null && res['volver'] == true) {
      Navigator.pop<Map<String, dynamic>>(context, {
        'pagado': true,
        'itemsPagados': widget.productosSeleccionados,
        'monto': widget.total,
        'metodo': metodoPago,
        'referencia': referenciaCtrl.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final prods = widget.productosSeleccionados;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final appBarBg = isDark ? const Color(0xFF101522) : Colors.white;
    final appBarFg = isDark ? Colors.white : const Color(0xFF0F172A);
    final bgTop = isDark ? const Color(0xFF0B1220) : const Color(0xFFF6F8FB);
    final bgBottom = isDark ? const Color(0xFF111827) : const Color(0xFFE9EDF3);
    final totalColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final hintDim = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final subtitleDim = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    final horizontalPad = size.width >= 1200 ? 32.0 : size.width >= 600 ? 20.0 : 16.0;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Confirmar pago'),
        centerTitle: true,
        elevation: isDark ? 0 : 0.5,
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgTop, bgBottom])),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 120),
                child: isWide
                    ? _WideLayout(isDark: isDark, hintDim: hintDim, subtitleDim: subtitleDim, totalColor: totalColor, pedido: pedido, prods: prods)
                    : _NarrowLayout(isDark: isDark, hintDim: hintDim, subtitleDim: subtitleDim, totalColor: totalColor, pedido: pedido, prods: prods),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        surface: Theme.of(context).colorScheme.surface,
        total: widget.total,
        onConfirm: _confirmarPago,
        controller: _btnCtrl,
        isEnabled: metodoPago != null,
        isDark: isDark,
      ),
    );
  }

  // ===== Secciones =====
  Widget _resumenPedido({
    required bool isDark,
    required Color hintDim,
    required Color subtitleDim,
    required Color totalColor,
    required Map<String, dynamic> pedido,
    required List<Map<String, dynamic>> prods,
  }) {
    return _GlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.receipt_long,
            title: 'Resumen del pedido',
            subtitle: '#${pedido['id'] ?? '-'}  •  ${pedido['fecha'] ?? ''}',
            chipBg: isDark ? const Color(0xFF1F2937) : const Color(0xFF111827),
            chipFg: Colors.white,
            subtitleColor: subtitleDim,
          ),
          const SizedBox(height: 12),
          _RowKV('Cliente', '${pedido['cliente'] ?? '-'}', labelColor: hintDim),
          _RowKV('Almacén', '${pedido['almacen'] ?? '-'}', labelColor: hintDim),
          const SizedBox(height: 8),
          const Divider(height: 24),
          const Text('Productos seleccionados', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (prods.isEmpty)
            Text('No hay productos', style: TextStyle(color: hintDim))
          else
            ...prods.map((p) {
              final cant = (p['cantidad'] ?? 0) as num;
              final precio = (p['precio'] ?? 0) as num;
              final subtotal = cant * precio;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('x$cant · ${_formatCurrency(precio.toDouble())}', style: TextStyle(color: hintDim, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(_formatCurrency(subtotal.toDouble()), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(child: Text('TOTAL A PAGAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text(_formatCurrency(widget.total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: totalColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metodoPago({required bool isDark, required Color subtitleDim}) {
    return _GlassCard(
      isDark: isDark,
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _CardHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Método de pago',
            subtitle: 'Selecciona una opción',
            chipBg: isDark ? const Color(0xFF1F2937) : const Color(0xFF111827),
            chipFg: Colors.white,
            subtitleColor: subtitleDim,
          ),
          const SizedBox(height: 12),
          _MetodoPagoChips(
            metodos: metodos,
            value: metodoPago,
            onChanged: (v) => setState(() => metodoPago = v),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: referenciaCtrl,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(context, isDark: isDark, label: 'Referencia / Folio', hint: 'Opcional (transferencia, voucher, etc.)', icon: Icons.tag_outlined),
            validator: (v) {
              if ((metodoPago == 'Transferencia' || metodoPago == 'Depósito') && (v == null || v.trim().isEmpty)) {
                return 'Agrega la referencia del movimiento';
              }
              return null;
            },
          ),
        ]),
      ),
    );
  }

  Widget _NarrowLayout({
    required bool isDark,
    required Color hintDim,
    required Color subtitleDim,
    required Color totalColor,
    required Map<String, dynamic> pedido,
    required List<Map<String, dynamic>> prods,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resumenPedido(isDark: isDark, hintDim: hintDim, subtitleDim: subtitleDim, totalColor: totalColor, pedido: pedido, prods: prods),
          const SizedBox(height: 16),
          _metodoPago(isDark: isDark, subtitleDim: subtitleDim),
        ],
      ),
    );
  }

  Widget _WideLayout({
    required bool isDark,
    required Color hintDim,
    required Color subtitleDim,
    required Color totalColor,
    required Map<String, dynamic> pedido,
    required List<Map<String, dynamic>> prods,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: _resumenPedido(isDark: isDark, hintDim: hintDim, subtitleDim: subtitleDim, totalColor: totalColor, pedido: pedido, prods: prods)),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: _metodoPago(isDark: isDark, subtitleDim: subtitleDim)),
      ],
    );
  }
}

// ===== Widgets de Presentación =====

class _BottomBar extends StatelessWidget {
  final Color surface;
  final double total;
  final VoidCallback onConfirm;
  final AnimationController controller;
  final bool isEnabled;
  final bool isDark;

  const _BottomBar({
    required this.surface,
    required this.total,
    required this.onConfirm,
    required this.controller,
    required this.isEnabled,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeOutBack);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16 + 6),
      decoration: BoxDecoration(
        color: isDark ? surface.withOpacity(0.92) : Colors.white.withOpacity(0.96),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -6))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Total', style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                Text(_formatCurrency(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
            ),
            ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.03).animate(curved),
              child: ElevatedButton.icon(
                onPressed: isEnabled ? onConfirm : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar pago'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  elevation: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color chipBg;
  final Color chipFg;
  final Color subtitleColor;

  const _CardHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.chipBg,
    required this.chipFg,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: chipFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: subtitleColor, fontSize: 12)),
          ]),
        ),
      ],
    );
  }
}

class _MetodoPagoChips extends StatelessWidget {
  final List<String> metodos;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool isDark;

  const _MetodoPagoChips({required this.metodos, required this.value, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metodos.map((m) {
        final selected = value == m;
        return ChoiceChip(
          selected: selected,
          label: Text(m, overflow: TextOverflow.ellipsis),
          avatar: Icon(_iconFor(m), size: 18),
          onSelected: (_) => onChanged(m),
          labelStyle: TextStyle(color: selected ? Colors.white : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827)), fontWeight: FontWeight.w600),
          selectedColor: const Color(0xFF2563EB),
          backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          elevation: selected ? 4 : 0,
        );
      }).toList(),
    );
  }

  IconData _iconFor(String m) {
    switch (m) {
      case 'Efectivo':
        return Icons.payments_outlined;
      case 'Tarjeta de Débito':
        return Icons.credit_card;
      case 'Tarjeta de Crédito':
        return Icons.credit_score_outlined;
      case 'Transferencia':
        return Icons.swap_horiz_outlined;
      case 'Depósito':
        return Icons.account_balance_outlined;
      default:
        return Icons.wallet_outlined;
    }
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _GlassCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.9)),
        boxShadow: [if (isDark) const BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 10)) else BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10))],
        gradient: isDark
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)])
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x33FFFFFF), Color(0x1AFFFFFF)]),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String k;
  final String v;
  final Color labelColor;
  const _RowKV(this.k, this.v, {required this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(k, style: TextStyle(color: labelColor, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context, {required bool isDark, required String label, String? hint, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon) : null,
    filled: true,
    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF273244) : const Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

String _formatCurrency(double value) {
  final isNegative = value < 0;
  value = value.abs();
  final whole = value.floor();
  final cents = ((value - whole) * 100).round().toString().padLeft(2, '0');
  final chars = whole.toString().split('').reversed.toList();
  final buf = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    if (i != 0 && i % 3 == 0) buf.write(',');
    buf.write(chars[i]);
  }
  final wholeFmt = buf.toString().split('').reversed.join();
  return '${isNegative ? '-' : ''}\$$wholeFmt.$cents';
}

// =================== COMPROBANTE (NOTIFICACIÓN) ===================

class ComprobantePagoScreen extends StatelessWidget {
  final String empresa;
  final String servicio;
  final String numeroSuministro;
  final String titular;
  final String cuentaCargo;
  final String codigoOperacion;
  final String fecha;
  final String hora;
  final double monto;

  const ComprobantePagoScreen({
    super.key,
    required this.empresa,
    required this.servicio,
    required this.numeroSuministro,
    required this.titular,
    required this.cuentaCargo,
    required this.codigoOperacion,
    required this.fecha,
    required this.hora,
    required this.monto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Check circular
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8F7EE)),
                        child: const Icon(Icons.check, color: Color(0xFF10B981), size: 32),
                      ),
                      const SizedBox(height: 10),
                      const Text('¡Pago realizado!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 6),
                      _linea('Empresa:', empresa),
                      _linea('Servicio:', servicio),
                      _linea('Número de suministro:', numeroSuministro),
                      _linea('Nombre del titular:', titular),
                      _linea('Cuenta cargo:', cuentaCargo),
                      _linea('Cód. operación:', codigoOperacion),
                      _linea('Fecha:', fecha),
                      _linea('Hora:', hora),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Text('Monto:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                          Text(_formatCurrency(monto), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Volver con señal para limpiar en PedidosScreen
                            Navigator.pop<Map<String, dynamic>>(context, {'volver': true});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2CA39B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Ir al inicio'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Constancia enviada'), backgroundColor: Color(0xFF2563EB)));
                        },
                        child: const Text('Enviar constancia'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _linea(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
