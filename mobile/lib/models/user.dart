class User {
  final String id;
  final String username;
  final String fullName;
  final String? phone;
  final String? email;
  final String role;
  final String status;
  final bool mustChangePassword;
  final bool hasFace;
  final String? avatarUrl;
  final String? faceImageUrl;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    this.phone,
    this.email,
    required this.role,
    required this.status,
    required this.mustChangePassword,
    required this.hasFace,
    this.avatarUrl,
    this.faceImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      phone: json['phone'],
      email: json['email'],
      role: json['role'],
      status: json['status'],
      mustChangePassword: json['must_change_password'] ?? true,
      hasFace: json['has_face'] ?? false,
      avatarUrl: json['avatar_url'],
      faceImageUrl: json['face_image_url'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get needsSetup => mustChangePassword || !hasFace || isPending;
}
