/// Validated personal preferences for financial day boundaries and allocations.
class PrimePreferences {
  final int dayStartHour;
  final List<int> dayWeights;

  PrimePreferences({required this.dayStartHour, required List<int> dayWeights})
      : dayWeights = List<int>.unmodifiable(dayWeights) {
    if (dayStartHour < 0 || dayStartHour > 23) {
      throw ArgumentError.value(dayStartHour, 'dayStartHour', 'Must be 0..23');
    }
    if (this.dayWeights.length != 7 ||
        this.dayWeights.any((weight) => weight < 0 || weight > 1000) ||
        this.dayWeights.every((weight) => weight == 0)) {
      throw ArgumentError.value(dayWeights, 'dayWeights',
          'Must contain seven nonnegative weights with a positive total');
    }
  }

  List<int> allocate(int spendable) {
    if (spendable < 0) throw ArgumentError.value(spendable, 'spendable');
    final total = dayWeights.reduce((a, b) => a + b);
    var distributed = 0;
    return List<int>.generate(7, (index) {
      if (index == 6) return spendable - distributed;
      final amount = spendable * dayWeights[index] ~/ total;
      distributed += amount;
      return amount;
    });
  }
}
