class FinancialCalculationEngine {
  static const maximum = 100000000000000;
  static int? multiply(int quantity, int unitPrice) {
    if (quantity <= 0 || unitPrice <= 0) return null;
    final value = BigInt.from(quantity) * BigInt.from(unitPrice);
    return value <= BigInt.from(maximum) ? value.toInt() : null;
  }

  static int? rialToToman(int rial) =>
      rial >= 0 && rial % 10 == 0 ? rial ~/ 10 : null;
}
