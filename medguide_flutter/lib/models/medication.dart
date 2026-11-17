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

class PrescribedMedication {
  const PrescribedMedication({
    required this.id,
    required this.name,
    required this.appointmentDate,
    required this.appointmentStatus,
    this.dosage,
    this.frequency,
    this.duration,
    this.notes,
    this.doctorName,
  });

  final String id;
  final String name;
  final DateTime appointmentDate;
  final String appointmentStatus;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? notes;
  final String? doctorName;

  factory PrescribedMedication.fromJson(Map<String, dynamic> json) => PrescribedMedication(
        id: json['id'] as String,
        name: json['medication_name'] as String,
        appointmentDate: DateTime.parse(json['date_time'] as String),
        appointmentStatus: json['appointment_status'] as String? ?? '',
        dosage: json['medication_dosage'] as String?,
        frequency: json['medication_frequency'] as String?,
        duration: json['medication_duration'] as String?,
        notes: json['medication_notes'] as String?,
        doctorName: json['doctor_name'] as String?,
      );
}
