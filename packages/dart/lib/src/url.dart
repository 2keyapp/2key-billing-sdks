String normalizeApiBaseUrl(String input) {
  var s = input.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  final lower = s.toLowerCase();
  for (final suffix in ['/api/v1', '/api/billing']) {
    if (lower.endsWith(suffix)) {
      s = s.substring(0, s.length - suffix.length);
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
      break;
    }
  }
  return s;
}
