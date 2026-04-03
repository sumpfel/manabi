import 'dart:ui';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class OcrResult {
  final String text;
  final Rect boundingBox;

  OcrResult({required this.text, required this.boundingBox});
}

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);

  Future<List<OcrResult>> processImage(String imageUrl) async {
    try {
      File file;
      if (imageUrl.startsWith('http') || imageUrl.startsWith('https')) {
        file = await DefaultCacheManager().getSingleFile(imageUrl);
      } else {
        file = File(imageUrl);
      }
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      List<OcrResult> results = [];
      // Grouping elements manually completely bypasses ML Kit's built-in horizontal line-grouping.
      // E.g. ML Kit might see 3 vertical columns side-by-side but incorrectly group them as 10 horizontal lines across the columns.
      for (TextBlock block in recognizedText.blocks) {
         final isVertical = block.boundingBox.height > block.boundingBox.width;
         
         List<TextElement> allElements = [];
         for (TextLine line in block.lines) {
            allElements.addAll(line.elements);
         }
         
         String text = '';
         if (isVertical) {
             // 1. Sort all elements right-to-left by their center-X
             allElements.sort((a, b) => b.boundingBox.center.dx.compareTo(a.boundingBox.center.dx));
             
             // 2. Group these elements into proper vertical columns
             List<List<TextElement>> columns = [];
             for (var element in allElements) {
                 bool placed = false;
                 for (var column in columns) {
                    if (column.isEmpty) continue;
                    double colCenterX = column.map((e) => e.boundingBox.center.dx).reduce((a, b) => a + b) / column.length;
                    if ((colCenterX - element.boundingBox.center.dx).abs() < 30) {
                       column.add(element);
                       placed = true;
                       break;
                    }
                 }
                 if (!placed) {
                    columns.add([element]);
                 }
             }
             
             // 3. The columns are ordered right-to-left. Sort elements inside each column top-to-bottom.
             for (var column in columns) {
                 column.sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));
                 text += column.map((e) => e.text).join('');
             }
         } else {
             // 1. Sort all elements top-to-bottom by their center-Y
             allElements.sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));
             
             // 2. Group by rows
             List<List<TextElement>> rows = [];
             for (var element in allElements) {
                 bool placed = false;
                 for (var row in rows) {
                    if (row.isEmpty) continue;
                    double rowCenterY = row.map((e) => e.boundingBox.center.dy).reduce((a, b) => a + b) / row.length;
                    if ((rowCenterY - element.boundingBox.center.dy).abs() < 20) {
                       row.add(element);
                       placed = true;
                       break;
                    }
                 }
                 if (!placed) {
                    rows.add([element]);
                 }
             }
             
             // 3. For each row, sort left-to-right
             for (var row in rows) {
                 row.sort((a, b) => a.boundingBox.center.dx.compareTo(b.boundingBox.center.dx));
                 text += row.map((e) => e.text).join(' '); // Add spaces for horizontal words!
             }
             text = text.trim();
         }
         
         results.add(OcrResult(
            text: text,
            boundingBox: block.boundingBox,
         ));
      }
      return results;
    } catch (e) {
      throw Exception('Failed to process image for OCR: $e');
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
