import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Drawer/controller/ride_history_controller.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, required this.walletController});

  final RideHistoryController walletController;

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _cardCtrl = TextEditingController();

  static const Color _bg = AppColors.containerColor1;
  static Color _teal = AppColors.drkGreen;
  static const Color _black = AppColors.commonBlack;
  static const Color _text = AppColors.commonBlack;
  static Color _muted = AppColors.textColorGrey;
  static const Color _field = AppColors.containerColor;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  double get _balance =>
      double.tryParse(widget.walletController.balance.value.toString().trim()) ??
      0.0;

  Future<void> _submit() async {
    final raw = _amountCtrl.text.trim();
    final amt = double.tryParse(raw);
    if (amt == null || amt <= 0) {
      Get.snackbar(
        'Invalid amount',
        'Please enter a valid amount',
        backgroundColor: Colors.black87,
        colorText: Colors.white,
      );
      return;
    }
    if (_balance > 0 && amt > _balance) {
      Get.snackbar(
        'Insufficient balance',
        'Amount should be less than or equal to wallet balance',
        backgroundColor: Colors.black87,
        colorText: Colors.white,
      );
      return;
    }

    await widget.walletController.requestWithdraw(amount: amt);
    if (!mounted) return;
    if (!widget.walletController.isWithdrawLoading.value) {
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text),
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
              _sectionTitle('Amount'),
              const SizedBox(height: 10),
              _amountRow(),
              const SizedBox(height: 18),
              _sectionTitle('Card holder name'),
              const SizedBox(height: 10),
              _textField(
                controller: _nameCtrl,
                hint: 'Enter name',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _sectionTitle('Card number'),
              const SizedBox(height: 10),
              _textField(
                controller: _cardCtrl,
                hint: 'Enter card number',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 22),
              Obx(() {
                final loading = widget.walletController.isWithdrawLoading.value;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: loading
                        ? const HopprCircularLoader(radius: 14, color: Colors.white)
                        : const Text(
                            'Withdraw',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Make sure the amount is correct before submitting.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted),
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70),
          ),
          const Spacer(),
          Obx(() {
            final bal = _balance.toStringAsFixed(2);
            return Text(
              '\u20B9$bal',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            );
          }),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _text),
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
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textInputAction: TextInputAction.next,
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
        hintStyle: TextStyle(color: _muted.withValues(alpha: 0.8), fontWeight: FontWeight.w800),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
