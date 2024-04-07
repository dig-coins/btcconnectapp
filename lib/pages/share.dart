String mBTC2BTC(int v) {
  return "${v.toDouble() / 100000000}";
}

int sBTC2mBTC(String v) {
  return (double.parse(v) * 100000000).round();
}
