import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MpesaStkResult {
  final bool success;
  final String message;
  final String? checkoutRequestId;
  final bool requiresKeys;

  MpesaStkResult({
    required this.success,
    required this.message,
    this.checkoutRequestId,
    this.requiresKeys = false,
  });
}

class MpesaStkService {
  static const String _keyConsumerKey = 'daraja_consumer_key';
  static const String _keyConsumerSecret = 'daraja_consumer_secret';
  static const String _keyShortCode = 'daraja_shortcode';
  static const String _keyPasskey = 'daraja_passkey';

  static Future<void> saveDarajaKeys({
    required String consumerKey,
    required String consumerSecret,
    required String shortCode,
    required String passkey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConsumerKey, consumerKey.trim());
    await prefs.setString(_keyConsumerSecret, consumerSecret.trim());
    await prefs.setString(_keyShortCode, shortCode.trim());
    await prefs.setString(_keyPasskey, passkey.trim());
  }

  static Future<Map<String, String>> getDarajaKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'consumerKey': prefs.getString(_keyConsumerKey) ?? '',
      'consumerSecret': prefs.getString(_keyConsumerSecret) ?? '',
      'shortCode': prefs.getString(_keyShortCode) ?? '',
      'passkey': prefs.getString(_keyPasskey) ?? '',
    };
  }

  /// Sends an STK Push prompt directly to the specified phone number.
  static Future<MpesaStkResult> triggerStkPush({
    required String phoneNumber,
    required String amount,
    required String accountRef,
  }) async {
    final storedKeys = await getDarajaKeys();
    final key = storedKeys['consumerKey'] ?? '';
    final secret = storedKeys['consumerSecret'] ?? '';
    final shortCode = storedKeys['shortCode'] ?? '';
    final pass = storedKeys['passkey'] ?? '';

    if (key.isEmpty || secret.isEmpty) {
      return MpesaStkResult(
        success: false,
        requiresKeys: true,
        message: 'Safaricom Daraja API keys required. Please tap "Configure Daraja Keys" or use M-Pesa App/USSD.',
      );
    }

    // Normalize phone number to format 2547XXXXXXXX or 2541XXXXXXXX
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '254${formattedPhone.substring(1)}';
    } else if (formattedPhone.startsWith('+254')) {
      formattedPhone = formattedPhone.substring(1);
    }

    if (!formattedPhone.startsWith('254') || formattedPhone.length != 12) {
      return MpesaStkResult(
        success: false,
        message: 'Invalid phone number format. Please enter a valid Safaricom number.',
      );
    }

    try {
      // 1. Get OAuth Access Token from Safaricom Daraja
      final authHeader = base64Encode(utf8.encode('$key:$secret'));
      final authResponse = await http.get(
        Uri.parse('https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials'),
        headers: {'Authorization': 'Basic $authHeader'},
      );

      if (authResponse.statusCode != 200) {
        return MpesaStkResult(
          success: false,
          requiresKeys: true,
          message: 'Safaricom Auth Failed. Please verify your Consumer Key & Secret.',
        );
      }

      final accessToken = jsonDecode(authResponse.body)['access_token'];

      // 2. Generate Timestamp & Password
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final password = base64Encode(utf8.encode('$shortCode$pass$timestamp'));

      // 3. Send STK Push Request
      final stkPayload = {
        "BusinessShortCode": shortCode.isNotEmpty ? shortCode : "174379",
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": amount,
        "PartyA": formattedPhone,
        "PartyB": shortCode.isNotEmpty ? shortCode : "174379",
        "PhoneNumber": formattedPhone,
        "CallBackURL": "https://mydomain.com/pat",
        "AccountReference": accountRef.isNotEmpty ? accountRef : "SkaniPay",
        "TransactionDesc": "SkaniPay Payment"
      };

      final stkResponse = await http.post(
        Uri.parse('https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(stkPayload),
      );

      final resData = jsonDecode(stkResponse.body);

      if (resData['ResponseCode'] == '0') {
        return MpesaStkResult(
          success: true,
          message: 'STK Push sent to $formattedPhone! Enter your M-Pesa PIN.',
          checkoutRequestId: resData['CheckoutRequestID'],
        );
      } else {
        return MpesaStkResult(
          success: false,
          message: resData['CustomerMessage'] ?? 'STK Push Failed.',
        );
      }
    } catch (e) {
      debugPrint('Daraja STK Error: $e');
      return MpesaStkResult(
        success: false,
        message: 'Could not connect to Safaricom Daraja server.',
      );
    }
  }
}
