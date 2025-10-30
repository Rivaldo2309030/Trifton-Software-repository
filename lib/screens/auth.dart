import 'dart:convert';
import 'dart:io';
import 'package:distribuidora/screens/main_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distribuidora/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:distribuidora/services/database_helper.dart';

/// ====== PALETA (alineada a tus azules) ======
const kBrandDark = Color(0xFF0D2960);
const kBrandMid = Color(0xFF12376B);
const kBrandLite = Color(0xFF1A4F91);

class LoginScreen extends StatefulWidget {
  final String? username;
  final String? password;

  const LoginScreen({super.key, this.username, this.password});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _isLoading = false;

  void _registerUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username ?? '');
    _passwordController = TextEditingController(text: widget.password ?? '');
    _checkLoginStatus();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idusuario');

    if (userId != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    }
  }

  void _showSuccessDialogWithIcon(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          title: Column(
            children: const [
              Icon(
                Icons.local_shipping_rounded,
                color: kBrandDark,
                size: 52,
              ),
              SizedBox(height: 8),
              Text(
                '¡Éxito!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kBrandDark,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    final String url = '${ApiConfig.baseUrl}loginUser.php';

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          "username": _usernameController.text.trim(),
          "contrasena": _passwordController.text,
        },
      );

      final responseData = jsonDecode(response.body);

      if (responseData["status"] == "success") {
        if (responseData["data"] != null &&
            responseData["data"]["idusuario"] != null) {
          final userId = int.parse(
            responseData['data']['idusuario'].toString(),
          );
          final username = responseData['data']['username'] ?? "Usuario";

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt("idusuario", userId);
          await prefs.setString("username", username);

          final dbHelper = DatabaseHelper.instance;
          await dbHelper.saveUserCredentials(
            userId,
            _usernameController.text.trim(),
            username,
            _passwordController.text,
          );

          _showSuccessDialogWithIcon("Inicio de sesión exitoso");

          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
            );
          });
        } else {
          _toast("Error: el servidor no envió idusuario");
        }
      } else {
        _toast("Error: ${responseData['message']}");
      }
    } on SocketException {
      await _loginOffline();
    } catch (e) {
      _toast("Error en la conexión al servidor: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginOffline() async {
    if (!mounted) return;
    _toast("No hay conexión. Intentando login offline...");
    setState(() => _isLoading = true);

    try {
      final dbHelper = DatabaseHelper.instance;
      final userData = await dbHelper.verifyOfflineLogin(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (userData != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt("idusuario", userData['idusuario']);
        await prefs.setString("username", userData['username']);

        _showSuccessDialogWithIcon("Inicio de sesión offline exitoso");

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          );
        });
      } else {
        _toast("Error: Credenciales offline incorrectas o no guardadas.");
      }
    } catch (e) {
      _toast("Error durante el login offline: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kBrandDark),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kBrandDark, kBrandMid, kBrandLite],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(top: -40, right: -30, child: _bubble(140, 0.15)),
          Positioned(top: 80, left: -20, child: _bubble(90, 0.12)),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(46), // withOpacity(0.18)
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 24,
                          color: Colors.black26,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(8.0), // Ajusta el padding según sea necesario
                        child: Image(
                          image: AssetImage('assets/img/logo_triton_principal.png'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'TRITON SOFTWARE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Inicia sesión para continuar',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 28),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230), // withOpacity(0.9)
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDeco(
                            label: 'Usuario',
                            icon: Icons.person_rounded,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa tu usuario'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          onFieldSubmitted: (_) => _loginUser(),
                          decoration: _inputDeco(
                            label: 'Contraseña',
                            icon: Icons.lock_rounded,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: kBrandDark,
                              ),
                              tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Ingresa tu contraseña'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _loginUser,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _isLoading ? 'Entrando...' : 'Entrar',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrandDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿No tienes cuenta?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: _registerUser,
                      child: const Text(
                        'Regístrate',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Center(
                  child: Opacity(
                    opacity: 0.35,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.location_on_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Logística • Embarques • Pedidos',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _bubble(double size, double opacity) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withAlpha((255 * opacity).round()),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  void _goLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kBrandDark),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  void _showSuccessOverlay() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 50,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: kBrandDark,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  '¡Registro exitoso!',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1), () => entry.remove());
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    final String url = '${ApiConfig.baseUrl}registerUser.php';

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre": _nombreController.text.trim(),
          "username": _usuarioController.text.trim(),
          "telefono": _phoneController.text.trim(),
          "contrasena": _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      if (data["status"] == "success") {
        _showSuccessOverlay();
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                username: _usuarioController.text.trim(),
                password: _passwordController.text,
              ),
            ),
          );
        });
      } else {
        _toast('Error: ${data['message']}');
      }
    } catch (e) {
      _toast('Error en la conexión al servidor');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kBrandDark, kBrandMid, kBrandLite],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(top: -40, right: -30, child: _bubble(140, 0.15)),
          Positioned(top: 80, left: -20, child: _bubble(90, 0.12)),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(46), // withOpacity(0.18)
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 24,
                          color: Colors.black26,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(8.0), // Ajusta el padding según sea necesario
                        child: Image(
                          image: AssetImage('assets/img/logo_triton_principal.png'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'TRITON SOFTWARE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Crea tu cuenta para continuar',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230), // withOpacity(0.9)
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDeco(
                            label: 'Nombre completo',
                            icon: Icons.badge_rounded,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa tu nombre completo'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _usuarioController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDeco(
                            label: 'Usuario',
                            icon: Icons.person_rounded,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa un usuario'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _inputDeco(
                            label: 'Teléfono',
                            icon: Icons.phone_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu número de teléfono';
                            } else if (!RegExp(r'^\d+$').hasMatch(value)) {
                              return 'El teléfono debe ser numérico';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          textInputAction: TextInputAction.next,
                          obscureText: _obscure1,
                          decoration: _inputDeco(
                            label: 'Contraseña',
                            icon: Icons.lock_rounded,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                              icon: Icon(
                                _obscure1
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: kBrandDark,
                              ),
                              tooltip: _obscure1 ? 'Mostrar' : 'Ocultar',
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Ingresa una contraseña'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscure2,
                          onFieldSubmitted: (_) => _registerUser(),
                          decoration: _inputDeco(
                            label: 'Confirmar contraseña',
                            icon: Icons.password_rounded,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                              icon: Icon(
                                _obscure2
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: kBrandDark,
                              ),
                              tooltip: _obscure2 ? 'Mostrar' : 'Ocultar',
                            ),
                          ),
                          validator: (v) => (v != _passwordController.text)
                              ? 'Las contraseñas no coinciden'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _registerUser,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(
                              _isLoading ? 'Registrando...' : 'Registrar',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrandDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: _goLogin,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Center(
                  child: Opacity(
                    opacity: 0.35,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.local_shipping_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Registro de usuarios',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
