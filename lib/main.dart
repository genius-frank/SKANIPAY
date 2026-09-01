import 'package:flutter/material.dart';
import 'scanner_screen.dart';
void main() {
  runApp(const SkaniPayApp());
}

class SkaniPayApp extends StatelessWidget {
  const SkaniPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkaniPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00A86B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A86B),
          primary: const Color(0xFF00A86B),
          secondary: const Color(0xFF01D277),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9), // Modern Light Background
      body: CustomScrollView(
        slivers: [
          // Professional App Bar with Gradient
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF00A86B),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00A86B), Color(0xFF01D277)],
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),
                    Icon(Icons.document_scanner, size: 60, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'SkaniPay',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                    Text(
                      'Scan • Pay • Done',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Service Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Payments',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a service to start scanning',
                    style: TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                  const SizedBox(height: 24),
                  
                  // Primary Action: Send Money
                  ServiceCard(
                    icon: Icons.send_rounded,
                    label: 'Send Money',
                    subtitle: 'Scan phone or speak number',
                    color: const Color(0xFF00A86B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen(serviceType: 'Send Money'))),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Dual Grid for Other Services
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      GridServiceCard(
                        icon: Icons.store_rounded,
                        label: 'Buy Goods',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen(serviceType: 'Buy Goods & Services'))),
                      ),
                      GridServiceCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'Pay Bill',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen(serviceType: 'Pay Bill'))),
                      ),
                      GridServiceCard(
                        icon: Icons.phone_android_rounded,
                        label: 'Airtime',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen(serviceType: 'Buy Airtime'))),
                      ),
                      GridServiceCard(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Withdraw',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen(serviceType: 'Withdraw Cash'))),
                      ),
                      GridServiceCard(
                        icon: Icons.shopping_bag_rounded,
                        label: 'Pochi',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen(serviceType: 'Pochi la Biashara'))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ServiceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black45)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class GridServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const GridServiceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00A86B), size: 36),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
