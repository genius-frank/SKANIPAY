import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'transaction_storage.dart';

class ConfirmScreen extends StatefulWidget {
  final String serviceType;
  final String scannedNumber;
  final String scannedAccount;
  final String scannedStore;

  const ConfirmScreen({
    super.key,
    required this.serviceType,
    required this.scannedNumber,
    this.scannedAccount = '',
    this.scannedStore = '',
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  String _recipientName = '';

  @override
  void initState() {
    super.initState();
    _numberController.text = widget.scannedNumber;
    _accountController.text = widget.scannedAccount;
    _storeController.text = widget.scannedStore;
    
    // Look up contact if it's a phone number service
    if (widget.serviceType == 'Send Money' || widget.serviceType == 'Pochi la Biashara') {
      _lookupContact(widget.scannedNumber);
    }
    
    // Add listener to re-lookup if user edits the number
    _numberController.addListener(() {
      if (widget.serviceType == 'Send Money' || widget.serviceType == 'Pochi la Biashara') {
        _lookupContact(_numberController.text);
      }
    });
  }

  Future<void> _lookupContact(String phoneNumber) async {
    if (phoneNumber.length < 10) return;
    
    try {
      if (await Permission.contacts.request().isGranted) {
        final contacts = await FastContacts.getAllContacts();
        
        // Normalize the scanned number for comparison
        String normalizedScanned = phoneNumber.replaceAll(RegExp(r'\s+'), '');
        if (normalizedScanned.startsWith('254')) normalizedScanned = '0${normalizedScanned.substring(3)}';
        if (normalizedScanned.startsWith('+254')) normalizedScanned = '0${normalizedScanned.substring(4)}';

        for (var contact in contacts) {
          for (var phone in contact.phones) {
            final String rawNum = phone.number;
            if (rawNum.isEmpty) continue;
            
            String normalizedContact = rawNum.replaceAll(RegExp(r'[^\d]'), '');
            if (normalizedContact.startsWith('254')) normalizedContact = '0${normalizedContact.substring(3)}';
            
            if (normalizedContact == normalizedScanned || normalizedContact.endsWith(normalizedScanned.substring(1))) {
              if (mounted) {
                setState(() {
                  _recipientName = contact.displayName;
                });
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error looking up contact: $e');
    }
    
    if (mounted) {
      setState(() {
        _recipientName = '';
      });
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _amountController.dispose();
    _accountController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  Future<void> _openMpesa() async {
    final number = _numberController.text.trim();
    final amount = _amountController.text.trim();

    if (number.isEmpty || amount.isEmpty) {
      _showError('Please enter both number and amount!');
      return;
    }

    _showConfirmationDialog(number, amount);
  }

  void _showConfirmationDialog(String number, String amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00A86B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00A86B)),
            ),
            const SizedBox(width: 12),
            const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are about to send:', style: TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 4),
            Text('KES $amount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF00A86B))),
            const SizedBox(height: 16),
            const Text('To:', style: TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              _recipientName.isNotEmpty ? _recipientName : number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            if (_recipientName.isNotEmpty)
              Text(number, style: const TextStyle(fontSize: 14, color: Colors.black45)),
            
            if (widget.serviceType == 'Pay Bill' && _accountController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Account:', style: TextStyle(color: Colors.black54, fontSize: 14)),
              Text(_accountController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: Colors.black26),
                const SizedBox(width: 4),
                Text(
                  '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: Colors.black26),
                ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _executePayment(number, amount);
                  },
                  child: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _executePayment(String number, String amount) async {
    // Save transaction to local history
    await TransactionStorage.saveTransaction(
      PaymentTransaction(
        serviceType: widget.serviceType,
        number: number,
        account: _accountController.text.trim(),
        store: _storeController.text.trim(),
        recipientName: _recipientName,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );

    final Uri mpesaUri = Uri.parse('com.safaricom.mpesa.lifestyle://');
    try {
      if (await canLaunchUrl(mpesaUri)) {
        await launchUrl(mpesaUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Error launching M-Pesa app: $e');
    }
    _launchUSSD(number, amount);
  }

  void _launchUSSD(String number, String amount) async {
    String ussdCode = '';
    // Based on Safaricom *334# standard menu
    if (widget.serviceType == 'Buy Goods & Services') {
      ussdCode = '*334*5*1*$number*$amount#';
    } else if (widget.serviceType == 'Pay Bill') {
      final account = _accountController.text.trim();
      ussdCode = '*334*5*2*$number*$account*$amount#';
    } else if (widget.serviceType == 'Withdraw Cash') {
      final store = _storeController.text.trim();
      ussdCode = store.isNotEmpty ? '*334*2*1*$number*$store*$amount#' : '*334*2*1*$number*$amount#';
    } else if (widget.serviceType == 'Send Money') {
      ussdCode = '*334*1*1*$number*$amount#';
    } else if (widget.serviceType == 'Pochi la Biashara') {
      ussdCode = '*334*5*3*$number*$amount#';
    } else if (widget.serviceType == 'Buy Airtime') {
      ussdCode = '*334*3*2*$number*$amount#'; // Buy for other phone
    } else {
      ussdCode = '*334#';
    }

    final Uri telUri = Uri.parse('tel:${ussdCode.replaceAll('#', '%23')}');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      _showError('Could not launch dialer.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _copyNumber() {
    Clipboard.setData(ClipboardData(text: _numberController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Number copied successfully!'),
        backgroundColor: const Color(0xFF00A86B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.serviceType,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm Details',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -1),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please verify the information below before proceeding.',
                  style: TextStyle(fontSize: 15, color: Colors.black45),
                ),
                const SizedBox(height: 32),
                
                // Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(
                        widget.serviceType == 'Send Money' || widget.serviceType == 'Pochi la Biashara'
                            ? 'Recipient Phone Number'
                            : 'Business/Agent Number',
                      ),
                      if (_recipientName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF00A86B)),
                                const SizedBox(width: 6),
                                Text(
                                  _recipientName,
                                  style: const TextStyle(color: Color(0xFF00A86B), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _buildTextField(_numberController, 'Enter number'),
                      
                      if (widget.serviceType == 'Withdraw Cash') ...[
                        const SizedBox(height: 24),
                        _buildFieldLabel('Store Number (Optional)'),
                        _buildTextField(_storeController, 'Enter store number'),
                      ],
                      
                      if (widget.serviceType == 'Pay Bill') ...[
                        const SizedBox(height: 24),
                        _buildFieldLabel('Account Number'),
                        _buildTextField(_accountController, 'Enter account number'),
                      ],
                      
                      const SizedBox(height: 24),
                      _buildFieldLabel('Amount (KES)'),
                      _buildTextField(_amountController, '0.00', prefix: 'KES '),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: ['100', '500', '1000', '2000', '5000'].map((amt) {
                          return ActionChip(
                            label: Text('+$amt'),
                            onPressed: () {
                              setState(() {
                                double current = double.tryParse(_amountController.text) ?? 0;
                                _amountController.text = (current + double.parse(amt)).toStringAsFixed(0);
                              });
                            },
                            backgroundColor: const Color(0xFF00A86B).withValues(alpha: 0.1),
                            side: BorderSide.none,
                            labelStyle: const TextStyle(color: Color(0xFF00A86B), fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Action Buttons
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    shadowColor: const Color(0xFF00A86B).withValues(alpha: 0.4),
                  ),
                  onPressed: _openMpesa,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('PROCEED SECURELY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 64),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _copyNumber,
                  child: const Text('COPY NUMBER', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
                
                const SizedBox(height: 32),
                
                // Security Tip
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Colors.black.withValues(alpha: 0.2)),
                      const SizedBox(width: 8),
                      Text(
                        'Secure encrypted transaction via Safaricom',
                        style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.3), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black26, letterSpacing: 1),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {String? prefix}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00A86B), width: 1.5)),
      ),
    );
  }
}
