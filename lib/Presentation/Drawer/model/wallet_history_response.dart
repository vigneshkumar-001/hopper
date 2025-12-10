class WalletResponse {
  final bool success;
  final Balance? balance;
  final String? minBalance;
  final String? totalTransactions;
  final int? currentPage;
  final int? totalPages;
  final List<Transaction> transactions;

  WalletResponse({
    required this.success,
    this.balance,
    this.minBalance,
    this.totalTransactions,
    this.currentPage,
    this.totalPages,
    required this.transactions,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    return WalletResponse(
      success: json['success'] ?? false,
      balance: json['balance'] != null
          ? Balance.fromJson(json['balance'])
          : null,
      minBalance: json['minBalance']?.toString(),
      totalTransactions: json['totalTransactions']?.toString(),
      currentPage: json['currentPage'],
      totalPages: json['totalPages'],
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => Transaction.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'balance': balance?.toJson(),
      'minBalance': minBalance,
      'totalTransactions': totalTransactions,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'transactions': transactions.map((e) => e.toJson()).toList(),
    };
  }
}

class Balance {
  final String? amount;
  final String? cashOnHand;

  Balance({
    this.amount,
    this.cashOnHand,
  });

  factory Balance.fromJson(Map<String, dynamic> json) {
    return Balance(
      amount: json['amount']?.toString(),
      cashOnHand: json['cashOnHand']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'cashOnHand': cashOnHand,
    };
  }
}

class Transaction {
  final String? id;
  final String? driverId;
  final String? amount;
  final String? type;
  final String? paymentMode;
  final String? paymentId;
  final String? ridePaymentstatus;
  final String? status;
  final String? createdAt;
  final String? commissionAmount;
  final String? bookingId;
  final String? displayText;
  final String? walletDescription;
  final String? imageType;
  final String? color;
  final Booking? booking;

  Transaction({
    this.id,
    this.driverId,
    this.amount,
    this.type,
    this.paymentMode,
    this.paymentId,
    this.ridePaymentstatus,
    this.status,
    this.createdAt,
    this.commissionAmount,
    this.bookingId,
    this.displayText,
    this.imageType,
    this.color,
    this.walletDescription,
    this.booking,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['_id']?.toString(),
      driverId: json['driverId']?.toString(),
      amount: json['amount']?.toString(),
      type: json['type']?.toString(),
      paymentMode: json['paymentMode']?.toString(),
      paymentId: json['paymentId']?.toString(),
      ridePaymentstatus: json['ridePaymentstatus']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['createdAt']?.toString(),
      commissionAmount: json['commissionAmount']?.toString(),
      bookingId: json['bookingId']?.toString(),
      displayText: json['displayText']?.toString(),
      imageType: json['imageType']?.toString(),
      color: json['color']?.toString(),
      walletDescription: json['walletDescription']?.toString(),
      booking: json['booking'] != null
          ? Booking.fromJson(json['booking'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'driverId': driverId,
      'amount': amount,
      'type': type,
      'paymentMode': paymentMode,
      'paymentId': paymentId,
      'ridePaymentstatus': ridePaymentstatus,
      'status': status,
      'createdAt': createdAt,
      'commissionAmount': commissionAmount,
      'bookingId': bookingId,
      'displayText': displayText,
      'imageType': imageType,
      'color': color,
      'walletDescription': walletDescription,
      'booking': booking?.toJson(),
    };
  }
}

class Booking {
  final String? id;
  final String? bookingType;
  final String? bookingId;
  final String? status;
  final String? pickupAddress;
  final String? dropAddress;
  final String? createdAt;

  Booking({
    this.id,
    this.bookingType,
    this.bookingId,
    this.status,
    this.pickupAddress,
    this.dropAddress,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['_id']?.toString(),
      bookingType: json['bookingType']?.toString(),
      bookingId: json['bookingId']?.toString(),
      status: json['status']?.toString(),
      pickupAddress: json['pickupAddress']?.toString(),
      dropAddress: json['dropAddress']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'bookingType': bookingType,
      'bookingId': bookingId,
      'status': status,
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      'createdAt': createdAt,
    };
  }
}


// class WalletResponse {
//   final bool success;
//   final Balance? balance;
//   final String? minBalance;
//   final String? totalTransactions;
//   final List<Transaction> transactions;
//
//   WalletResponse({
//     required this.success,
//     this.balance,
//     this.minBalance,
//     this.totalTransactions,
//     required this.transactions,
//   });
//
//   factory WalletResponse.fromJson(Map<String, dynamic> json) {
//     return WalletResponse(
//       success: json['success'] ?? false,
//       balance: json['balance'] != null ? Balance.fromJson(json['balance']) : null,
//       minBalance: json['minBalance']?.toString(),
//       totalTransactions: json['totalTransactions']?.toString(),
//       transactions: (json['transactions'] as List<dynamic>?)
//           ?.map((e) => Transaction.fromJson(e))
//           .toList() ??
//           [],
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'success': success,
//       'balance': balance?.toJson(),
//       'minBalance': minBalance,
//       'totalTransactions': totalTransactions,
//       'transactions': transactions.map((e) => e.toJson()).toList(),
//     };
//   }
// }
//
// class Balance {
//   final String? amount;
//   final String? cashOnHand;
//
//   Balance({
//     this.amount,
//     this.cashOnHand,
//   });
//
//   factory Balance.fromJson(Map<String, dynamic> json) {
//     return Balance(
//       amount: json['amount']?.toString(),
//       cashOnHand: json['cashOnHand']?.toString(),
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'amount': amount,
//       'cashOnHand': cashOnHand,
//     };
//   }
// }
//
// class Transaction {
//   final String? id;
//   final String? driverId;
//   final String? amount;
//   final String? type;
//   final String? paymentMode;
//   final String? paymentId;
//   final String? ridePaymentstatus;
//   final String? status;
//   final String? createdAt;
//   final String? commissionAmount;
//   final String? bookingId;
//   final String? displayText;
//   final String? walletDescription;
//   final String? imageType;
//   final String? color;
//   final Booking? booking;
//
//   Transaction({
//     this.id,
//     this.driverId,
//     this.amount,
//     this.type,
//     this.paymentMode,
//     this.paymentId,
//     this.ridePaymentstatus,
//     this.status,
//     this.createdAt,
//     this.commissionAmount,
//     this.walletDescription,
//     this.bookingId,
//     this.displayText,
//     this.imageType,
//     this.color,
//     this.booking,
//   });
//
//   factory Transaction.fromJson(Map<String, dynamic> json) {
//     return Transaction(
//       id: json['_id']?.toString(),
//       driverId: json['driverId']?.toString(),
//       amount: json['amount']?.toString(),
//       type: json['type']?.toString(),
//       paymentMode: json['paymentMode']?.toString(),
//       paymentId: json['paymentId']?.toString(),
//       ridePaymentstatus: json['ridePaymentstatus']?.toString(),
//       status: json['status']?.toString(),
//       createdAt: json['createdAt']?.toString(),
//       walletDescription: json['walletDescription']?.toString(),
//       commissionAmount: json['commissionAmount']?.toString(),
//       bookingId: json['bookingId']?.toString(),
//       displayText: json['displayText']?.toString(),
//       imageType: json['imageType']?.toString(),
//       color: json['color']?.toString(),
//       booking:
//       json['booking'] != null ? Booking.fromJson(json['booking']) : null,
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       '_id': id,
//       'driverId': driverId,
//       'amount': amount,
//       'type': type,
//       'paymentMode': paymentMode,
//       'paymentId': paymentId,
//       'ridePaymentstatus': ridePaymentstatus,
//       'status': status,
//       'createdAt': createdAt,
//       'commissionAmount': commissionAmount,
//       'walletDescription': walletDescription,
//       'bookingId': bookingId,
//       'displayText': displayText,
//       'imageType': imageType,
//       'color': color,
//       'booking': booking?.toJson(),
//     };
//   }
// }
//
// class Booking {
//   final String? id;
//   final String? bookingType;
//   final String? bookingId;
//   final String? status;
//   final String? pickupAddress;
//   final String? dropAddress;
//   final String? createdAt;
//
//   Booking({
//     this.id,
//     this.bookingType,
//     this.bookingId,
//     this.status,
//     this.pickupAddress,
//     this.dropAddress,
//     this.createdAt,
//   });
//
//   factory Booking.fromJson(Map<String, dynamic> json) {
//     return Booking(
//       id: json['_id']?.toString(),
//       bookingType: json['bookingType']?.toString(),
//       bookingId: json['bookingId']?.toString(),
//       status: json['status']?.toString(),
//       pickupAddress: json['pickupAddress']?.toString(),
//       dropAddress: json['dropAddress']?.toString(),
//       createdAt: json['createdAt']?.toString(),
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       '_id': id,
//       'bookingType': bookingType,
//       'bookingId': bookingId,
//       'status': status,
//       'pickupAddress': pickupAddress,
//       'dropAddress': dropAddress,
//       'createdAt': createdAt,
//     };
//   }
// }
//
