class DriverEarningsResponse {
  final bool success;
  final DriverEarningsCursor cursor;
  final DriverEarningsFilters filters;
  final DriverEarningsSummary summary;
  final List<DriverEarningsItem> items;

  const DriverEarningsResponse({
    required this.success,
    required this.cursor,
    required this.filters,
    required this.summary,
    required this.items,
  });

  factory DriverEarningsResponse.fromJson(Map<String, dynamic> json) {
    return DriverEarningsResponse(
      success: json['success'] == true,
      cursor: DriverEarningsCursor.fromJson(
        Map<String, dynamic>.from((json['cursor'] ?? const {}) as Map),
      ),
      filters: DriverEarningsFilters.fromJson(
        Map<String, dynamic>.from((json['filters'] ?? const {}) as Map),
      ),
      summary: DriverEarningsSummary.fromJson(
        Map<String, dynamic>.from((json['summary'] ?? const {}) as Map),
      ),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => DriverEarningsItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }
}

class DriverEarningsCursor {
  final String? next;
  final bool hasMore;

  const DriverEarningsCursor({required this.next, required this.hasMore});

  factory DriverEarningsCursor.fromJson(Map<String, dynamic> json) {
    return DriverEarningsCursor(
      next: (json['next'] as String?)?.trim().isEmpty == true ? null : json['next'] as String?,
      hasMore: json['hasMore'] == true,
    );
  }
}

class DriverEarningsFilters {
  final String? category;
  final String? bookingType;
  final List<String> paymentModes;
  final List<String> statuses;
  final List<String> transactionTypes;
  final String? fromDateIso;
  final String? toDateIso;
  final int? limit;

  const DriverEarningsFilters({
    required this.category,
    required this.bookingType,
    required this.paymentModes,
    required this.statuses,
    required this.transactionTypes,
    required this.fromDateIso,
    required this.toDateIso,
    required this.limit,
  });

  factory DriverEarningsFilters.fromJson(Map<String, dynamic> json) {
    List<String> toStrings(dynamic v) {
      if (v is List) {
        return v.map((e) => (e ?? '').toString()).where((e) => e.trim().isNotEmpty).toList();
      }
      return const <String>[];
    }

    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString());
    }

    return DriverEarningsFilters(
      category: (json['category'] ?? '').toString().trim().isEmpty
          ? null
          : (json['category'] ?? '').toString().trim(),
      bookingType: (json['bookingType'] ?? '').toString().trim().isEmpty
          ? null
          : (json['bookingType'] ?? '').toString().trim(),
      paymentModes: toStrings(json['paymentModes']),
      statuses: toStrings(json['statuses']),
      transactionTypes: toStrings(json['transactionTypes']),
      fromDateIso: (json['fromDate'] ?? '').toString().trim().isEmpty
          ? null
          : (json['fromDate'] ?? '').toString().trim(),
      toDateIso: (json['toDate'] ?? '').toString().trim().isEmpty
          ? null
          : (json['toDate'] ?? '').toString().trim(),
      limit: toInt(json['limit']),
    );
  }
}

class DriverEarningsSummary {
  final String availableBalance;
  final String cashOnHand;
  final String lifetimeEarnings;
  final String totalWithdrawals;
  final String pendingWithdrawals;

  const DriverEarningsSummary({
    required this.availableBalance,
    required this.cashOnHand,
    required this.lifetimeEarnings,
    required this.totalWithdrawals,
    required this.pendingWithdrawals,
  });

  factory DriverEarningsSummary.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] ?? '0.00').toString();
    return DriverEarningsSummary(
      availableBalance: s('availableBalance'),
      cashOnHand: s('cashOnHand'),
      lifetimeEarnings: s('lifetimeEarnings'),
      totalWithdrawals: s('totalWithdrawals'),
      pendingWithdrawals: s('pendingWithdrawals'),
    );
  }
}

class DriverEarningsItem {
  final String id;
  final String amount;
  final String type;
  final String category;
  final String title;
  final String paymentId;
  final String paymentMode;
  final String status;
  final String ridePaymentStatus;
  final String createdAtIso;
  final DriverEarningsBooking booking;
  final DriverEarningsCustomer customer;

  const DriverEarningsItem({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.title,
    required this.paymentId,
    required this.paymentMode,
    required this.status,
    required this.ridePaymentStatus,
    required this.createdAtIso,
    required this.booking,
    required this.customer,
  });

  factory DriverEarningsItem.fromJson(Map<String, dynamic> json) {
    return DriverEarningsItem(
      id: (json['id'] ?? '').toString(),
      amount: (json['amount'] ?? '0.00').toString(),
      type: (json['type'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      paymentId: (json['paymentId'] ?? '').toString(),
      paymentMode: (json['paymentMode'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      ridePaymentStatus: (json['ridePaymentstatus'] ?? json['ridePaymentStatus'] ?? '').toString(),
      createdAtIso: (json['createdAt'] ?? '').toString(),
      booking: DriverEarningsBooking.fromJson(
        Map<String, dynamic>.from((json['booking'] ?? const {}) as Map),
      ),
      customer: DriverEarningsCustomer.fromJson(
        Map<String, dynamic>.from((json['customer'] ?? const {}) as Map),
      ),
    );
  }
}

class DriverEarningsBooking {
  final String bookingId;
  final String bookingType;
  final String status;
  final String pickupAddress;
  final String dropAddress;

  const DriverEarningsBooking({
    required this.bookingId,
    required this.bookingType,
    required this.status,
    required this.pickupAddress,
    required this.dropAddress,
  });

  factory DriverEarningsBooking.fromJson(Map<String, dynamic> json) {
    return DriverEarningsBooking(
      bookingId: (json['bookingId'] ?? '').toString(),
      bookingType: (json['bookingType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      pickupAddress: (json['pickupAddress'] ?? '').toString(),
      dropAddress: (json['dropAddress'] ?? '').toString(),
    );
  }
}

class DriverEarningsCustomer {
  final String name;
  final String phone;
  final String profileImage;

  const DriverEarningsCustomer({
    required this.name,
    required this.phone,
    required this.profileImage,
  });

  factory DriverEarningsCustomer.fromJson(Map<String, dynamic> json) {
    return DriverEarningsCustomer(
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      profileImage: (json['profileImage'] ?? '').toString(),
    );
  }
}

