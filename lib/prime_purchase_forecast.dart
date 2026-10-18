/// Read-only purchase impact preview. Does not post a transaction.
class PrimePurchasePreview {
  final int availableBefore;
  final int availableAfter;
  final int protectedSavings;
  final int shortfall;
  final bool affordable;
  const PrimePurchasePreview({required this.availableBefore,required this.availableAfter,
    required this.protectedSavings,required this.shortfall,required this.affordable});
}

class PrimePurchaseForecast {
  /// `available` is the existing spendable balance after recorded transactions.
  /// `protectedSavings` is shown separately and is never spent in this preview.
  static PrimePurchasePreview simulate({required int available,
    required int purchaseAmount,required int protectedSavings}) {
    if (purchaseAmount <= 0 || protectedSavings < 0) {
      throw ArgumentError('Invalid purchase amount or protected savings');
    }
    final after=available-purchaseAmount;
    return PrimePurchasePreview(availableBefore:available,availableAfter:after,
      protectedSavings:protectedSavings,shortfall:after<0?-after:0,
      affordable:after>=0);
  }
}
