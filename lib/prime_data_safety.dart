/// PRIME 3.0 — validated, portable backups and migration-safe storage.
/// Pure Dart; caller handles file I/O, confirmation, and persistence.
import 'dart:convert';

class PrimeBackupException implements Exception {
  final String message;
  const PrimeBackupException(this.message);
  @override
  String toString() => 'PrimeBackupException: $message';
}

class PrimeBackup {
  static const format = 'haftepool-prime-backup';
  static const version = 1;
  static const legacyStorageKey = 'haftepool_native_v1';

  /// Wraps a COPY of the legacy state, preserving unknown fields for future
  /// migration. This does not overwrite the currently saved data.
  static String exportJson(Map<String, dynamic> legacyState,
      {DateTime? exportedAt}) {
    final state = _clone(legacyState);
    validateLegacyState(state);
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'sourceStorageKey': legacyStorageKey,
      'state': state,
    });
  }

  /// Parses a backup without changing local data. The UI must show a preview
  /// and obtain explicit user consent before calling a storage write.
  static Map<String, dynamic> previewImport(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const PrimeBackupException('فایل پشتیبان JSON معتبر نیست');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != format || decoded['version'] != version ||
        decoded['state'] is! Map<String, dynamic>) {
      throw const PrimeBackupException('قالب یا نسخه پشتیبان پشتیبانی نمی‌شود');
    }
    final state = _clone(decoded['state'] as Map<String, dynamic>);
    validateLegacyState(state);
    return state;
  }

  /// Legacy payload validation; extra fields are deliberately preserved.
  static void validateLegacyState(Map<String, dynamic> state) {
    for (final field in ['entries', 'goals']) {
      final value = state[field];
      if (value != null && value is! List) {
        throw PrimeBackupException('ساختار $field نامعتبر است');
      }
    }
    for (final field in ['budgets', 'targets', 'settlements', 'debts']) {
      final value = state[field];
      if (value != null && value is! Map) {
        throw PrimeBackupException('ساختار $field نامعتبر است');
      }
    }
    final weights = state['weights'];
    if (weights != null && (weights is! List || weights.length != 7 ||
        weights.any((v) => v is! int || v < 0) ||
        weights.every((v) => v == 0))) {
      throw const PrimeBackupException('درصدهای هفت روز معتبر نیست');
    }
    final startHour = state['dayStartHour'];
    if (startHour != null &&
        (startHour is! int || startHour < 0 || startHour > 23)) {
      throw const PrimeBackupException('ساعت شروع روز معتبر نیست');
    }
    for (final field in ['budgets', 'targets']) {
      final values = state[field];
      if (values is Map) {
        for (final value in values.values) {
          if (value is! int || value < 0) {
            throw PrimeBackupException('مبلغ $field نامعتبر است');
          }
        }
      }
    }
    for (final field in ['entries', 'goals']) {
      final records = state[field];
      if (records is List) {
        for (final record in records) {
          if (record is! Map || record['id'] is! String ||
              (record['amount'] != null &&
                  (record['amount'] is! int || record['amount'] <= 0)) ||
              (record['price'] != null &&
                  (record['price'] is! int || record['price'] <= 0))) {
            throw PrimeBackupException('یک رکورد $field نامعتبر است');
          }
        }
      }
    }
  }

  static Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}
