import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiMatchService {
  GeminiMatchService();

  // Insert your Gemini API key here.
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";  
  static const String _model = "gemini-1.5-flash";

  bool get isConfigured => apiKey.isNotEmpty;

  Future<GeminiMatchResult?> rankNgoCandidates({
    required String foodName,
    required String category,
    required int quantity,
    required double foodLat,
    required double foodLng,
    required double expiryHoursRemaining,
    required List<Map<String, dynamic>> candidates,
  }) async {
    if (!isConfigured || candidates.isEmpty) return null;

    final uri = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey",
    );

    final prompt = """
You are ranking NGOs for food rescue.
Priority:
1) Capacity fit first.
2) Then nearest true distance.

Food listing:
- Name: $foodName
- Category: $category
- Quantity: $quantity
- Pickup coordinates: ($foodLat, $foodLng)
- Expiry in hours: ${expiryHoursRemaining.toStringAsFixed(2)}

Candidates JSON:
${jsonEncode(candidates)}

Return STRICT JSON only (no markdown):
{
  "selectedNgoId": "string",
  "reason": "short reason",
  "confidence": 0-100
}
""";

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidatesArr = decoded["candidates"];
    if (candidatesArr is! List || candidatesArr.isEmpty) return null;

    final content = candidatesArr.first["content"] as Map<String, dynamic>?;
    final parts = content?["parts"] as List?;
    if (parts == null || parts.isEmpty) return null;
    final text = (parts.first["text"] ?? "").toString();
    if (text.isEmpty) return null;

    final jsonText = _extractJsonObject(text);
    if (jsonText == null) return null;

    final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    final selectedNgoId = (parsed["selectedNgoId"] ?? "").toString();
    if (selectedNgoId.isEmpty) return null;

    final reason = (parsed["reason"] ?? "Selected by Gemini.").toString();
    final confidence = _toInt(parsed["confidence"]).clamp(0, 100);

    return GeminiMatchResult(
      selectedNgoId: selectedNgoId,
      reason: reason,
      confidence: confidence,
    );
  }

  String? _extractJsonObject(String text) {
    final start = text.indexOf("{");
    final end = text.lastIndexOf("}");
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class GeminiMatchResult {
  const GeminiMatchResult({
    required this.selectedNgoId,
    required this.reason,
    required this.confidence,
  });

  final String selectedNgoId;
  final String reason;
  final int confidence;
}
