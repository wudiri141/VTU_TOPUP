// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class ApiService {
  static const String _base    = 'https://vtutopup.com.ng/api';
  static const Duration _timeout = Duration(seconds: 30);

  static Map<String, String> _headers({String? token}) {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try { return jsonDecode(res.body) as Map<String, dynamic>; }
    catch (_) { return {'success': false, 'message': 'Unexpected server response.'}; }
  }

  // ── AUTH ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String firstName, required String lastName,
    required String email,     required String phone,
    required String password,  required String confirmPassword,
    required String pin,       String referralCode = '',
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth.php'), headers: _headers(),
        body: jsonEncode({'action':'register','first_name':firstName,'last_name':lastName,
          'email':email,'phone':phone,'password':password,
          'confirm_password':confirmPassword,'pin':pin,'referral_code':referralCode}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error. Check your connection.'}; }
  }

  static Future<Map<String, dynamic>> login({
    required String identity, required String password,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth.php'), headers: _headers(),
        body: jsonEncode({'action':'login','identity':identity,'password':password}),
      ).timeout(_timeout);
      final data = _decode(res);
      if (data['success'] == true) {
        final user = UserModel.fromJson(
            data['user'] as Map<String,dynamic>, token: data['token']??'');
        return {'success':true,'user':user,'message':data['message']};
      }
      return data;
    } catch (_) { return {'success':false,'message':'Network error. Check your connection.'}; }
  }

  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth.php'), headers: _headers(),
        body: jsonEncode({'action':'forgot_password','email':email}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error. Check your connection.'}; }
  }

  // ── PROFILE ACTIONS ─────────────────────────────────────
  static Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth.php'), headers: _headers(token: token),
        body: jsonEncode({'action':'change_password','current_password':currentPassword,
          'new_password':newPassword,'confirm_password':confirmPassword}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  static Future<Map<String, dynamic>> changePin({
    required String token,
    required String oldPin,
    required String newPin,
    required String confirmPin,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth.php'), headers: _headers(token: token),
        body: jsonEncode({'action':'change_pin','old_pin':oldPin,
          'new_pin':newPin,'confirm_pin':confirmPin}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  static Future<Map<String, dynamic>> sendSupportMessage({
    required String token,
    required String subject,
    required String message,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth.php'), headers: _headers(token: token),
        body: jsonEncode({'action':'support','subject':subject,'message':message}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  // ── WALLET ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWalletBalance(String token) async {
    try {
      final res = await http.get(Uri.parse('$_base/wallet.php?action=balance'),
          headers: _headers(token: token)).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  static Future<List<TransactionModel>> getTransactions(String token,
      {int page=1, int limit=20}) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/wallet.php?action=transactions&page=$page&limit=$limit'),
        headers: _headers(token: token)).timeout(_timeout);
      final data = _decode(res);
      if (data['success']==true)
        return (data['transactions'] as List)
            .map((j) => TransactionModel.fromJson(j)).toList();
      return [];
    } catch (_) { return []; }
  }

  // ── DATA ────────────────────────────────────────────────
  static Future<List<DataPlanModel>> getDataPlans(String token, String network) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/services.php?action=data_plans&network=${network.toUpperCase()}'),
        headers: _headers(token: token)).timeout(_timeout);
      final data = _decode(res);
      if (data['success']==true)
        return (data['plans'] as List).map((j) => DataPlanModel.fromJson(j)).toList();
      return [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> buyAirtime({
    required String token, required String network,
    required String phone,  required double amount, required String pin,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/services.php?action=buy_airtime'), headers: _headers(token: token),
        body: jsonEncode({'network':network,'phone':phone,'amount':amount,'pin':pin}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  static Future<Map<String, dynamic>> buyData({
    required String token, required String network,
    required String phone,  required String planId, required String pin,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/services.php?action=buy_data'), headers: _headers(token: token),
        body: jsonEncode({'network':network,'phone':phone,'plan_id':planId,'pin':pin}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  // ── ELECTRICITY ─────────────────────────────────────────
  static Future<List<DiscoModel>> getElectricityDiscos(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/services.php?action=electricity_discos'),
        headers: _headers(token: token)).timeout(_timeout);
      final data = _decode(res);
      if (data['success']==true)
        return (data['discos'] as List).map((j) => DiscoModel.fromJson(j)).toList();
      return [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> verifyMeter({
    required String token, required String discoId, required String meterNumber,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/services.php?action=verify_meter'), headers: _headers(token: token),
        body: jsonEncode({'disco_name':discoId,'meter_number':meterNumber}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  static Future<Map<String, dynamic>> buyElectricity({
    required String token,       required String discoId,
    required String meterNumber, required String meterType,
    required double amount,      required String pin,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/services.php?action=buy_electricity'), headers: _headers(token: token),
        body: jsonEncode({'disco_name':discoId,'meter_number':meterNumber,
          'meter_type':meterType,'amount':amount,'pin':pin}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  // ── CABLE TV ────────────────────────────────────────────
  static Future<List<CablePlanModel>> getCablePlans(String token, String cablename) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/services.php?action=cable_plans&cablename=$cablename'),
        headers: _headers(token: token)).timeout(_timeout);
      final data = _decode(res);
      if (data['success']==true)
        return (data['plans'] as List).map((j) => CablePlanModel.fromJson(j)).toList();
      return [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> verifySmartcard({
    required String token, required String cablename, required String smartcard,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/services.php?action=verify_smartcard'), headers: _headers(token: token),
        body: jsonEncode({'cablename':cablename,'smart_card_number':smartcard}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }

  static Future<Map<String, dynamic>> buyCable({
    required String token,     required String cablename,
    required String smartcard, required String planId, required String pin,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/services.php?action=buy_cable'), headers: _headers(token: token),
        body: jsonEncode({'cablename':cablename,'smart_card_number':smartcard,
          'cableplan':planId,'pin':pin}),
      ).timeout(_timeout);
      return _decode(res);
    } catch (_) { return {'success':false,'message':'Network error.'}; }
  }
}
