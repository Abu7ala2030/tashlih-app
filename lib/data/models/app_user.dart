import '../enums/user_role.dart';

class AppUser {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final bool isActive;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role.name,
      'isActive': isActive,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.customer,
      ),
      isActive: map['isActive'] ?? true,
    );
  }
}
