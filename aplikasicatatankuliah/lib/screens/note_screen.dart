import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/course.dart';
import '../models/note.dart';
import '../services/firebase_service.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  final FirebaseService _service = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  Course? _selectedCourse;
  List<Course> _courses = [];
  List<Note> _notes = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _coursesLoaded = false;

  StreamSubscription? _coursesSub;
  StreamSubscription? _notesSub;

  @override
  void initState() {
    super.initState();
    _coursesSub = _service.getCourses().listen((data) {
      if (mounted) setState(() { _courses = data; _coursesLoaded = true; });
    });
    _notesSub = _service.getNotes().listen((data) {
      if (mounted) setState(() => _notes = data);
    });
  }

  @override
  void dispose() {
    _coursesSub?.cancel();
    _notesSub?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _formatTimestamp(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateFormat('dd MMM yyyy, HH:mm', 'id').format(dt);
  }

  void _resetForm() {
    _titleController.clear();
    _contentController.clear();
    setState(() => _selectedCourse = null);
  }

  Future<void> _saveNote({Note? existing}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih mata kuliah dulu!'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final note = Note(
        id: existing?.id ?? '',
        courseId: _selectedCourse!.id,
        courseName: _selectedCourse!.name,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        timestamp: existing?.timestamp ?? DateTime.now().millisecondsSinceEpoch,
      );
      if (existing != null) {
        await _service.updateNote(existing.id, note);
      } else {
        await _service.addNote(note);
      }
      _resetForm();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing != null ? 'Catatan diperbarui!' : 'Catatan ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: Text('Yakin hapus "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteNote(note.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan dihapus'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showNoteForm({Note? existing}) {
    if (existing != null) {
      _titleController.text = existing.title;
      _contentController.text = existing.content;
      setState(() {
        _selectedCourse = _courses.firstWhere(
          (c) => c.id == existing.courseId,
          orElse: () => _courses.first,
        );
      });
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(existing != null ? Icons.edit_note : Icons.note_add, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(
                        existing != null ? 'Edit Catatan' : 'Tambah Catatan',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<Course>(
                    value: _selectedCourse,
                    decoration: const InputDecoration(
                      labelText: 'Mata Kuliah',
                      prefixIcon: Icon(Icons.school),
                      border: OutlineInputBorder(),
                    ),
                    items: _courses.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                    onChanged: (val) {
                      setModalState(() => _selectedCourse = val);
                      setState(() => _selectedCourse = val);
                    },
                    hint: const Text('Pilih mata kuliah'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Catatan',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Isi Catatan',
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _saveNote(existing: existing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(existing != null ? 'Perbarui' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(note.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(note.courseName,
                    style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Text(note.content),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(_formatTimestamp(note.timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showNoteForm(existing: note);
            },
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _notes
        : _notes.where((n) =>
            n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.courseName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Kuliah'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: !_coursesLoaded
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _notes.isEmpty ? 'Belum ada catatan' : 'Catatan tidak ditemukan',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _notes.isEmpty ? 'Tap tombol + untuk menambahkan' : 'Coba kata kunci lain',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final note = filtered[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showDetailDialog(note),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.indigo.shade200),
                                    ),
                                    child: Text(
                                      note.courseName,
                                      style: TextStyle(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Spacer(),
                                  PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'edit') _showNoteForm(existing: note);
                                      if (val == 'delete') _deleteNote(note);
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))]),
                                      ),
                                    ],
                                    child: const Icon(Icons.more_vert, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(note.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(_formatTimestamp(note.timestamp),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteForm(),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Catatan'),
      ),
    );
  }
}