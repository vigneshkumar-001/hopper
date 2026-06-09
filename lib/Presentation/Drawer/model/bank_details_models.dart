// Models for the driver withdraw bank-details feature.
//
// - NigerianBank: a selectable bank (name + transfer code) for the picker.
// - SavedBankDetails: the driver's saved withdraw account — parsed from the
//   update-driver-withdraw-payments-details response AND cached locally (the
//   backend exposes no GET to read it back).
// - BankDetailsResponse: the save-bank-details API response wrapper.

class NigerianBank {
  final String name;
  final String code;

  const NigerianBank({required this.name, required this.code});

  factory NigerianBank.fromJson(Map<String, dynamic> j) => NigerianBank(
        name: (j['name'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) =>
      other is NigerianBank && other.code == code && other.name == name;

  @override
  int get hashCode => Object.hash(name, code);
}

class SavedBankDetails {
  final String accountHolderName;
  final String bankName;
  final String bankCode;
  final String accountNumber;
  final String branchName;
  final String swiftCode;
  final String status;
  final String image;

  const SavedBankDetails({
    required this.accountHolderName,
    required this.bankName,
    required this.bankCode,
    required this.accountNumber,
    required this.branchName,
    required this.swiftCode,
    required this.status,
    required this.image,
  });

  /// A usable withdraw account needs a holder name, a bank (name + code) and a
  /// valid 10-digit NUBAN.
  bool get isComplete =>
      accountHolderName.trim().isNotEmpty &&
      bankName.trim().isNotEmpty &&
      bankCode.trim().isNotEmpty &&
      accountNumber.trim().length == 10;

  /// "****6789" — last 4 of the account number only.
  String get maskedAccount {
    final n = accountNumber.trim();
    if (n.length <= 4) return n;
    return '****${n.substring(n.length - 4)}';
  }

  factory SavedBankDetails.fromJson(Map<String, dynamic> j) => SavedBankDetails(
        accountHolderName: (j['accountHolderName'] ?? '').toString(),
        bankName: (j['bankName'] ?? '').toString(),
        bankCode: (j['bankCode'] ?? '').toString(),
        accountNumber: (j['accountNumber'] ?? '').toString(),
        branchName: (j['branchName'] ?? '').toString(),
        swiftCode: (j['swiftCode'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'accountHolderName': accountHolderName,
        'bankName': bankName,
        'bankCode': bankCode,
        'accountNumber': accountNumber,
        'branchName': branchName,
        'swiftCode': swiftCode,
        'status': status,
        'image': image,
      };
}

class BankDetailsResponse {
  final bool success;
  final String message;
  final SavedBankDetails? data;

  const BankDetailsResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory BankDetailsResponse.fromJson(Map<String, dynamic> j) =>
      BankDetailsResponse(
        success: j['success'] == true || j['success']?.toString() == 'true',
        message: (j['message'] ?? '').toString(),
        data: j['data'] is Map
            ? SavedBankDetails.fromJson(
                Map<String, dynamic>.from(j['data'] as Map),
              )
            : null,
      );
}
