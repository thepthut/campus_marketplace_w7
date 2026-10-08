import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../repositories/favorites_repository.dart';

class FavoritesPage extends StatefulWidget {
  final FavoritesRepository repository;
  const FavoritesPage({super.key, required this.repository});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<FavoriteItem>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = widget.repository.getAllFavorites();
  }

  // MainScaffold สร้าง pages ใหม่ทุกครั้งที่สลับ Tab (setState)
  // จึงโหลดรายการใหม่ตรงนี้ เพื่อให้เห็นสินค้าที่เพิ่งกดหัวใจจากหน้า Home ทันที
  @override
  void didUpdateWidget(covariant FavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ไม่ต้อง setState ตรงนี้ เพราะ Flutter จะเรียก build ต่อให้อยู่แล้ว
    _favoritesFuture = widget.repository.getAllFavorites();
  }

  void _reload() {
    setState(() {
      _favoritesFuture = widget.repository.getAllFavorites();
    });
  }

  Future<void> _remove(FavoriteItem fav) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.removeFavorite(fav.itemId);
      _reload();
      messenger.showSnackBar(
        SnackBar(content: Text('ลบ "${fav.title}" ออกจากรายการโปรดแล้ว')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายการโปรด')),
      body: FutureBuilder<List<FavoriteItem>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          final favorites = snapshot.data ?? [];
          if (favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ยังไม่มีรายการโปรด ลองกดหัวใจที่หน้าหลักดูสิ',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final fav = favorites[index];
              return ListTile(
                leading: Image.network(
                  fav.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  // ตอนออฟไลน์โหลดรูปไม่ได้ แสดงไอคอนแทน แต่ title/price ยังมาจากฐานข้อมูล
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported),
                ),
                title: Text(fav.title),
                subtitle: Text('${fav.price} บาท'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(fav),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
