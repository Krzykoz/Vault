/// An ISO-style currency code (e.g. `USD`, `EUR`). Stored uppercased.
///
/// Pure value type — no Flutter, no platform dependencies.
class Currency {
  final String code;

  const Currency._(this.code);

  factory Currency(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(code, 'code', 'Currency code must not be empty');
    }
    return Currency._(normalized);
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;

  Map<String, dynamic> toMap() => {'code': code};

  factory Currency.fromMap(Map<String, dynamic> map) =>
      Currency(map['code'] as String);
}
