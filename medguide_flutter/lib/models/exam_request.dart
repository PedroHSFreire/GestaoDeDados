class ExamRequest {
  const ExamRequest({
    required this.id,
    required this.examType,
    required this.description,
    required this.status,
    required this.requestDate,
    this.doctorName,
    this.patientName,
  });

  final String id;
  final String examType;
  final String description;
  final String status;
  final DateTime requestDate;
  final String? doctorName;
  final String? patientName;

  factory ExamRequest.fromJson(Map<String, dynamic> json) => ExamRequest(
        id: json['id'] as String,
        examType: json['exam_type'] as String,
        description: json['description'] as String? ?? '',
        status: json['status'] as String,
        requestDate: DateTime.parse(json['request_date'] as String),
        doctorName: json['doctor_name'] as String?,
        patientName: json['patient_name'] as String?,
      );
}
