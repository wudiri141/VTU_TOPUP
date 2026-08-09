// lib/screens/dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'login.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';

String _formatMoney(num value, {bool decimals = true}) {
  final fixed = value.toStringAsFixed(decimals ? 2 : 0);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  return parts.length == 1 ? whole : '$whole.${parts.last}';
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _transactionTitle(TransactionModel tx) {
  final network = tx.network.isNotEmpty ? '${tx.network} ' : '';
  final service = tx.service.isNotEmpty ? tx.service.toUpperCase() : 'TRANSACTION';
  return '$network$service';
}

String _transactionDetailsText(TransactionModel tx) {
  return [
    'VTU TOPUP Transaction',
    'Service: ${_transactionTitle(tx)}',
    'Amount: NGN ${_formatMoney(tx.amount)}',
    'Status: ${tx.status}',
    if (tx.phone.isNotEmpty) 'Phone: ${tx.phone}',
    if (tx.reference.isNotEmpty) 'Reference: ${tx.reference}',
    if (tx.description.isNotEmpty) 'Description: ${tx.description}',
    'Date: ${_formatDate(tx.createdAt)}',
  ].join('\n');
}

String _safeReceiptName(TransactionModel tx) {
  final ref = tx.reference.isNotEmpty
      ? tx.reference
      : DateTime.now().millisecondsSinceEpoch.toString();
  final safeRef = ref.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return 'vtu_topup_receipt_$safeRef.png';
}

Future<File> _captureReceiptImage(GlobalKey key, TransactionModel tx) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_safeReceiptName(tx)}');
  return file.writeAsBytes(bytes, flush: true);
}

Future<bool> _saveReceiptToGallery(File file, TransactionModel tx) async {
  if (Platform.isAndroid) {
    const channel = MethodChannel('vtu_topup/media');
    final saved = await channel.invokeMethod<bool>('saveImage', {
      'path': file.path,
      'name': _safeReceiptName(tx),
    });
    return saved == true;
  }
  return false;
}

Future<bool> _confirmExit(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Exit VTU TOPUP?'),
      content: Text('Do you want to exit the app?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('No'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text('Yes', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return shouldExit ?? false;
}

void _showTransactionDetails(BuildContext context, TransactionModel tx) {
  final details = _transactionDetailsText(tx);
  final receiptKey = GlobalKey();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheetContext) {
      void copyWithMessage(String message) {
        Clipboard.setData(ClipboardData(text: details));
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ));
      }

      Future<void> shareReceiptImage() async {
        try {
          final file = await _captureReceiptImage(receiptKey, tx);
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/png')],
            text: 'VTU TOPUP transaction receipt',
          );
        } catch (_) {
          copyWithMessage('Could not share image. Receipt details copied.');
        }
      }

      Future<void> saveReceiptImage() async {
        try {
          final file = await _captureReceiptImage(receiptKey, tx);
          final saved = await _saveReceiptToGallery(file, tx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(saved
                ? 'Receipt image saved to gallery'
                : 'Receipt image saved to app files'),
            backgroundColor: saved ? Colors.green : AppColors.primary,
          ));
        } catch (_) {
          copyWithMessage('Could not save image. Receipt details copied.');
        }
      }

      final statusColor = tx.isSuccess
          ? Colors.green
          : tx.isFailed
              ? Colors.red
              : Colors.orange;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4)),
            ),
            SizedBox(height: 18),
            RepaintBoundary(
              key: receiptKey,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child:
                          Icon(Icons.receipt_long, color: AppColors.primary),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VTU TOPUP Receipt',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text(_transactionTitle(tx),
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12)),
                          ]),
                    ),
                    Text(tx.status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ]),
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      _DetailRow('Amount', '₦${_formatMoney(tx.amount)}'),
                      if (tx.phone.isNotEmpty) _DetailRow('Phone', tx.phone),
                      if (tx.reference.isNotEmpty)
                        _DetailRow('Reference', tx.reference),
                      if (tx.description.isNotEmpty)
                        _DetailRow('Description', tx.description),
                      _DetailRow('Date', _formatDate(tx.createdAt)),
                    ]),
                  ),
                ]),
              ),
            ),
            SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: shareReceiptImage,
                  icon: Icon(Icons.share_outlined, size: 18),
                  label: Text('Share'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saveReceiptImage,
                  icon: Icon(Icons.save_alt, size: 18),
                  label: Text('Save'),
                ),
              ),
            ]),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => copyWithMessage('Transaction details copied'),
                icon: Icon(Icons.copy, size: 18),
                label: Text('Copy Details'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ),
          ]),
        ),
      );
    },
  );
}

void _showInAppTransactionNotice(BuildContext context, String message) {
  NotificationService.transaction(
    title: 'VTU TOPUP Transaction',
    body: message,
  );
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(Icons.notifications_active_outlined, color: Colors.white, size: 20),
      SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]),
    backgroundColor: AppColors.primary,
    behavior: SnackBarBehavior.floating,
  ));
}

// ─────────────────────────────────────────────────────────────
// PIN MODAL
// ─────────────────────────────────────────────────────────────
Future<String?> showPinModal(BuildContext context) async {
  final ctrl = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 20),
          Icon(Icons.lock_outline, color: AppColors.primary, size: 40),
          SizedBox(height: 8),
          Text("Enter Transaction PIN",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Enter your 4-digit PIN to confirm",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          SizedBox(height: 20),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, letterSpacing: 16),
            decoration: InputDecoration(
              counterText: '',
              hintText: '● ● ● ●',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text("Cancel"),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (ctrl.text.length == 4) {
                    Navigator.pop(ctx, ctrl.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text("Confirm",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
          SizedBox(height: 24),
        ]),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────
void showSuccessDialog(BuildContext context,
    {required String title,
    required String message,
    required String ref,
    String? extra}) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child:
                Icon(Icons.check_circle, color: AppColors.primary, size: 44),
          ),
          SizedBox(height: 16),
          Text(title,
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87)),
          if (extra != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(extra,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600)),
            ),
          ],
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text("A receipt has been sent to your email.",
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 12)),
              ),
            ]),
          ),
          SizedBox(height: 6),
          Text("Ref: $ref",
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text("Done",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// DASHBOARD
// ─────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final UserModel user;
  const DashboardScreen({required this.user});
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  late UserModel _user;
  bool _showAmounts = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _refreshWallet() async {
    final res = await ApiService.getWalletBalance(_user.token);
    if (res['success'] == true && mounted) {
      setState(() {
        _user.wallet = (res['wallet'] as num).toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
          user: _user,
          onRefresh: _refreshWallet,
          showAmounts: _showAmounts,
          onToggleAmounts: () => setState(() => _showAmounts = !_showAmounts),
          onFundWallet: () => setState(() => _tab = 2),
          onViewTransactions: () => setState(() => _tab = 1)),
      TransactionTab(
          user: _user,
          showAmounts: _showAmounts),
      WalletTab(
          user: _user,
          onRefresh: _refreshWallet,
          showAmounts: _showAmounts,
          onToggleAmounts: () => setState(() => _showAmounts = !_showAmounts)),
      ProfileTab(user: _user),
    ];
    return WillPopScope(
      onWillPop: () => _confirmExit(context),
      child: Scaffold(
        body: pages[_tab],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _tab = i),
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long), label: 'Transaction'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────
class HomeTab extends StatefulWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  final bool showAmounts;
  final VoidCallback onToggleAmounts;
  final VoidCallback onFundWallet;
  final VoidCallback onViewTransactions;
  const HomeTab({
    required this.user,
    required this.onRefresh,
    required this.showAmounts,
    required this.onToggleAmounts,
    required this.onFundWallet,
    required this.onViewTransactions,
  });
  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<TransactionModel> _txns = [];
  bool _loadingTxns = true;

  @override
  void initState() {
    super.initState();
    _loadTxns();
  }

  Future<void> _loadTxns() async {
    final list =
        await ApiService.getTransactions(widget.user.token, limit: 5);
    if (mounted) {
      setState(() {
        _txns = list;
        _loadingTxns = false;
      });
    }
  }

  void _push(Widget s) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => s));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            widget.onRefresh();
            await _loadTxns();
          },
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                color: AppColors.dark,
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                AssetImage('assets/logo.png')),
                        SizedBox(width: 10),
                        Text('VTU TOPUP',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ]),
                      Icon(Icons.notifications_outlined,
                          color: Colors.white),
                    ]),
              ),

              // Wallet card
              Container(
                color: AppColors.primary,
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, ${widget.user.firstName}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: AppColors.primary,
                                    size: 20),
                                SizedBox(width: 8),
                                Text('Wallet Balance',
                                    style:
                                        TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  child: Icon(Icons.credit_card,
                                      color: AppColors.primary, size: 24),
                                ),
                              ]),
                              SizedBox(height: 12),
                              Row(children: [
                                Flexible(
                                  child: Text(
                                      widget.showAmounts
                                          ? '₦${_formatMoney(widget.user.wallet)}'
                                          : '₦ ****',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold)),
                                ),
                                SizedBox(width: 6),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      BoxConstraints(minWidth: 36, minHeight: 36),
                                  tooltip: widget.showAmounts
                                      ? 'Hide balance'
                                      : 'Show balance',
                                  onPressed: widget.onToggleAmounts,
                                  icon: Icon(
                                      widget.showAmounts
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: AppColors.primary),
                                ),
                              ]),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: widget.onFundWallet,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 10)),
                                child: Text('Fund Wallet',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ]),
                      ),
                    ]),
              ),

              SizedBox(height: 20),

              // Quick actions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _QuickBtn(
                        icon: Icons.phone,
                        label: 'Airtime',
                        color: AppColors.airtime,
                        onTap: () => _push(BuyAirtimeScreen(
                            user: widget.user,
                            onSuccess: widget.onRefresh))),
                    _QuickBtn(
                        icon: Icons.wifi,
                        label: 'Data',
                        color: AppColors.data,
                        onTap: () => _push(BuyDataScreen(
                            user: widget.user,
                            onSuccess: widget.onRefresh))),
                    _QuickBtn(
                        icon: Icons.bolt,
                        label: 'Electricity',
                        color: AppColors.electricity,
                        onTap: () => _push(ElectricityScreen(
                            user: widget.user,
                            onSuccess: widget.onRefresh))),
                    _QuickBtn(
                        icon: Icons.tv,
                        label: 'Cable',
                        color: AppColors.cable,
                        onTap: () => _push(CableScreen(
                            user: widget.user,
                            onSuccess: widget.onRefresh))),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Recent Transactions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Transactions',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: widget.onViewTransactions,
                        child: Text('View All',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
              ),
              SizedBox(height: 12),

              if (_loadingTxns)
                Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: AppColors.primary)))
              else if (_txns.isEmpty)
                Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No transactions yet.',
                            style: TextStyle(color: Colors.grey))))
              else
                ..._txns.map((t) =>
                    _TxnTile(tx: t, showAmount: widget.showAmounts)),

              SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2))
            ],
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final TransactionModel tx;
  final bool showAmount;
  const _TxnTile({required this.tx, this.showAmount = true});

  @override
  Widget build(BuildContext context) {
    final iconData = tx.service == 'electricity'
        ? Icons.bolt
        : tx.service == 'cable'
            ? Icons.tv
            : tx.service == 'data'
                ? Icons.wifi
                : Icons.phone;
    final iconColor = tx.service == 'electricity'
        ? AppColors.electricity
        : tx.service == 'cable'
            ? AppColors.cable
            : tx.service == 'data'
                ? AppColors.data
                : tx.network == 'MTN'
                    ? Color(0xFFFFCC00)
                    : tx.network == 'AIRTEL'
                        ? Color(0xFFE40000)
                        : tx.network == 'GLO'
                            ? Color(0xFF006400)
                            : AppColors.primary;
    final statusColor = tx.isSuccess
        ? Colors.green
        : tx.isFailed
            ? Colors.red
            : Colors.orange;

    return InkWell(
      onTap: () => _showTransactionDetails(context, tx),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 6,
                  offset: Offset(0, 2))
            ]),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_transactionTitle(tx),
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(_formatDate(tx.createdAt),
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(showAmount ? '₦${_formatMoney(tx.amount)}' : '••••',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(tx.status,
                style: TextStyle(color: statusColor, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 92,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────
class _ServiceAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      centerTitle: true,
      leading: BackButton(color: Colors.black),
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
            radius: 16,
            backgroundImage: AssetImage('assets/logo.png')),
        SizedBox(width: 8),
        Text('VTU TOPUP',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ]),
    );
  }
}

Widget _buildInputField(TextEditingController ctrl, String hint,
    IconData icon,
    {TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    bool obscure = false}) {
  return TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    obscureText: obscure,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
    ),
  );
}

Widget _buildActionBtn(String label, VoidCallback? onTap,
    {bool loading = false}) {
  return SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30))),
      child: loading
          ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          : Text(label,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
    ),
  );
}

class _NetworkSelector extends StatelessWidget {
  final int selectedIdx;
  final List<String> networks;
  final List<Color> colors;
  final Function(int) onSelect;
  const _NetworkSelector(
      {required this.selectedIdx,
      required this.networks,
      required this.colors,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(networks.length, (i) {
        final sel = selectedIdx == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              margin:
                  EdgeInsets.only(right: i < networks.length - 1 ? 8 : 0),
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: sel ? AppColors.primary : Colors.transparent,
                    width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4)
                ],
              ),
              child: Column(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: colors[i],
                    child: Text(networks[i][0],
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold))),
                SizedBox(height: 5),
                Text(networks[i],
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BUY AIRTIME
// ─────────────────────────────────────────────────────────────
class BuyAirtimeScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSuccess;
  const BuyAirtimeScreen({required this.user, required this.onSuccess});
  @override
  _BuyAirtimeScreenState createState() => _BuyAirtimeScreenState();
}

class _BuyAirtimeScreenState extends State<BuyAirtimeScreen> {
  int _netIdx = 0;
  String _quickAmt = '';
  bool _loading = false;
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _networks = ['MTN', 'AIRTEL', 'GLO', '9MOBILE'];
  final _colors = [
    Color(0xFFFFCC00),
    Color(0xFFE40000),
    Color(0xFF006400),
    Color(0xFF006400)
  ];
  final _quickAmts = ['100', '200', '500', '1000'];

  Future<void> _buy() async {
    final phone = _phoneCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (phone.isEmpty) {
      _snack('Enter phone number', err: true);
      return;
    }
    if (amount < 50) {
      _snack('Minimum is ₦50', err: true);
      return;
    }
    final pin = await showPinModal(context);
    if (pin == null) return;
    setState(() => _loading = true);
    final res = await ApiService.buyAirtime(
        token: widget.user.token,
        network: _networks[_netIdx],
        phone: phone,
        amount: amount,
        pin: pin);
    setState(() => _loading = false);
    if (res['success'] == true) {
      widget.onSuccess();
      _showInAppTransactionNotice(
          context, 'Airtime transaction completed successfully.');
      showSuccessDialog(context,
          title: 'Airtime Successful!',
          message:
              '₦${_formatMoney(amount, decimals: false)} airtime sent to $phone.',
          ref: res['ref'] ?? '');
    } else {
      _snack(res['message'] ?? 'Failed', err: true);
    }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: err ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: _ServiceAppBar(),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Buy Airtime',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          _NetworkSelector(
              selectedIdx: _netIdx,
              networks: _networks,
              colors: _colors,
              onSelect: (i) => setState(() => _netIdx = i)),
          SizedBox(height: 20),
          _buildInputField(_phoneCtrl, 'Phone number', Icons.smartphone,
              keyboardType: TextInputType.phone,
              suffix: Icon(Icons.person_outline, color: Colors.grey)),
          SizedBox(height: 12),
          _buildInputField(_amountCtrl, 'Amount', Icons.attach_money,
              keyboardType: TextInputType.number),
          SizedBox(height: 14),
          Row(
            children: _quickAmts.map((a) {
              final sel = _quickAmt == a;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _quickAmt = a);
                    _amountCtrl.text = a;
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                        right: a != _quickAmts.last ? 8 : 0),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary, width: 1),
                    ),
                    child: Center(
                      child: Text('₦$a',
                          style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Spacer(),
          _buildActionBtn('Buy Airtime', _buy, loading: _loading),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BUY DATA
// ─────────────────────────────────────────────────────────────
class BuyDataScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSuccess;
  const BuyDataScreen({required this.user, required this.onSuccess});
  @override
  _BuyDataScreenState createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  int _netIdx = 0;
  bool _loading = false;
  bool _loadingPlans = false;
  List<DataPlanModel> _plans = [];
  List<String> _types = [];
  String? _selectedType;
  DataPlanModel? _selectedPlan;
  final _phoneCtrl = TextEditingController();
  final _networks = ['MTN', 'AIRTEL', 'GLO', '9MOBILE'];
  final _colors = [
    Color(0xFFFFCC00),
    Color(0xFFE40000),
    Color(0xFF006400),
    Color(0xFF006400)
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _loadingPlans = true;
      _plans = [];
      _types = [];
      _selectedType = null;
      _selectedPlan = null;
    });
    final p = await ApiService.getDataPlans(
        widget.user.token, _networks[_netIdx]);
    if (mounted) {
      setState(() {
        _plans = p;
        _types = p
            .map((plan) => plan.datatype)
            .where((type) => type.trim().isNotEmpty)
            .toSet()
            .toList();
        _loadingPlans = false;
      });
    }
  }

  Future<void> _buy() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      _snack('Enter phone number', err: true);
      return;
    }
    if (_selectedPlan == null) {
      _snack('Select a data plan', err: true);
      return;
    }
    final pin = await showPinModal(context);
    if (pin == null) return;
    setState(() => _loading = true);
    final res = await ApiService.buyData(
        token: widget.user.token,
        network: _networks[_netIdx],
        phone: _phoneCtrl.text.trim(),
        planId: _selectedPlan!.planId,
        pin: pin);
    setState(() => _loading = false);
    if (res['success'] == true) {
      widget.onSuccess();
      _showInAppTransactionNotice(
          context, 'Data transaction completed successfully.');
      showSuccessDialog(context,
          title: 'Data Purchase Successful!',
          message:
              '${_selectedPlan!.size} sent to ${_phoneCtrl.text.trim()}.',
          ref: res['ref'] ?? '');
    } else {
      _snack(res['message'] ?? 'Failed', err: true);
    }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: err ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: _ServiceAppBar(),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Buy Data',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          _NetworkSelector(
              selectedIdx: _netIdx,
              networks: _networks,
              colors: _colors,
              onSelect: (i) {
                setState(() => _netIdx = i);
                _fetchPlans();
              }),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: _loadingPlans
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text('Choose data type',
                          style: TextStyle(color: Colors.grey)),
                      value: _selectedType,
                      onChanged: (v) => setState(() {
                        _selectedType = v;
                        _selectedPlan = null;
                      }),
                      items: _types
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  style: TextStyle(fontSize: 13))))
                          .toList(),
                    )),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: _loadingPlans
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<DataPlanModel>(
                      isExpanded: true,
                      hint: Text('Choose a data plan',
                          style: TextStyle(color: Colors.grey)),
                      value: _selectedPlan,
                      onChanged: (v) => setState(() => _selectedPlan = v),
                      items: _plans
                          .where((p) => _selectedType == null
                              ? false
                              : p.datatype == _selectedType)
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.label,
                                  style: TextStyle(fontSize: 13))))
                          .toList(),
                    )),
          ),
          SizedBox(height: 12),
          _buildInputField(_phoneCtrl, 'Phone number', Icons.smartphone,
              keyboardType: TextInputType.phone,
              suffix: Icon(Icons.person_outline, color: Colors.grey)),
          Spacer(),
          _buildActionBtn('Buy Data', _buy, loading: _loading),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ELECTRICITY
// ─────────────────────────────────────────────────────────────
class ElectricityScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSuccess;
  const ElectricityScreen(
      {required this.user, required this.onSuccess});
  @override
  _ElectricityScreenState createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  bool _loading = false;
  bool _loadingDiscos = true;
  bool _verifying = false;
  bool _verified = false;
  String _meterType = 'prepaid';
  String _customerName = '';
  String _quickAmt = '';
  DiscoModel? _selectedDisco;
  List<DiscoModel> _discos = [];
  final _meterCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _quickAmts = ['1000', '2000', '5000', '10000'];

  @override
  void initState() {
    super.initState();
    _loadDiscos();
  }

  Future<void> _loadDiscos() async {
    final list =
        await ApiService.getElectricityDiscos(widget.user.token);
    if (mounted) {
      setState(() {
        _discos = list;
        _loadingDiscos = false;
      });
    }
  }

  Future<void> _verify() async {
    if (_selectedDisco == null) {
      _snack('Select a disco', err: true);
      return;
    }
    if (_meterCtrl.text.trim().isEmpty) {
      _snack('Enter meter number', err: true);
      return;
    }
    setState(() {
      _verifying = true;
      _verified = false;
      _customerName = '';
    });
    final res = await ApiService.verifyMeter(
        token: widget.user.token,
        discoId: _selectedDisco!.id,
        meterNumber: _meterCtrl.text.trim());
    if (mounted) {
      setState(() {
        _verifying = false;
        if (res['success'] == true) {
          _verified = true;
          _customerName = res['customer_name'] ?? 'Verified';
        } else {
          _snack(res['message'] ?? 'Verification failed', err: true);
        }
      });
    }
  }

  Future<void> _buy() async {
    if (!_verified) {
      _snack('Verify meter first', err: true);
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 100) {
      _snack('Minimum is ₦100', err: true);
      return;
    }
    final pin = await showPinModal(context);
    if (pin == null) return;
    setState(() => _loading = true);
    final res = await ApiService.buyElectricity(
        token: widget.user.token,
        discoId: _selectedDisco!.id,
        meterNumber: _meterCtrl.text.trim(),
        meterType: _meterType,
        amount: amount,
        pin: pin);
    setState(() => _loading = false);
    if (res['success'] == true) {
      widget.onSuccess();
      final tok = res['token'] as String? ?? '';
      _showInAppTransactionNotice(
          context, 'Electricity transaction completed successfully.');
      showSuccessDialog(context,
          title: 'Electricity Successful!',
          message:
              '₦${_formatMoney(amount, decimals: false)} paid for meter ${_meterCtrl.text.trim()}.',
          ref: res['ref'] ?? '',
          extra: tok.isNotEmpty ? '🔑 Token: $tok' : null);
      _meterCtrl.clear();
      _amountCtrl.clear();
      setState(() {
        _verified = false;
        _customerName = '';
      });
    } else {
      _snack(res['message'] ?? 'Failed', err: true);
    }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: err ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: _ServiceAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pay Electricity',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          if (_loadingDiscos)
            Center(
                child: CircularProgressIndicator(color: AppColors.primary))
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DiscoModel>(
                  isExpanded: true,
                  hint: Text('Select Electricity Disco',
                      style: TextStyle(color: Colors.grey)),
                  value: _selectedDisco,
                  onChanged: (v) {
                    setState(() {
                      _selectedDisco = v;
                      _verified = false;
                      _customerName = '';
                    });
                  },
                  items: _discos
                      .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.name,
                              style: TextStyle(fontSize: 13))))
                      .toList(),
                ),
              ),
            ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: ['prepaid', 'postpaid'].map((t) {
                final sel = _meterType == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _meterType = t;
                        _verified = false;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          t[0].toUpperCase() + t.substring(1),
                          style: TextStyle(
                              color: sel ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _buildInputField(
                  _meterCtrl, 'Meter number', Icons.electric_meter,
                  keyboardType: TextInputType.number),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: _verifying ? null : _verify,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _verifying
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Verify',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
            ),
          ]),
          if (_verified) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text('✅ $_customerName',
                      style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
          SizedBox(height: 12),
          _buildInputField(
              _amountCtrl, 'Amount (min ₦100)', Icons.attach_money,
              keyboardType: TextInputType.number),
          SizedBox(height: 12),
          Row(
            children: _quickAmts.map((a) {
              final sel = _quickAmt == a;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _quickAmt = a);
                    _amountCtrl.text = a;
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                        right: a != _quickAmts.last ? 8 : 0),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary, width: 1),
                    ),
                    child: Center(
                      child: Text('₦$a',
                          style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 24),
          _buildActionBtn('Pay Electricity', _verified ? _buy : null,
              loading: _loading),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CABLE
// ─────────────────────────────────────────────────────────────
class CableScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSuccess;
  const CableScreen({required this.user, required this.onSuccess});
  @override
  _CableScreenState createState() => _CableScreenState();
}

class _CableScreenState extends State<CableScreen> {
  int _providerIdx = 0;
  bool _loading = false;
  bool _loadingPlans = false;
  bool _verifying = false;
  bool _verified = false;
  String _customerName = '';
  List<CablePlanModel> _plans = [];
  CablePlanModel? _selectedPlan;
  final _smartCtrl = TextEditingController();
  final _providers = ['GOTV', 'DSTV', 'STARTIMES', 'SHOWMAX'];
  final _providerIds = ['1', '2', '3', '4'];
  final _providerColors = [
    Color(0xFFE40000),
    Color(0xFF0057A8),
    Color(0xFFE87722),
    Color(0xFF1DB954)
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _loadingPlans = true;
      _plans = [];
      _selectedPlan = null;
    });
    final p = await ApiService.getCablePlans(
        widget.user.token, _providerIds[_providerIdx]);
    if (mounted) {
      setState(() {
        _plans = p;
        _loadingPlans = false;
      });
    }
  }

  Future<void> _verify() async {
    if (_smartCtrl.text.trim().isEmpty) {
      _snack('Enter smartcard number', err: true);
      return;
    }
    setState(() {
      _verifying = true;
      _verified = false;
      _customerName = '';
    });
    final res = await ApiService.verifySmartcard(
        token: widget.user.token,
        cablename: _providerIds[_providerIdx],
        smartcard: _smartCtrl.text.trim());
    if (mounted) {
      setState(() {
        _verifying = false;
        if (res['success'] == true) {
          _verified = true;
          _customerName = res['customer_name'] ?? 'Verified';
        } else {
          _snack(res['message'] ?? 'Verification failed', err: true);
        }
      });
    }
  }

  Future<void> _buy() async {
    if (!_verified) {
      _snack('Verify smartcard first', err: true);
      return;
    }
    if (_selectedPlan == null) {
      _snack('Select a plan', err: true);
      return;
    }
    final pin = await showPinModal(context);
    if (pin == null) return;
    setState(() => _loading = true);
    final res = await ApiService.buyCable(
        token: widget.user.token,
        cablename: _providerIds[_providerIdx],
        smartcard: _smartCtrl.text.trim(),
        planId: _selectedPlan!.id,
        pin: pin);
    setState(() => _loading = false);
    if (res['success'] == true) {
      widget.onSuccess();
      _showInAppTransactionNotice(
          context, 'Cable transaction completed successfully.');
      showSuccessDialog(context,
          title: 'Cable Subscription Successful!',
          message: '${_selectedPlan!.name} subscribed.',
          ref: res['ref'] ?? '');
      _smartCtrl.clear();
      setState(() {
        _verified = false;
        _customerName = '';
        _selectedPlan = null;
      });
    } else {
      _snack(res['message'] ?? 'Failed', err: true);
    }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: err ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: _ServiceAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cable Subscription',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Row(
            children: List.generate(_providers.length, (i) {
              final sel = _providerIdx == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _providerIdx = i;
                      _verified = false;
                      _customerName = '';
                    });
                    _fetchPlans();
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                        right: i < _providers.length - 1 ? 8 : 0),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4)
                      ],
                    ),
                    child: Column(children: [
                      CircleAvatar(
                          radius: 18,
                          backgroundColor: _providerColors[i],
                          child: Text(_providers[i][0],
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12))),
                      SizedBox(height: 5),
                      Text(_providers[i],
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: _buildInputField(
                  _smartCtrl, 'Smartcard / IUC number', Icons.credit_card,
                  keyboardType: TextInputType.number),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: _verifying ? null : _verify,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _verifying
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Verify',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
            ),
          ]),
          if (_verified) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text('✅ $_customerName',
                      style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: _loadingPlans
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<CablePlanModel>(
                      isExpanded: true,
                      hint: Text('Select a plan',
                          style: TextStyle(color: Colors.grey)),
                      value: _selectedPlan,
                      onChanged: (v) =>
                          setState(() => _selectedPlan = v),
                      items: _plans
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.label,
                                  style: TextStyle(fontSize: 13))))
                          .toList(),
                    )),
          ),
          SizedBox(height: 24),
          _buildActionBtn(
              'Subscribe',
              _verified && _selectedPlan != null ? _buy : null,
              loading: _loading),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TRANSACTION TAB
// ─────────────────────────────────────────────────────────────
class TransactionTab extends StatefulWidget {
  final UserModel user;
  final bool showAmounts;
  const TransactionTab({
    required this.user,
    required this.showAmounts,
  });
  @override
  _TransactionTabState createState() => _TransactionTabState();
}

class _TransactionTabState extends State<TransactionTab> {
  List<TransactionModel> _txns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await ApiService.getTransactions(widget.user.token, limit: 50);
    if (mounted) {
      setState(() {
        _txns = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.dark,
          automaticallyImplyLeading: false,
          title: Text('Transactions', style: TextStyle(color: Colors.white))),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _txns.isEmpty
              ? Center(
                  child: Text('No transactions yet.',
                      style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                      children:
                          _txns
                              .map((t) => _TxnTile(
                                  tx: t, showAmount: widget.showAmounts))
                              .toList())),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WALLET TAB
// ─────────────────────────────────────────────────────────────
class WalletTab extends StatefulWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  final bool showAmounts;
  final VoidCallback onToggleAmounts;
  const WalletTab({
    required this.user,
    required this.onRefresh,
    required this.showAmounts,
    required this.onToggleAmounts,
  });
  @override
  _WalletTabState createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  String _bankName = '';
  String _acctNo = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getWalletBalance(widget.user.token);
    if (res['success'] == true && mounted) {
      setState(() {
        widget.user.wallet = (res['wallet'] as num).toDouble();
        _bankName = res['virtual_bank_name'] ?? 'OPay';
        _acctNo = res['virtual_account_number'] ?? '';
        _loading = false;
      });
      widget.onRefresh();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.dark,
          automaticallyImplyLeading: false,
          title: Text('Wallet', style: TextStyle(color: Colors.white))),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(padding: EdgeInsets.all(20), children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wallet Balance',
                            style: TextStyle(color: Colors.black)),
                        SizedBox(height: 8),
                        Row(children: [
                          Flexible(
                            child: Text(
                                widget.showAmounts
                                    ? '₦${_formatMoney(widget.user.wallet)}'
                                    : '₦ ****',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(width: 6),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints:
                                BoxConstraints(minWidth: 36, minHeight: 36),
                            tooltip: widget.showAmounts
                                ? 'Hide balance'
                                : 'Show balance',
                            onPressed: widget.onToggleAmounts,
                            icon: Icon(
                                widget.showAmounts
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: AppColors.primary),
                          ),
                        ]),
                      ]),
                ),
                SizedBox(height: 24),
                if (_acctNo.isNotEmpty) ...[
                  Text('Fund via Bank Transfer',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6)
                        ]),
                    child: Column(children: [
                      _InfoRow('Bank Name', _bankName),
                      Divider(height: 20),
                      _InfoRow('Account Number', _acctNo),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _acctNo));
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Account number copied!')));
                        },
                        icon: Icon(Icons.copy),
                        label: Text('Copy Account Number'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12))),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
      Text(label,
          style: TextStyle(
              color: Colors.grey, fontWeight: FontWeight.w500)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────────────────────
class ProfileTab extends StatelessWidget {
  final UserModel user;
  const ProfileTab({required this.user});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Logout?'),
        content: Text('Do you want to logout of VTU TOPUP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
          backgroundColor: AppColors.dark,
          automaticallyImplyLeading: false,
          title: Text('Profile', style: TextStyle(color: Colors.white))),
      body: ListView(children: [
        // Profile header
        Container(
          color: AppColors.dark,
          padding: EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(children: [
            CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(Icons.person,
                    size: 44, color: AppColors.primary)),
            SizedBox(height: 12),
            Text(user.fullname,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(user.email,
                style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
            Text(user.phone,
                style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),

        SizedBox(height: 16),
        _ReferralCard(user: user),

        _ProfSection('Security', [
          _ProfTileData(Icons.lock_outline, 'Change Password', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ChangePasswordScreen(user: user)));
          }),
          _ProfTileData(Icons.pin_outlined, 'Change Transaction PIN',
              () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChangePinScreen(user: user)));
          }),
        ]),

        _ProfSection('Help & Support', [
          _ProfTileData(Icons.support_agent_outlined, 'Contact Support',
              () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SupportScreen(user: user)));
          }),
          _ProfTileData(Icons.info_outline, 'About VTU TOPUP', () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AboutVtuTopupScreen()));
          }),
        ]),

        _ProfSection('Account', [
          _ProfTileData(Icons.logout, 'Logout', () => _logout(context),
              isRed: true),
        ]),

        SizedBox(height: 30),
      ]),
    );
  }
}

class AboutVtuTopupScreen extends StatelessWidget {
  const AboutVtuTopupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('About VTU TOPUP', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(padding: EdgeInsets.all(20), children: [
        Center(
          child: Column(children: [
            Image.asset('assets/logo.png', width: 92, height: 92),
            SizedBox(height: 12),
            Text('VTU TOPUP',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            SizedBox(height: 4),
            Text('Your media, airtime, data, bills and wallet services in one app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
          ]),
        ),
        SizedBox(height: 24),
        _AboutBlock(
          icon: Icons.phone_android,
          title: 'What We Do',
          text:
              'VTU TOPUP helps users buy airtime, data, electricity tokens and cable subscriptions quickly from a single wallet.',
        ),
        _AboutBlock(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Wallet Services',
          text:
              'Fund your wallet by bank transfer, track your balance, and review every transaction from the dashboard or transaction page.',
        ),
        _AboutBlock(
          icon: Icons.receipt_long,
          title: 'Transaction Records',
          text:
              'Each transaction includes the amount, status, reference, date and service details so you can copy, share or keep the record.',
        ),
        _AboutBlock(
          icon: Icons.support_agent_outlined,
          title: 'Support',
          text:
              'For wallet funding, failed purchases, refunds or account help, use Contact Support from the profile page.',
        ),
      ]),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _AboutBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE5E7EB))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary),
        ),
        SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textDark)),
            SizedBox(height: 6),
            Text(text,
                style: TextStyle(
                    color: AppColors.textMuted, height: 1.35, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final UserModel user;
  const _ReferralCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final code = user.referralCode;
    final link = code.isEmpty
        ? ''
        : 'https://vtutopup.com.ng/register.php?ref=$code';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: Icon(Icons.card_giftcard_outlined,
                  color: AppColors.primary, size: 20)),
          SizedBox(width: 12),
          Expanded(
            child: Text('Referral',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: _InfoRow('Code', code.isEmpty ? 'Unavailable' : code)),
        ]),
        SizedBox(height: 8),
        _InfoRow('Total Referrals', user.referralCount.toString()),
        SizedBox(height: 8),
        _InfoRow('Total Earned', '₦${_formatMoney(user.referralEarnings)}'),
        SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(Icons.copy, size: 18),
            label: Text('Copy Referral Link'),
            onPressed: link.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Referral link copied'),
                        backgroundColor: Colors.green));
                  },
          ),
        ),
      ]),
    );
  }
}

class _ProfSection extends StatelessWidget {
  final String title;
  final List<_ProfTileData> tiles;
  const _ProfSection(this.title, this.tiles);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(title,
            style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ),
      Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 6)
            ]),
        child: Column(
          children: tiles.asMap().entries.map((e) {
            final t = e.value;
            final last = e.key == tiles.length - 1;
            return Column(children: [
              ListTile(
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: t.isRed
                          ? Colors.red.withOpacity(0.08)
                          : AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle),
                  child: Icon(t.icon,
                      color: t.isRed ? Colors.red : AppColors.primary,
                      size: 20),
                ),
                title: Text(t.label,
                    style: TextStyle(
                        color:
                            t.isRed ? Colors.red : Colors.black87,
                        fontWeight: FontWeight.w500)),
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400),
                onTap: t.onTap,
              ),
              if (!last) Divider(height: 1, indent: 70),
            ]);
          }).toList(),
        ),
      ),
      SizedBox(height: 16),
    ]);
  }
}

class _ProfTileData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isRed;
  const _ProfTileData(this.icon, this.label, this.onTap,
      {this.isRed = false});
}

// ─────────────────────────────────────────────────────────────
// CHANGE PASSWORD
// ─────────────────────────────────────────────────────────────
class ChangePasswordScreen extends StatefulWidget {
  final UserModel user;
  const ChangePasswordScreen({required this.user});
  @override
  _ChangePasswordScreenState createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  Future<void> _submit() async {
    if (_currentCtrl.text.isEmpty ||
        _newCtrl.text.isEmpty ||
        _confirmCtrl.text.isEmpty) {
      _snack('All fields are required', err: true);
      return;
    }
    if (_newCtrl.text.length < 6) {
      _snack('New password must be at least 6 characters', err: true);
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      _snack('New passwords do not match', err: true);
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.changePassword(
        token: widget.user.token,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
        confirmPassword: _confirmCtrl.text);
    setState(() => _loading = false);
    if (res['success'] == true) {
      _snack('Password changed successfully!');
      await Future.delayed(Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } else {
      _snack(res['message'] ?? 'Failed', err: true);
    }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: err ? Colors.red : Colors.green));

  Widget _passField(TextEditingController ctrl, String hint, bool show,
      VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
            Icon(Icons.lock_outline, color: AppColors.primary),
        suffixIcon: IconButton(
            icon: Icon(
                show ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey),
            onPressed: toggle),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: _ServiceAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline,
                      color: Colors.white, size: 24)),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Change Password',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('Keep your account secure',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ]),
              ),
            ]),
          ),
          SizedBox(height: 28),
          Text('Current Password',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          _passField(_currentCtrl, 'Enter current password',
              _showCurrent,
              () => setState(() => _showCurrent = !_showCurrent)),
          SizedBox(height: 20),
          Text('New Password',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          _passField(
              _newCtrl,
              'Enter new password (min 6 chars)',
              _showNew,
              () => setState(() => _showNew = !_showNew)),
          SizedBox(height: 20),
          Text('Confirm New Password',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          _passField(_confirmCtrl, 'Re-enter new password',
              _showConfirm,
              () => setState(() => _showConfirm = !_showConfirm)),
          SizedBox(height: 32),
          _buildActionBtn('Update Password', _submit,
              loading: _loading),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHANGE PIN
// ─────────────────────────────────────────────────────────────
class ChangePinScreen extends StatefulWidget {
  final UserModel user;
  const ChangePinScreen({required this.user});
  @override
  _ChangePinScreenState createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  Future<void> _submit() async {
    if (_oldCtrl.text.isEmpty ||
        _newCtrl.text.isEmpty ||
        _confirmCtrl.text.isEmpty) {
      _snack('All fields are required', err: true);
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_newCtrl.text)) {
      _snack('New PIN must be exactly 4 digits', err: true);
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      _snack('PINs do not match', err: true);
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.changePin(
        token: widget.user.token,
        oldPin: _oldCtrl.text,
        newPin: _newCtrl.text,
        confirmPin: _confirmCtrl.text);
    setState(() => _loading = false);
    if (res['success'] == true) {
      _snack('PIN changed successfully!');
      await Future.delayed(Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } else {
      _snack(res['message'] ?? 'Failed', err: true);
    }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: err ? Colors.red : Colors.green));

  Widget _pinField(TextEditingController ctrl, String hint, bool show,
      VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      maxLength: 4,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: 22,
          letterSpacing: 12,
          fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, letterSpacing: 1),
        prefixIcon:
            Icon(Icons.pin_outlined, color: AppColors.primary),
        suffixIcon: IconButton(
            icon: Icon(
                show ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey),
            onPressed: toggle),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: _ServiceAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: Icon(Icons.pin_outlined,
                      color: Colors.white, size: 24)),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Change Transaction PIN',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('Your 4-digit transaction PIN',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ]),
              ),
            ]),
          ),
          SizedBox(height: 28),
          Text('Current PIN',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          _pinField(_oldCtrl, 'Enter current PIN', _showOld,
              () => setState(() => _showOld = !_showOld)),
          SizedBox(height: 20),
          Text('New PIN',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          _pinField(_newCtrl, 'Enter new PIN', _showNew,
              () => setState(() => _showNew = !_showNew)),
          SizedBox(height: 20),
          Text('Confirm New PIN',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          _pinField(_confirmCtrl, 'Re-enter new PIN', _showConfirm,
              () => setState(() => _showConfirm = !_showConfirm)),
          SizedBox(height: 32),
          _buildActionBtn('Update PIN', _submit, loading: _loading),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUPPORT SCREEN
// ─────────────────────────────────────────────────────────────
class SupportScreen extends StatefulWidget {
  final UserModel user;
  const SupportScreen({required this.user});
  @override
  _SupportScreenState createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _messageCtrl = TextEditingController();
  String? _selectedSubject;
  bool _loading = false;

  final _subjects = [
    'Airtime Not Delivered',
    'Data Not Delivered',
    'Electricity Payment Issue',
    'Cable Subscription Issue',
    'Wallet Funding Issue',
    'Wrong Deduction / Refund Request',
    'Account Access Problem',
    'Other',
  ];

  Future<void> _submit() async {
    final subject = _selectedSubject ?? '';
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty) {
      _snack('Please select a subject', err: true);
      return;
    }
    if (message.length < 20) {
      _snack('Message must be at least 20 characters', err: true);
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.sendSupportMessage(
        token: widget.user.token,
        subject: subject,
        message: message);
    setState(() => _loading = false);
    if (res['success'] == true) {
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle),
                  child: Icon(Icons.mark_email_read_outlined,
                      color: Colors.green, size: 44)),
              SizedBox(height: 16),
              Text('Message Sent!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                  'We will respond to ${widget.user.email} within 24 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87)),
            ]),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Done',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          );
        },
      );
    } else {
      _snack(res['message'] ?? 'Failed to send', err: true);
    }
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: err ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: _ServiceAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: Icon(Icons.support_agent_outlined,
                      color: Colors.white, size: 24)),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact Support',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('We respond within 24 hours',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ]),
              ),
            ]),
          ),
          SizedBox(height: 20),
          Row(children: [
            _ContactChip(Icons.email_outlined, 'support@vtutopup.com.ng'),
            SizedBox(width: 10),
            _ContactChip(Icons.chat_bubble_outline, 'WhatsApp'),
          ]),
          SizedBox(height: 24),
          Text('Subject',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text('Select a subject',
                    style: TextStyle(color: Colors.grey)),
                value: _selectedSubject,
                onChanged: (v) =>
                    setState(() => _selectedSubject = v),
                items: _subjects
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s,
                            style: TextStyle(fontSize: 13))))
                    .toList(),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('Message',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          SizedBox(height: 8),
          TextField(
            controller: _messageCtrl,
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  'Describe your issue in detail...\n\nInclude: transaction reference, phone number, and any error messages received.',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          SizedBox(height: 6),
          Text('Min. 20 characters',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
          SizedBox(height: 24),
          _buildActionBtn('Send Message', _submit, loading: _loading),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.primary),
        SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
