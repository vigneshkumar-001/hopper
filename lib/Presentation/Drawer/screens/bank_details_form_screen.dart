import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

import '../controller/withdraw_controller.dart';
import '../model/bank_details_models.dart';

/// Bank details form — Account Holder Name, Nigerian bank picker (name + code),
/// 10-digit NUBAN account number, optional branch / swift. Saves via
/// [WithdrawController] and pops `true` on success.
class BankDetailsFormScreen extends StatefulWidget {
  const BankDetailsFormScreen({super.key});

  @override
  State<BankDetailsFormScreen> createState() => _BankDetailsFormScreenState();
}

class _BankDetailsFormScreenState extends State<BankDetailsFormScreen> {
  final WithdrawController _c = Get.isRegistered<WithdrawController>()
      ? Get.find<WithdrawController>()
      : Get.put(WithdrawController());

  final _holderCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _swiftCtrl = TextEditingController();

  NigerianBank? _selectedBank;

  static const Color _bg = AppColors.containerColor1;
  static const Color _field = AppColors.containerColor;
  static const Color _text = AppColors.commonBlack;
  static final Color _teal = AppColors.drkGreen;
  static final Color _muted = AppColors.textColorGrey;

  @override
  void initState() {
    super.initState();
    // Prefill in edit mode.
    final s = _c.savedBank.value;
    if (s != null) {
      _holderCtrl.text = s.accountHolderName;
      _accountCtrl.text = s.accountNumber;
      _branchCtrl.text = s.branchName;
      _swiftCtrl.text = s.swiftCode;
      if (s.bankName.isNotEmpty && s.bankCode.isNotEmpty) {
        _selectedBank = NigerianBank(name: s.bankName, code: s.bankCode);
      }
    }
    _c.loadBanks();
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _branchCtrl.dispose();
    _swiftCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final holder = _holderCtrl.text.trim();
    final account = _accountCtrl.text.trim();

    if (holder.isEmpty) {
      CustomSnackBar.showError('Enter the account holder name');
      return;
    }
    if (_selectedBank == null) {
      CustomSnackBar.showError('Select your bank');
      return;
    }
    if (account.length != 10) {
      CustomSnackBar.showError('Account number must be exactly 10 digits');
      return;
    }

    final ok = await _c.saveBankDetails(
      accountHolderName: holder,
      bank: _selectedBank!,
      accountNumber: account,
      branchName: _branchCtrl.text.trim(),
      swiftCode: _swiftCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) Navigator.pop(context, true);
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
          'Bank details',
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
              Text(
                'Add the bank account where your withdrawals will be paid.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 18),
              _label('Account holder name'),
              const SizedBox(height: 8),
              _input(
                controller: _holderCtrl,
                hint: 'e.g. Vignesh Kumar',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _label('Bank'),
              const SizedBox(height: 8),
              _bankPickerField(),
              const SizedBox(height: 16),
              _label('Account number (10 digits)'),
              const SizedBox(height: 8),
              _input(
                controller: _accountCtrl,
                hint: '0123456789',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _label('Branch name (optional)'),
              const SizedBox(height: 8),
              _input(
                controller: _branchCtrl,
                hint: 'Enter branch',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _label('Swift code (optional)'),
              const SizedBox(height: 8),
              _input(
                controller: _swiftCtrl,
                hint: 'Enter swift code',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 26),
              Obx(() {
                final saving = _c.isSaving.value;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.commonBlack,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: saving
                        ? const HopprCircularLoader(
                            radius: 14,
                            color: Colors.white,
                          )
                        : const Text(
                            'Save bank details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: _text,
        ),
      );

  Widget _bankPickerField() {
    return GestureDetector(
      onTap: _openBankPicker,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedBank?.name ?? 'Select your bank',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _selectedBank == null
                      ? _muted.withValues(alpha: 0.8)
                      : _text,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  void _openBankPicker() {
    final query = ''.obs;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.75,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select bank',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => query.value = v.trim().toLowerCase(),
                    decoration: InputDecoration(
                      hintText: 'Search bank',
                      prefixIcon: Icon(Icons.search, color: _muted),
                      filled: true,
                      fillColor: _field,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Obx(() {
                    if (_c.isBanksLoading.value && _c.banks.isEmpty) {
                      return const Center(child: HopprCircularLoader());
                    }
                    final q = query.value;
                    final list = q.isEmpty
                        ? _c.banks.toList()
                        : _c.banks
                            .where((b) => b.name.toLowerCase().contains(q))
                            .toList();
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          'No banks found',
                          style: TextStyle(color: _muted),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      itemBuilder: (_, i) {
                        final bank = list[i];
                        final selected = _selectedBank?.code == bank.code;
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          title: Text(
                            bank.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: selected
                              ? Icon(Icons.check_circle_rounded, color: _teal)
                              : null,
                          onTap: () {
                            setState(() => _selectedBank = bank);
                            Navigator.pop(sheetCtx);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
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
