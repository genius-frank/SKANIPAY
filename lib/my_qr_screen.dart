import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  String _selectedService = 'Send Money';
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  String get _qrData {
    final num = _numberController.text.trim();
    if (num.isEmpty) return '';

    if (_selectedService == 'Pay Bill') {
      final acc = _accountController.text.trim();
      return 'PAYBILL: $num ACC: $acc';
    } else if (_selectedService == 'Buy Goods & Services') {
      return 'TILL: $num';
    } else {
      return 'PHONE: $num';
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _qrData;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Payment QR',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                'Receive Payments Fast',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              const Text(
                'Generate your custom QR code for others to scan',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
              const SizedBox(height: 24),

              // Service Selector Segment
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: ['Send Money', 'Buy Goods & Services', 'Pay Bill'].map((type) {
                    final isSelected = _selectedService == type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedService = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF00A86B) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type == 'Buy Goods & Services' ? 'Till' : type,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Inputs Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Business or Display Name (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _numberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _selectedService == 'Send Money'
                            ? 'Your Phone Number'
                            : (_selectedService == 'Pay Bill' ? 'Business Paybill Number' : 'Till Number'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_selectedService == 'Pay Bill') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _accountController,
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Generated QR Card
              if (qrData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_nameController.text.isNotEmpty)
                        Text(
                          _nameController.text.toUpperCase(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00A86B)),
                        ),
                      const SizedBox(height: 8),
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220.0,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF00A86B)),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        qrData,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Scan with SkaniPay Camera',
                        style: TextStyle(fontSize: 12, color: Colors.black26),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.black12),
                      SizedBox(height: 12),
                      Text(
                        'Enter details above to generate your QR',
                        style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
