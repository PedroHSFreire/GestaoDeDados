class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.crm,
    this.specialty,
    this.phone,
    this.address,
    this.experience,
    this.education,
    this.bio,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? crm;
  final String? specialty;
  final String? phone;
  final String? address;
  final String? experience;
  final String? education;
  final String? bio;

  bool get isDoctor => role == 'doctor';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        crm: json['crm'] as String?,
        specialty: json['specialty'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        experience: json['experience'] as String?,
        education: json['education'] as String?,
        bio: json['bio'] as String?,
      );
}
