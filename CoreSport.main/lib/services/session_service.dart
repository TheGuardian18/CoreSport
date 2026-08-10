import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _keyRole = 'current_role';
  static const _keyUsuario = 'current_usuario';

  Future<void> saveSession(String usuario, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsuario, usuario);
    await prefs.setString(_keyRole, role);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  Future<String?> getUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsuario);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsuario);
    await prefs.remove(_keyRole);
  }
}