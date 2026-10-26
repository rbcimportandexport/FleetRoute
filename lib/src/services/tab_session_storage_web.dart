import 'dart:convert';
import 'dart:html' as html;

class TabSessionStorage {
  static const _key = 'transport_one.tab_auth_session';

  static Map<String, dynamic>? read() {
    final raw = html.window.sessionStorage[_key];
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static void write(Map<String, dynamic> value) {
    html.window.sessionStorage[_key] = jsonEncode(value);
  }

  static void clear() => html.window.sessionStorage.remove(_key);
}
