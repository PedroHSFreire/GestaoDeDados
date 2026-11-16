class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.times,
    required this.active,
    required this.timezone,
    this.dosage,
  });

  final String id;
  final String name;
  final String? dosage;
  final List<String> times;
  final bool active;
  final String timezone;

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as String,
        name: json['name'] as String,
        dosage: json['dosage'] as String?,
        times: (json['times'] as List<dynamic>? ?? const []).cast<String>(),
        active: json['active'] as bool? ?? true,
        timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
      );
}
