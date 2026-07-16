import 'dart:convert';

DateTime? jwtExpiresAt(String token) {
  try {
    final parts = token.trim().split('.');
    if (parts.length != 3) return null;

    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;

    final rawExpiry = payload['exp'];
    final expirySeconds =
        rawExpiry is num
            ? rawExpiry.toInt()
            : int.tryParse(rawExpiry?.toString() ?? '');
    if (expirySeconds == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(
      expirySeconds * Duration.millisecondsPerSecond,
      isUtc: true,
    );
  } catch (_) {
    return null;
  }
}

bool isJwtExpired(
  String token, {
  DateTime? now,
  Duration clockSkew = const Duration(seconds: 15),
}) {
  final expiresAt = jwtExpiresAt(token);
  if (expiresAt == null) return false;
  final effectiveNow = (now ?? DateTime.now()).toUtc().add(clockSkew);
  return !expiresAt.isAfter(effectiveNow);
}
