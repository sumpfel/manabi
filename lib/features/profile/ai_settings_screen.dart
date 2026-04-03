import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/settings_service.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late TextEditingController _geminiKeyController;
  late TextEditingController _openaiKeyController;
  late TextEditingController _anthropicKeyController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _geminiKeyController = TextEditingController(text: settings.geminiApiKey);
    _openaiKeyController = TextEditingController(text: settings.openaiApiKey);
    _anthropicKeyController = TextEditingController(text: settings.anthropicApiKey);
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _openaiKeyController.dispose();
    _anthropicKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('KI-Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider selection
          const Text('KI-Anbieter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gemini', label: Text('Gemini'), icon: Icon(Icons.auto_awesome)),
              ButtonSegment(value: 'openai', label: Text('OpenAI'), icon: Icon(Icons.cloud)),
              ButtonSegment(value: 'anthropic', label: Text('Anthropic'), icon: Icon(Icons.psychology)),
              ButtonSegment(value: 'ollama', label: Text('Ollama'), icon: Icon(Icons.dns)),
            ],
            selected: {settings.aiProvider},
            onSelectionChanged: (v) {
              notifier.updateAiProvider(v.first);
              // Set default model for the provider
              switch (v.first) {
                case 'openai':
                  if (settings.aiModel.startsWith('gemini') || settings.aiModel.startsWith('claude')) {
                    notifier.updateAiModel('gpt-4o-mini');
                  }
                  break;
                case 'anthropic':
                  if (settings.aiModel.startsWith('gemini') || settings.aiModel.startsWith('gpt')) {
                    notifier.updateAiModel('claude-sonnet-4-5-20250514');
                  }
                  break;
                case 'gemini':
                  if (!settings.aiModel.startsWith('gemini')) {
                    notifier.updateAiModel('gemini-2.0-flash');
                  }
                  break;
                case 'ollama':
                  notifier.updateAiModel('llama3.2:3b');
                  break;
              }
            },
          ),
          const SizedBox(height: 24),

          // API Keys
          const Text('API-Schlüssel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _geminiKeyController,
            decoration: InputDecoration(
              labelText: 'Gemini API-Key',
              prefixIcon: const Icon(Icons.key),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: settings.aiProvider == 'gemini' ? const Icon(Icons.check_circle, color: Colors.green) : null,
            ),
            obscureText: true,
            onChanged: (v) => notifier.updateGeminiApiKey(v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openaiKeyController,
            decoration: InputDecoration(
              labelText: 'OpenAI API-Key',
              prefixIcon: const Icon(Icons.key),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: settings.aiProvider == 'openai' ? const Icon(Icons.check_circle, color: Colors.green) : null,
            ),
            obscureText: true,
            onChanged: (v) => notifier.updateOpenaiApiKey(v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _anthropicKeyController,
            decoration: InputDecoration(
              labelText: 'Anthropic API-Key',
              prefixIcon: const Icon(Icons.key),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: settings.aiProvider == 'anthropic' ? const Icon(Icons.check_circle, color: Colors.green) : null,
            ),
            obscureText: true,
            onChanged: (v) => notifier.updateAnthropicApiKey(v),
          ),
          const SizedBox(height: 24),

          // Model selection
          const Text('KI-Modell', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _modelsForProvider(settings.aiProvider).contains(settings.aiModel)
                ? settings.aiModel
                : _modelsForProvider(settings.aiProvider).first,
            itemHeight: 64.0,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.smart_toy),
            ),
            items: _buildModelDropdownItems(settings.aiProvider),
            onChanged: (v) {
              if (v != null) notifier.updateAiModel(v);
            },
          ),
          const SizedBox(height: 24),

          // Language level
          const Text('Sprachniveau', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A1', label: Text('A1')),
              ButtonSegment(value: 'A2', label: Text('A2')),
              ButtonSegment(value: 'B1', label: Text('B1')),
              ButtonSegment(value: 'B2', label: Text('B2')),
              ButtonSegment(value: 'C1', label: Text('C1')),
            ],
            selected: {settings.aiLanguageLevel},
            onSelectionChanged: (v) => notifier.updateAiLevel(v.first),
          ),
          const SizedBox(height: 24),

          // Chat display options
          const Text('Chat-Anzeige', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Romaji im Chat anzeigen'),
            value: settings.showRomajiInChat,
            onChanged: (v) => notifier.toggleRomajiInChat(v),
          ),
          SwitchListTile(
            title: const Text('Hiragana-Lesungen anzeigen'),
            value: settings.showHiraganaInChat,
            onChanged: (v) => notifier.toggleHiraganaInChat(v),
          ),
          SwitchListTile(
            title: const Text('Deutsche Sätze einfärben'),
            value: settings.colorGermanSentences,
            onChanged: (v) => notifier.toggleColorGerman(v),
          ),
          const SizedBox(height: 24),

          // Color settings
          const Text('Wortart-Farben', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _colorTile('Partikel', settings.colorParticles, (c) => notifier.updateColorParticles(c)),
          _colorTile('Verben', settings.colorVerbs, (c) => notifier.updateColorVerbs(c)),
          _colorTile('Nomen', settings.colorNouns, (c) => notifier.updateColorNouns(c)),
          _colorTile('Adjektive', settings.colorAdjectives, (c) => notifier.updateColorAdjectives(c)),
          _colorTile('Adverbien', settings.colorAdverbs, (c) => notifier.updateColorAdverbs(c)),
          const SizedBox(height: 24),

          // Vocab restrictions
          const Text('Vokabel-Einschränkungen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Nur bekannte Vokabeln verwenden'),
            subtitle: const Text('KI verwendet nur Wörter aus deinen Decks'),
            value: settings.restrictToKnownVocab,
            onChanged: (v) => notifier.toggleRestrictVocab(v),
          ),
          ListTile(
            title: const Text('Max. neue Wörter pro Antwort'),
            trailing: DropdownButton<int>(
              value: settings.maxNewWordsPerResponse,
              items: [1, 2, 3, 5, 10].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (v) { if (v != null) notifier.updateMaxNewWords(v); },
            ),
          ),
          const SizedBox(height: 24),

          // Deck routing
          const Text('Vokabel-Deck Zuordnung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: settings.aiDeckRouting,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'per_chat', child: Text('Pro Chat ein Deck')),
              DropdownMenuItem(value: 'per_n_words', child: Text('Alle N Wörter neues Deck')),
              DropdownMenuItem(value: 'target_deck', child: Text('Immer in ein Ziel-Deck')),
            ],
            onChanged: (v) { if (v != null) notifier.updateAiDeckRouting(v); },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<String> _modelsForProvider(String provider) {
    switch (provider) {
      case 'openai':
        return ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini', 'gpt-4.1', 'o4-mini'];
      case 'anthropic':
        return ['claude-sonnet-4-5-20250514', 'claude-haiku-4-5-20251001', 'claude-opus-4-6-20250618'];
      case 'ollama':
        return ['llama3.2:3b', 'mistral:7b', 'gemma:2b', 'qwen2.5:7b', 'llama3'];
      default:
        return ['gemini-2.0-flash', 'gemini-2.0-flash-lite', 'gemini-2.5-flash-preview-05-20', 'gemini-2.5-pro-preview-05-06'];
    }
  }

  List<DropdownMenuItem<String>> _buildModelDropdownItems(String provider) {
    if (provider != 'ollama') {
      return _modelsForProvider(provider).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList();
    }
    final ollamaModels = [
      {'id': 'llama3.2:3b', 'desc': 'Schnell, gut für Sprachen'},
      {'id': 'mistral:7b', 'desc': 'Gutes logisches  Verständnis'},
      {'id': 'gemma:2b', 'desc': 'Sehr schnell, kompakt'},
      {'id': 'qwen2.5:7b', 'desc': 'Exzellente Grammatik (N1)'},
      {'id': 'llama3', 'desc': 'Allrounder (Hohe Qualität)'},
    ];
    return ollamaModels.map((m) {
      return DropdownMenuItem<String>(
        value: m['id']!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m['id']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text(m['desc']!, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      );
    }).toList();
  }

  Widget _colorTile(String label, String currentHex, Function(String) onChanged) {
    Color color;
    try {
      color = Color(int.parse(currentHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = Colors.grey;
    }
    return ListTile(
      title: Text(label),
      trailing: GestureDetector(
        onTap: () => _showColorPicker(label, currentHex, onChanged),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
        ),
      ),
    );
  }

  void _showColorPicker(String label, String currentHex, Function(String) onChanged) {
    final colors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7', '#3F51B5',
      '#2196F3', '#03A9F4', '#00BCD4', '#009688', '#4CAF50',
      '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107', '#FF9800',
      '#FF5722', '#795548', '#9E9E9E', '#607D8B',
      '#4FC3F7', '#FF8A65', '#81C784', '#CE93D8', '#FFD54F',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Farbe für $label'),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: colors.map((hex) {
            final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
            return GestureDetector(
              onTap: () {
                onChanged(hex);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(color: hex == currentHex ? Colors.white : Colors.transparent, width: 3),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
