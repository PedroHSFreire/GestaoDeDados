class Appointment {
  const Appointment({
    required this.id,
    required this.dateTime,
    required this.status,
    required this.type,
    required this.symptoms,
    required this.doctorId,
    this.patientId,
    this.doctorName,
    this.patientName,
    this.specialty,
    this.notes,
    this.diagnosis,
    this.prescription,
    this.doctorNotes,
  });

  final String id;
  final DateTime dateTime;
  final String status;
  final String type;
  final String symptoms;
  final String doctorId;
  final String? patientId;
  final String? doctorName;
  final String? patientName;
  final String? specialty;
  final String? notes;
  final String? diagnosis;
  final String? prescription;
  final String? doctorNotes;

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['date_time'] as String),
        status: json['status'] as String,
        type: json['appointment_type'] as String? ?? json['type'] as String? ?? 'online',
        symptoms: json['symptoms'] as String? ?? '',
        doctorId: json['doctor_id'] as String? ?? '',
        patientId: json['patient_id'] as String?,
        doctorName: json['doctor_name'] as String?,
        patientName: json['patient_name'] as String?,
        specialty: json['specialty'] as String?,
        notes: json['notes'] as String?,
        diagnosis: json['diagnosis'] as String?,
        prescription: json['prescription'] as String?,
        doctorNotes: json['doctor_notes'] as String?,
      );
}

class DoctorSummary {
  const DoctorSummary({required this.id, required this.name, required this.specialty, this.crm, this.address});

  final String id;
  final String name;
  final String specialty;
  final String? crm;
  final String? address;

  factory DoctorSummary.fromJson(Map<String, dynamic> json) => DoctorSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        specialty: json['specialty'] as String? ?? 'Especialidade não informada',
        crm: json['crm'] as String?,
        address: json['address'] as String?,
      );
}
