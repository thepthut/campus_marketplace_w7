import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/listing_draft.dart';
import 'gemini_service.dart';

class GeminiVisionService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<ListingDraft> analyzeProductImage({
    required File imageFile,
    required String prompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('ไม่พบ GEMINI_API_KEY กรุณารันด้วย --dart-define=GEMINI_API_KEY=...');
    }

    // อ่านไฟล์ภาพเป็นไบต์ แล้วเข้ารหัส Base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // ใช้ชื่อโมเดลเดียวกับ GeminiService (แก้ที่เดียวพอ)
    final uri = Uri.parse(
        '${GeminiService.baseUrl}/${GeminiService.model}:generateContent');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'category': {
              'type': 'STRING',
              'enum': ['หนังสือเรียน', 'อุปกรณ์อิเล็กทรอนิกส์', 'ของแต่งหอพัก', 'เสื้อผ้า', 'อื่นๆ'],
            },
            'description': {'type': 'STRING'},
          },
          'required': ['title', 'category', 'description'],
        },
      },
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
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(GeminiService.messageForStatus(response.statusCode));
      }

      // jsonDecode ชั้นที่ 1: response ทั้งก้อน
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('AI ไม่สามารถวิเคราะห์ภาพนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม ลองใช้ภาพอื่น');
      }

      final first = candidates[0] as Map<String, dynamic>;
      if (first['finishReason'] == 'SAFETY') {
        throw Exception('เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น');
      }

      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('AI ไม่ได้ส่งผลการวิเคราะห์กลับมา กรุณาลองใหม่อีกครั้ง');
      }

      // jsonDecode ชั้นที่ 2: "text" เป็น String ที่ข้างในเป็น JSON
      final text = (parts[0] as Map<String, dynamic>)['text'] as String;
      final draftJson = jsonDecode(text) as Map<String, dynamic>;

      return ListingDraft.fromJson(draftJson);
    } on TimeoutException {
      throw Exception('AI ใช้เวลาวิเคราะห์นานเกินไป กรุณาลองใหม่อีกครั้ง');
    } on http.ClientException {
      throw Exception('ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ');
    } on FormatException {
      throw Exception('ผลลัพธ์จาก AI ไม่ใช่ JSON ที่ถูกต้อง กรุณาลองใหม่อีกครั้ง');
    }
  }
}