import 'package:flutter/material.dart';

class VocabTableView extends StatefulWidget {
  final List<Map<String, String>> vocabList;
  final String? title;

  const VocabTableView({super.key, required this.vocabList, this.title});

  @override
  State<VocabTableView> createState() => _VocabTableViewState();
}

class _VocabTableViewState extends State<VocabTableView> {
  bool _showReading = true;
  bool _showTranslation = true;
  bool _showExample = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(widget.title ?? 'Vokabel-Tabelle'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) {
              setState(() {
                if (val == 'reading') _showReading = !_showReading;
                if (val == 'translation') _showTranslation = !_showTranslation;
                if (val == 'example') _showExample = !_showExample;
              });
            },
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem(value: 'reading', checked: _showReading, child: const Text('Lesung')),
              CheckedPopupMenuItem(value: 'translation', checked: _showTranslation, child: const Text('Übersetzung')),
              CheckedPopupMenuItem(value: 'example', checked: _showExample, child: const Text('Beispiel')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            headingRowColor: WidgetStateProperty.all(Colors.white10),
            columns: [
              const DataColumn(label: Text('Wort', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
              if (_showReading) const DataColumn(label: Text('Lesung', style: TextStyle(fontWeight: FontWeight.bold))),
              if (_showTranslation) const DataColumn(label: Text('Übersetzung', style: TextStyle(fontWeight: FontWeight.bold))),
              if (_showExample) const DataColumn(label: Text('Beispielsatz', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: widget.vocabList.map((v) {
              return DataRow(cells: [
                DataCell(Text(v['word'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16))),
                if (_showReading) DataCell(Text(v['reading'] ?? '', style: const TextStyle(color: Colors.white70))),
                if (_showTranslation) DataCell(Text(v['translation'] ?? '', style: const TextStyle(color: Colors.white70))),
                if (_showExample) DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(v['example'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12), softWrap: true),
                  )
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
