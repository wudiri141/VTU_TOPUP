// lib/models/user_model.dart

class UserModel {
  final int    id;
  final String fullname, email, phone, role, token, referralCode;
  double       wallet;
  final int referralCount;
  final double referralEarnings;

  UserModel({required this.id, required this.fullname, required this.email,
    required this.phone, required this.wallet, required this.role, required this.token,
    this.referralCode = '', this.referralCount = 0, this.referralEarnings = 0.0});

  String get firstName => fullname.split(' ').first;

  factory UserModel.fromJson(Map<String, dynamic> j, {String token = ''}) => UserModel(
    id: int.tryParse(j['id']?.toString()??'0')??0, fullname:j['fullname']??'',
    email:j['email']??'', phone:j['phone']??'',
    wallet:double.tryParse(j['wallet']?.toString()??'0')??0.0, role:j['role']??'user',
    token:token, referralCode:j['referral_code']?.toString()??'',
    referralCount:int.tryParse(j['referral_count']?.toString()??'0')??0,
    referralEarnings:double.tryParse(j['referral_earnings']?.toString()??'0')??0.0);
}

class TransactionModel {
  final String source, service, network, phone, status, reference, description;
  final double amount;
  final DateTime createdAt;
  TransactionModel({required this.source, required this.service, required this.network,
    required this.phone, required this.amount, required this.status,
    required this.reference, required this.description, required this.createdAt});
  bool get isSuccess => status=='success'||status=='completed';
  bool get isFailed  => status=='failed';
  bool get isPending => status=='pending';
  factory TransactionModel.fromJson(Map<String, dynamic> j) => TransactionModel(
    source:j['source']??'', service:j['service']??'', network:j['network']??'',
    phone:j['phone']??'', amount:double.tryParse(j['amount']?.toString()??'0')??0.0,
    status:j['status']??'', reference:j['reference']??'', description:j['description']??'',
    createdAt:DateTime.tryParse(j['created_at']??'')??DateTime.now());
}

class DataPlanModel {
  final String planId, size, datatype;
  final int validityDays;
  final double sellPrice;
  DataPlanModel({required this.planId, required this.size, required this.datatype,
    required this.validityDays, required this.sellPrice});
  String get label => '$size — ₦${sellPrice.toStringAsFixed(0)} (${validityDays}d)';
  factory DataPlanModel.fromJson(Map<String, dynamic> j) => DataPlanModel(
    planId:j['data_plan_id']?.toString()??'', size:j['size']??'', datatype:j['datatype']??'',
    validityDays:int.tryParse(j['validity_days']?.toString()??'0')??0,
    sellPrice:double.tryParse(j['sell_price']?.toString()??'0')??0.0);
}

class DiscoModel {
  final String id, name;
  DiscoModel({required this.id, required this.name});
  factory DiscoModel.fromJson(Map<String, dynamic> j) => DiscoModel(
    id:j['electricity_plan_id']?.toString()??'', name:j['the_electricty_name']??'');
}

class CablePlanModel {
  final String id, name;
  final double price;
  CablePlanModel({required this.id, required this.name, required this.price});
  String get label => '$name — ₦${price.toStringAsFixed(0)}';
  factory CablePlanModel.fromJson(Map<String, dynamic> j) => CablePlanModel(
    id:j['id']?.toString()??'', name:j['name']??'',
    price:double.tryParse(j['price']?.toString()??'0')??0.0);
}
