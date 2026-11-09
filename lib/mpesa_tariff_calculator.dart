class MpesaTariffCalculator {
  /// Calculates estimated M-Pesa transfer fee based on official Safaricom tariff bands.
  static int calculateTransferFee(double amount, {bool isWithdrawal = false}) {
    if (amount <= 0) return 0;
    if (amount <= 100) return 0;

    if (isWithdrawal) {
      if (amount <= 500) return 28;
      if (amount <= 2500) return 29;
      if (amount <= 3500) return 52;
      if (amount <= 5000) return 69;
      if (amount <= 7500) return 87;
      if (amount <= 10000) return 115;
      if (amount <= 15000) return 167;
      if (amount <= 20000) return 185;
      if (amount <= 35000) return 197;
      if (amount <= 50000) return 209;
      return 309;
    } else {
      if (amount <= 500) return 7;
      if (amount <= 1000) return 13;
      if (amount <= 1500) return 23;
      if (amount <= 2500) return 33;
      if (amount <= 3500) return 53;
      if (amount <= 5000) return 57;
      if (amount <= 7500) return 78;
      if (amount <= 10000) return 90;
      if (amount <= 15000) return 100;
      if (amount <= 20000) return 105;
      if (amount <= 25000) return 110;
      if (amount <= 35000) return 112;
      if (amount <= 50000) return 115;
      return 118;
    }
  }
}
