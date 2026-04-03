import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/vocab.dart';

/// All exportable CSV column definitions
class CsvColumn {
  final String key;
  final String label;
  final String Function(Vocab v) extractor;

  const CsvColumn(this.key, this.label, this.extractor);
}

final allCsvColumns = <CsvColumn>[
  CsvColumn('kanji', 'Kanji', (v) => v.kanji ?? ''),
  CsvColumn('kana', 'Kana', (v) => v.kana),
  CsvColumn('translation', 'Translation', (v) => v.translation),
  CsvColumn('translation_en', 'Translation EN', (v) => v.translationEn ?? ''),
  CsvColumn('translation_de', 'Translation DE', (v) => v.translationDe ?? ''),
  CsvColumn('example_sentence', 'Example Sentence', (v) => v.exampleSentence ?? ''),
  CsvColumn('example_translation', 'Example Translation', (v) => v.exampleTranslation ?? ''),
  CsvColumn('notes', 'Notes', (v) => v.notes ?? ''),
  CsvColumn('manga_title', 'Manga Title', (v) => v.mangaTitle ?? ''),
  CsvColumn('chapter', 'Chapter', (v) => v.chapter ?? ''),
];

class CsvService {
  /// Escapes a CSV field value (wraps in quotes if it contains comma, newline, or quote)
  static String _escapeField(String value) {
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Export vocab list to CSV with selected columns in specified order
  static Future<void> exportToCsv({
    required List<Vocab> vocabList,
    required List<CsvColumn> columns,
    required bool includeHeader,
    required String deckName,
  }) async {
    final buffer = StringBuffer();

    if (includeHeader) {
      buffer.writeln(columns.map((c) => _escapeField(c.label)).join(','));
    }

    for (final vocab in vocabList) {
      buffer.writeln(columns.map((c) => _escapeField(c.extractor(vocab))).join(','));
    }

    final dir = await getTemporaryDirectory();
    final safeName = deckName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final file = File('${dir.path}/${safeName}_export.csv');
    await file.writeAsString(buffer.toString(), encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '$deckName.csv',
    );
  }

  /// Parse a CSV string into rows of fields
  static List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final fields = <String>[];
      bool inQuotes = false;
      final buffer = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final c = line[i];
        if (inQuotes) {
          if (c == '"' && i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else if (c == '"') {
            inQuotes = false;
          } else {
            buffer.write(c);
          }
        } else {
          if (c == '"') {
            inQuotes = true;
          } else if (c == ',') {
            fields.add(buffer.toString());
            buffer.clear();
          } else {
            buffer.write(c);
          }
        }
      }
      fields.add(buffer.toString());
      rows.add(fields);
    }
    return rows;
  }

  /// Pick a CSV file and parse it into Vocab objects
  /// Returns null if user cancels, or a list of Vocab with the given deckId
  static Future<List<Vocab>?> importFromCsv({required int deckId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString(encoding: utf8);
    final rows = _parseCsv(content);
    if (rows.isEmpty) return [];

    // Try to detect header row
    final firstRow = rows.first.map((f) => f.toLowerCase().trim()).toList();
    final knownHeaders = {'kanji', 'kana', 'translation', 'translation_en', 'translation_de', 'example_sentence', 'example_translation', 'notes'};
    final hasHeader = firstRow.any((f) => knownHeaders.contains(f));

    final dataRows = hasHeader ? rows.sublist(1) : rows;
    final headers = hasHeader ? firstRow : null;

    final vocabs = <Vocab>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in dataRows) {
      if (row.every((f) => f.trim().isEmpty)) continue;

      String getField(String name, [int? fallbackIndex]) {
        if (headers != null) {
          final idx = headers.indexOf(name);
          if (idx >= 0 && idx < row.length) return row[idx].trim();
        }
        if (fallbackIndex != null && fallbackIndex < row.length) return row[fallbackIndex].trim();
        return '';
      }

      final kanji = getField('kanji', 0);
      final kana = getField('kana', 1);
      final translation = getField('translation', 2);
      final translationEn = getField('translation_en');
      final translationDe = getField('translation_de');
      final exampleSentence = getField('example_sentence');
      final exampleTranslation = getField('example_translation');
      final notes = getField('notes');

      if (kana.isEmpty && kanji.isEmpty) continue;

      vocabs.add(Vocab(
        deckId: deckId,
        kanji: kanji.isEmpty ? null : kanji,
        kana: kana.isEmpty ? kanji : kana,
        translation: translation.isEmpty ? (translationDe.isNotEmpty ? translationDe : translationEn) : translation,
        translationEn: translationEn.isEmpty ? null : translationEn,
        translationDe: translationDe.isEmpty ? null : translationDe,
        exampleSentence: exampleSentence.isEmpty ? null : exampleSentence,
        exampleTranslation: exampleTranslation.isEmpty ? null : exampleTranslation,
        notes: notes.isEmpty ? null : notes,
        dueDate: now,
      ));
    }

    return vocabs;
  }
}
