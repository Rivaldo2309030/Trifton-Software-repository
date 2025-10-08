import 'package:flutter/material.dart';
import 'package:distribuidora/screens/PedidosScreen.dart';
import 'embarque_screen.dart';
import 'package:distribuidora/screens/sync_screen.dart';

void main() {
  runApp(const MyApp());
}

/// COLORES CORPORATIVOS
const Color kCorporateBlue = Color(0xFF0B2C5D); // Azul marino
const Color kCorporateBlueDark = Color(0xFF071C3D);
const Color kAccent = Color(0xFF00B0B9);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true);

    return MaterialApp(
      title: 'Triton Software',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kCorporateBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: kCorporateBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamily: 'Arial Black',
            fontFamilyFallback: ['Arial', 'sans-serif'],
            letterSpacing: 0.8,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          surfaceTintColor: kCorporateBlue,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    EmbarqueScreen(),
    PedidosScreen(pedidos: []),
    SyncScreen(), // <-- Pantalla añadida
  ];

  final List<String> _titles = const [
    "TRITON SOFTWARE",
    "TRITON SOFTWARE",
    "TRITON SOFTWARE",
    "SINCRONIZACIÓN", // <-- Título añadido
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth >= 1000;

        return Scaffold(
          appBar: _TritonAppBar(title: _titles[_currentIndex]),
          drawer: isLargeScreen ? null : _buildDrawer(),
          body: SafeArea(
            child: Row(
              children: [
                if (isLargeScreen) _buildNavigationRail(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: IndexedStack( // Usar IndexedStack para mantener el estado de las pantallas
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isLargeScreen ? null : _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard, color: kCorporateBlue),
          label: "Inicio",
        ),
        NavigationDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping, color: kCorporateBlue),
          label: "Embarque",
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart, color: kCorporateBlue),
          label: "Pedidos",
        ),
        NavigationDestination(
          icon: Icon(Icons.sync_alt_outlined),
          selectedIcon: Icon(Icons.sync_alt, color: kCorporateBlue),
          label: "Sincronizar",
        ),
      ],
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.white,
      selectedIconTheme: const IconThemeData(color: kCorporateBlue),
      selectedLabelTextStyle: const TextStyle(
        color: kCorporateBlue,
        fontWeight: FontWeight.bold,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text("Inicio"),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: Text("Embarque"),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: Text("Pedidos"),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.sync_alt_outlined),
          selectedIcon: Icon(Icons.sync_alt),
          label: Text("Sincronizar"),
        ),
      ],
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kCorporateBlue, kCorporateBlueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.business, color: kCorporateBlue, size: 36),
            ),
            accountName: Text(
              "TRITON SOFTWARE",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text("Arturo Díaz"),
          ),
          _drawerItem(Icons.dashboard_outlined, "Inicio", 0),
          _drawerItem(Icons.local_shipping_outlined, "Embarque", 1),
          _drawerItem(Icons.shopping_cart_outlined, "Pedidos", 2),
          _drawerItem(Icons.sync_alt_outlined, "Sincronizar", 3),
          const Spacer(),
          const Divider(height: 1),
          _drawerItem(Icons.settings, "Configuración", null),
          _drawerItem(Icons.help_outline, "Ayuda", null),
          const SizedBox(height: 10),
          Text(
            "Versión 1.0.0",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String title, int? index) {
    return ListTile(
      leading: Icon(
        icon,
        color: index == _currentIndex ? kCorporateBlue : null,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      selected: index != null && _currentIndex == index,
      onTap: index == null
          ? () {}
          : () {
              setState(() => _currentIndex = index);
              Navigator.pop(context);
            },
    );
  }
}

/// APPBAR con degradado y título BLANCO
class _TritonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _TritonAppBar({required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 80,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          fontFamily: 'Arial Black',
          fontFamilyFallback: ['Arial', 'sans-serif'],
          letterSpacing: 1.2,
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          gradient: LinearGradient(
            colors: [kCorporateBlue, kCorporateBlueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

/// ===================== DASHBOARD =====================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double scale = (w / 390).clamp(0.9, 1.25);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: _WelcomeBanner(scale: scale),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.05,
            ),
            delegate: SliverChildListDelegate.fixed([
              _KpiCard(
                title: "Pedidos",
                value: "128",
                trend: "+12%",
                icon: Icons.shopping_cart,
                gradient: const [Color(0xFF1B4F72), Color(0xFF0B2C5D)],
                scale: scale,
              ),
              _KpiCard(
                title: "Embarques",
                value: "42",
                trend: "+3%",
                icon: Icons.local_shipping,
                gradient: const [Color(0xFF0CA678), Color(0xFF087F5B)],
                scale: scale,
              ),
              _KpiCard(
                title: "Clientes",
                value: "87",
                trend: "+6%",
                icon: Icons.people,
                gradient: const [Color(0xFFFF8C42), Color(0xFFEB5E28)],
                scale: scale,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Banner superior
class _WelcomeBanner extends StatelessWidget {
  final double scale;
  const _WelcomeBanner({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18 * scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kCorporateBlue, kCorporateBlueDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kCorporateBlue.withOpacity(.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard_customize_rounded,
              color: Colors.white, size: 34 * scale),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bienvenido",
                  style: TextStyle(
                    color: Colors.white.withOpacity(.95),
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Arial Black',
                    fontFamilyFallback: ['Arial', 'sans-serif'],
                  ),
                ),
                Text(
                  "Panel de control · Triton Software",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Arial Black',
                    fontFamilyFallback: ['Arial', 'sans-serif'],
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

/// Tarjeta KPI
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final IconData icon;
  final List<Color> gradient;
  final double scale;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.gradient,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(.30),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.08),
              ),
            ),
          ),
          Positioned(
            left: -16,
            bottom: -16,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.06),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(.18),
                  radius: 24 * scale,
                  child: Icon(icon, color: Colors.white, size: 24 * scale),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28 * scale,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Arial Black',
                    fontFamilyFallback: ['Arial', 'sans-serif'],
                    letterSpacing: .2,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Arial Black',
                        fontFamilyFallback: ['Arial', 'sans-serif'],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.trending_up, color: Colors.white, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Arial Black',
                        fontFamilyFallback: ['Arial', 'sans-serif'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
