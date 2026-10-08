import 'dart:io';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../repositories/listing_draft_repository.dart';

class MyDraftsPage extends StatefulWidget {
  final ListingDraftRepository repository;
  const MyDraftsPage({super.key, required this.repository});

  @override
  State<MyDraftsPage> createState() => _MyDraftsPageState();
}

class _MyDraftsPageState extends State<MyDraftsPage> {
  late Future<List<ListingDraftRow>> _draftsFuture;

  @override
  void initState() {
    super.initState();
    _draftsFuture = widget.repository.getAllDrafts();
  }

  void _reload() {
    setState(() {
      _draftsFuture = widget.repository.getAllDrafts();
    });
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _delete(ListingDraftRow draft) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.deleteDraft(draft.id);
      _reload();
      messenger.showSnackBar(SnackBar(content: Text('ลบร่าง "${draft.title}" แล้ว')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ร่างประกาศของฉัน')),
      body: FutureBuilder<List<ListingDraftRow>>(
        future: _draftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          final drafts = snapshot.data ?? [];
          if (drafts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ยังไม่มีร่างประกาศ ลองถ่ายรูปสินค้าแล้วให้ AI ช่วยร่างดูสิ',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final imageFile = File(draft.imagePath);
              return ListTile(
                leading: imageFile.existsSync()
                    ? Image.file(imageFile, width: 48, height: 48, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported),
                title: Text(draft.title),
                subtitle: Text(
                  '${draft.category}\nแก้ไขล่าสุด: ${_formatDate(draft.updatedAt)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(draft),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
