import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfirmScreen extends StatefulWidget {
  final String serviceType;
  final String scannedNumber;

  const ConfirmScreen({
    super.key,
    required this.serviceType,
    required this.scannedNumber,
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _numberController.text = widget.scannedNumber;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _openMpesa() async {
    final number = _numberController.text.trim();
    final amount = _amountController.text.trim();

    if (number.isEmpty || amount.isEmpty) {
      _showError('Please enter both number and amount!');
      return;
    }

    // Try opening M-Pesa App first
    final Uri mpesaUri = Uri.parse('com.safaricom.mpesa.lifestyle://');
    try {
      if (await canLaunchUrl(mpesaUri)) {
        await launchUrl(mpesaUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Error launching M-Pesa app: $e');
    }

    // Fallback to USSD or SIM Toolkit approach if possible,
    // or just show a message with instructions.
    _showUSSDDialog(number, amount);
  }

  void _showUSSDDialog(String number, String amount) {
    String ussdCode = '';
    if (widget.serviceType == 'Buy Goods & Services') {
      ussdCode = '*334*3*1*$number*$amount#';
    } else if (widget.serviceType == 'Pay Bill') {
      final account = _accountController.text.trim();
      ussdCode = '*334*3*2*$number*$account*$amount#';
    } else if (widget.serviceType == 'Withdraw Cash') {
      ussdCode = '*334*7*1*$number*$amount#';
    } else {
      ussdCode = '*334#';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('M-Pesa App Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Would you like to use the USSD shortcut instead?'),
            const SizedBox(height: 12),
            SelectableText(
              ussdCode,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final Uri telUri = Uri.parse('tel:${ussdCode.replaceAll('#', '%23')}');
              if (await canLaunchUrl(telUri)) {
                await launchUrl(telUri);
              } else {
                _showError('Could not launch dialer.');
              }
            },
            child: const Text('Dial USSD'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyNumber() {
    Clipboard.setData(ClipboardData(text: _numberController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Number copied! Open Mpesa and paste it.'),
        backgroundColor: Color(0xFF00A86B),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A86B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A86B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.serviceType,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Confirm Details',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check the number carefully before paying',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scanned Number',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black45,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _numberController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00A86B),
                        letterSpacing: 2,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Number',
                      ),
                    ),
                    if (widget.serviceType == 'Pay Bill') ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Account Number',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black45,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _accountController,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter account number',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Amount (KES)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black45,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter amount',
                        prefixText: 'KES ',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _copyNumber,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy, color: Color(0xFF00A86B), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Copy Number',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A86B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _openMpesa,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment, color: Color(0xFF00A86B), size: 32),
                      SizedBox(width: 16),
                      Text(
                        'Proceed to Mpesa',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A86B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Always verify the number before proceeding to payment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
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