enum UserRole { administrador, mesa, espectador }

UserRole roleFromString(String value) {
  switch (value) {
    case 'administrador':
      return UserRole.administrador;
    case 'mesa':
      return UserRole.mesa;
    case 'espectador':
      return UserRole.espectador;
    default:
      throw Exception('Rol desconocido: $value');
  }
}

class AppUser {
  final String uid;
  final String email;
  final UserRole role;

  AppUser({required this.uid, required this.email, required this.role});
}