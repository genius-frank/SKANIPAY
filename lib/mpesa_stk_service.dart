import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MpesaStkResult {
  final bool success;
  final String message;
  final String? checkoutRequestId;

  MpesaStkResult({
    required this.success,
    required this.message,
    this.checkoutRequestId,
  });
}

class MpesaStkService {
  // Default Safaricom Daraja Sandbox credentials for testing
  static const String _defaultConsumerKey = 'c7aL0gQ2F5F4B3A2C1D0E9F8A7B6C5D4';
  static const String _defaultConsumerSecret = 'a1B2c3D4e5F6g7H8';
  static const String _defaultBusinessShortCode = '174379';
  static const String _defaultPasskey =
      'bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919';

  /// Sends an STK Push prompt directly to the specified phone number.
  static Future<MpesaStkResult> triggerStkPush({
    required String phoneNumber,
    required String amount,
    required String accountRef,
    String? consumerKey,
    String? consumerSecret,
    String? businessShortCode,
    String? passkey,
  }) async {
    final key = (consumerKey != null && consumerKey.isNotEmpty) ? consumerKey : _defaultConsumerKey;
    final secret = (consumerSecret != null && consumerSecret.isNotEmpty) ? consumerSecret : _defaultConsumerSecret;
    final shortCode = (businessShortCode != null && businessShortCode.isNotEmpty) ? businessShortCode : _defaultBusinessShortCode;
    final pass = (passkey != null && passkey.isNotEmpty) ? passkey : _defaultPasskey;

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
          message: 'Safaricom Authentication Failed. Please check Daraja API keys.',
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
        "BusinessShortCode": shortCode,
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": amount,
        "PartyA": formattedPhone,
        "PartyB": shortCode,
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
          message: 'STK Push sent to $formattedPhone! Enter M-Pesa PIN on your phone.',
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
