/// Formats an integer amount of Indonesian Rupiah as `Rp 55.500`
/// (thousands grouped with dots, no decimals).
String formatRupiah(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final sign = amount < 0 ? '-' : '';
  return 'Rp $sign${buffer.toString()}';
}
