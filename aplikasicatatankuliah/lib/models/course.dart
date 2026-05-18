class Course {
  final String id;
  final String name;
  final String lecturer;

  Course({
    required this.id,
    required this.name,
    required this.lecturer,
  });

  factory Course.fromMap(String id, Map<dynamic, dynamic> map) {
    return Course(
      id: id,
      name: map['name'] ?? '',
      lecturer: map['lecturer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lecturer': lecturer,
    };
  }
}