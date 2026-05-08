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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A86B),
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
      backgroundColor: const Color(0xFF00A86B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.document_scanner,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'SkaniPay',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Scan. Pay. Done.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                'Choose Service',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ServiceButton(
                icon: Icons.person,
                label: 'Withdraw Cash',
                subtitle: 'Scan Agent & Store Number',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScannerScreen(
                        serviceType: 'Withdraw Cash',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ServiceButton(
                icon: Icons.store,
                label: 'Buy Goods & Services',
                subtitle: 'Scan Till Number',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScannerScreen(
                        serviceType: 'Buy Goods & Services',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ServiceButton(
                icon: Icons.receipt,
                label: 'Pay Bill',
                subtitle: 'Scan Paybill & Account Number',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScannerScreen(
                        serviceType: 'Pay Bill',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ServiceButton(
                icon: Icons.shopping_bag,
                label: 'Pochi la Biashara',
                subtitle: 'Scan Pochi Number',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScannerScreen(
                        serviceType: 'Pochi la Biashara',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const ServiceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00A86B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF00A86B),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black45,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}