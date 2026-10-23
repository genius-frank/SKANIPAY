import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentTransaction {
  final String serviceType;
  final String number;
  final String account;
  final String store;
  final String recipientName;
  final String timestamp;

  PaymentTransaction({
    required this.serviceType,
    required this.number,
    this.account = '',
    this.store = '',
    this.recipientName = '',
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'serviceType': serviceType,
        'number': number,
        'account': account,
        'store': store,
        'recipientName': recipientName,
        'timestamp': timestamp,
      };

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      serviceType: json['serviceType'] ?? '',
      number: json['number'] ?? '',
      account: json['account'] ?? '',
      store: json['store'] ?? '',
      recipientName: json['recipientName'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class TransactionStorage {
  static const String _key = 'recent_transactions';

  static Future<void> saveTransaction(PaymentTransaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    List<PaymentTransaction> list = await getRecentTransactions();

    // Remove duplicates of same number and service type
    list.removeWhere((t) =>
        t.serviceType == transaction.serviceType && t.number == transaction.number);

    // Insert at top
    list.insert(0, transaction);

    // Keep last 10
    if (list.length > 10) {
      list = list.sublist(0, 10);
    }

    final jsonList = list.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<PaymentTransaction>> getRecentTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key);
    if (jsonList == null) return [];

    try {
      return jsonList
          .map((item) => PaymentTransaction.fromJson(jsonDecode(item)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
