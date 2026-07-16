import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopper/utils/session/jwt_expiry.dart';

String _tokenWithExpiry(DateTime expiry) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'exp':
            expiry.toUtc().millisecondsSinceEpoch ~/
            Duration.millisecondsPerSecond,
      }),
    ),
  );
  return '$header.$payload.signature';
}

void main() {
  final now = DateTime.utc(2026, 7, 16, 12);

  test('recognizes an expired JWT', () {
    final token = _tokenWithExpiry(now.subtract(const Duration(seconds: 1)));

    expect(isJwtExpired(token, now: now, clockSkew: Duration.zero), isTrue);
  });

  test('keeps a valid JWT active', () {
    final token = _tokenWithExpiry(now.add(const Duration(minutes: 5)));

    expect(isJwtExpired(token, now: now, clockSkew: Duration.zero), isFalse);
  });

  test('uses clock skew to avoid an acceptance race at expiry', () {
    final token = _tokenWithExpiry(now.add(const Duration(seconds: 10)));

    expect(isJwtExpired(token, now: now), isTrue);
  });

  test('leaves malformed tokens for server-side verification', () {
    expect(isJwtExpired('not-a-jwt', now: now), isFalse);
  });
}
