import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Drawer/controller/ride_history_controller.dart';
import 'package:hopper/Presentation/Drawer/controller/withdraw_controller.dart';
import 'package:hopper/Presentation/Drawer/screens/bank_details_form_screen.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, required this.walletController});

  final RideHistoryController walletController;

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountCtrl = TextEditingController();

  final WithdrawController _wc = Get.isRegistered<WithdrawController>()
      ? Get.find<WithdrawController>()
      : Get.put(WithdrawController());

  static const Color _bg = AppColors.containerColor1;
  static final Color _teal = AppColors.drkGreen;
  static const Color _black = AppColors.commonBlack;
  static const Color _text = AppColors.commonBlack;
  static final Color _muted = AppColors.textColorGrey;
  static const Color _field = AppColors.containerColor;

  @override
  void initState() {
    super.initState();
    _wc.loadSavedBank();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _balance =>
      double.tryParse(widget.walletController.balance.value.toString().trim()) ??
      0.0;

  Future<void> _openBankForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BankDetailsFormScreen()),
    );
    if (!mounted) return;
    await _wc.loadSavedBank();
  }

  Future<void> _submit() async {
    // Block until bank details are saved.
    if (!_wc.hasBank) {
      CustomSnackBar.showError('Add your bank details first');
      _openBankForm();
      return;
    }

    final raw = _amountCtrl.text.trim();
    final amt = double.tryParse(raw);
    if (amt == null || amt <= 0) {
      CustomSnackBar.showError('Please enter a valid amount');
      return;
    }
    if (_balance > 0 && amt > _balance) {
      CustomSnackBar.showError(
        'Amount should be less than or equal to wallet balance',
      );
      return;
    }

    // requestWithdraw surfaces backend min/max/insufficient/daily-limit/pending
    // messages via CustomSnackBar, refreshes the balance, and returns true only
    // on a confirmed request — so we pop only on success.
    final ok = await widget.walletController.requestWithdraw(amount: amt);
    if (!mounted) return;
    if (ok) {
      _amountCtrl.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Withdraw',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _text,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _balanceCard(),
              const SizedBox(height: 18),
              _sectionTitle('Bank account'),
              const SizedBox(height: 10),
              Obx(() => _bankSection()),
              const SizedBox(height: 18),
              _sectionTitle('Amount'),
              const SizedBox(height: 10),
              _amountRow(),
              const SizedBox(height: 22),
              Obx(() {
                final loading = widget.walletController.isWithdrawLoading.value;
                final hasBank = _wc.hasBank;
                final enabled = !loading && hasBank;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: enabled ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _black.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: loading
                        ? const HopprCircularLoader(
                            radius: 14,
                            color: Colors.white,
                          )
                        : Text(
                            hasBank
                                ? 'Withdraw'
                                : 'Add bank details to withdraw',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Make sure the amount is correct before submitting. The amount is '
                'held until the request is processed; if declined it is refunded '
                'to your wallet.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF5B8EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text(
            'Balance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          Obx(() {
            // Touch the observable so this rebuilds on balance change.
            widget.walletController.balance.value;
            final bal = _balance.toStringAsFixed(2);
            return Text(
              '₦$bal',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _bankSection() {
    final bank = _wc.savedBank.value;
    final hasBank = _wc.hasBank;

    if (!hasBank) {
      return GestureDetector(
        onTap: _openBankForm,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: _field,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _teal.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add_card_rounded, color: _teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add bank details',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Required before you can withdraw',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.commonWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_rounded, color: _teal, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bank!.bankName}  ·  ${bank.maskedAccount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bank.accountHolderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openBankForm,
            child: Text(
              'Change',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: _text,
      ),
    );
  }

  Widget _amountRow() {
    return Row(
      children: [
        Expanded(
          child: _textField(
            controller: _amountCtrl,
            hint: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 52,
          width: 56,
          decoration: BoxDecoration(
            color: _field,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Center(
            child: Image.asset(
              AppImages.bCurrency,
              width: 18,
              height: 18,
              color: AppColors.drkGreen,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _field,
        hintStyle: TextStyle(
          color: _muted.withValues(alpha: 0.8),
          fontWeight: FontWeight.w800,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _teal, width: 1.4),
        ),
      ),
    );
  }
}
