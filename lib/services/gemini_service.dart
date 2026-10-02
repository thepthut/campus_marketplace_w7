import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service สำหรับเรียก Gemini API แบบข้อความล้วน (Text Generation)
class GeminiService {
  // อ่านค่า Key จาก --dart-define=GEMINI_API_KEY=... ตอนรันแอป
  // (ไม่ต้องแก้บรรทัดนี้เป็น Key จริง ห้าม Hardcode Key ลงในโค้ด)
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // ชื่อโมเดล ถ้าเจอ 404 หรือ 503 บ่อย ให้เปลี่ยนเป็นโมเดลอื่นจาก
  // https://ai.google.dev/gemini-api/docs/models
  static const model = 'gemini-3.5-flash-lite';

  static const baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'ไม่พบ GEMINI_API_KEY กรุณารันด้วย flutter run --dart-define=GEMINI_API_KEY=your_key');
    }

    final uri = Uri.parse('$baseUrl/$model:generateContent');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      // 1) ตรวจ Status Code ก่อนเสมอ
      if (response.statusCode != 200) {
        throw Exception(messageForStatus(response.statusCode));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // 2) ตรวจว่า candidates มีข้อมูลจริง ก่อนเข้าถึง candidates[0]
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('AI ไม่สามารถตอบคำขอนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม');
      }

      final first = candidates[0] as Map<String, dynamic>;
      if (first['finishReason'] == 'SAFETY') {
        throw Exception('คำขอนี้เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini');
      }

      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('AI ไม่ได้ส่งข้อความตอบกลับมา กรุณาลองใหม่อีกครั้ง');
      }

      // รวมข้อความทุก part เข้าด้วยกัน (ปกติจะมี part เดียว)
      return parts
          .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
          .join();
    } on TimeoutException {
      throw Exception('AI ใช้เวลาตอบนานเกินไป กรุณาลองใหม่อีกครั้ง');
    } on http.ClientException {
      throw Exception('ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ');
    } on FormatException {
      throw Exception('ข้อมูลที่ได้รับจาก Gemini ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง');
    }
  }

  /// แปลง Status Code เป็นข้อความภาษาไทยที่ผู้ใช้เข้าใจ
  /// (เป็น static เพื่อให้ GeminiVisionService เรียกใช้ซ้ำได้)
  static String messageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'คำขอไม่ถูกต้อง หรือ API Key ไม่ถูกต้อง (400)';
      case 403:
        return 'ไม่มีสิทธิ์เข้าถึง กรุณาตรวจสอบ API Key (403)';
      case 404:
        return 'ไม่พบโมเดลที่ระบุ ชื่อโมเดลอาจผิดหรือถูกปลดระวางแล้ว (404)';
      case 429:
        return 'เรียกใช้งานถี่เกินโควตา กรุณารอสักครู่แล้วลองใหม่ (429)';
      case 500:
      case 503:
        return 'เซิร์ฟเวอร์ Gemini ไม่พร้อมใช้งานชั่วคราว กรุณาลองใหม่ ($statusCode)';
      default:
        return 'เกิดข้อผิดพลาดจาก Gemini API (สถานะ $statusCode)';
    }
  }
}