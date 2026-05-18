import 'package:firebase_database/firebase_database.dart';
import '../models/course.dart';
import '../models/note.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> addCourse(Course course) async {
    await _db.child('courses').push().set(course.toMap());
  }

  Stream<List<Course>> getCourses() {
    return _db.child('courses').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      return data.entries
          .map((e) => Course.fromMap(e.key.toString(), e.value as Map))
          .toList();
    });
  }

  Future<void> addNote(Note note) async {
    await _db.child('notes').push().set(note.toMap());
  }

  Future<void> updateNote(String id, Note note) async {
    await _db.child('notes/$id').update(note.toMap());
  }

  Future<void> deleteNote(String id) async {
    await _db.child('notes/$id').remove();
  }

  Stream<List<Note>> getNotes() {
    return _db.child('notes').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      final notes = data.entries
          .map((e) => Note.fromMap(e.key.toString(), e.value as Map))
          .toList();
      notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notes;
    });
  }
}