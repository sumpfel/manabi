import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/ai_service.dart';

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
    final ollamaModelsAsync = ref.watch(ollamaModelsProvider);
    
    // Merge fetched Ollama models with hardcoded ones if needed, 
    // or just use fetched ones.
    final fetchedOllamaModels = ollamaModelsAsync.value ?? [];

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
            value: _modelsForProvider(settings.aiProvider, fetchedOllamaModels).contains(settings.aiModel)
                ? settings.aiModel
                : _modelsForProvider(settings.aiProvider, fetchedOllamaModels).firstOrNull ?? 'gemini-2.0-flash',
            itemHeight: 64.0,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.smart_toy),
            ),
            items: _buildModelDropdownItems(settings.aiProvider, fetchedOllamaModels),
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
          const Text('Anzeige & Tutor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Furigana anzeigen'),
            subtitle: const Text('Lesehilfen über Kanji einblenden'),
            value: settings.showFurigana,
            onChanged: (v) => notifier.toggleShowFurigana(v),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('Grammatik-Farben'),
            subtitle: const Text('Wortarten farblich hervorheben'),
            value: settings.showColorGrammar,
            onChanged: (v) => notifier.toggleShowColorGrammar(v),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('Erklärungs-Sprache', style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'de', label: Text('Deutsch'), icon: Icon(Icons.language)),
              ButtonSegment(value: 'ja', label: Text('Japanisch'), icon: Icon(Icons.translate)),
            ],
            selected: {settings.aiExplanationLanguage},
            onSelectionChanged: (v) => notifier.updateAiExplanationLanguage(v.first),
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
          const Text('KI-Verhalten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Nur bekannte Vokabeln'),
            subtitle: const Text('KI nutzt Wörter aus deinen Decks'),
            value: settings.restrictToKnownVocab,
            onChanged: (v) => notifier.toggleRestrictVocab(v),
            activeColor: Theme.of(context).colorScheme.primary,
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

  List<String> _modelsForProvider(String provider, List<Map<String, dynamic>> ollamaModels) {
    switch (provider) {
      case 'openai':
        return ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini', 'gpt-4.1', 'o4-mini'];
      case 'anthropic':
        return ['claude-sonnet-4-5-20250514', 'claude-haiku-4-5-20251001', 'claude-opus-4-6-20250618'];
      case 'ollama':
        if (ollamaModels.isNotEmpty) {
          return ollamaModels.map((m) => m['name'] as String).toList();
        }
        return ['gemma4:latest', 'llama3.2:3b', 'gemma2:9b', 'phi4:14b', 'mistral:7b', 'gemma2:27b', 'qwen2.5:7b', 'llama3'];
      default:
        return ['gemini-2.0-flash', 'gemini-2.0-flash-lite', 'gemini-2.5-flash-preview-05-20', 'gemini-2.5-pro-preview-05-06'];
    }
  }

  List<DropdownMenuItem<String>> _buildModelDropdownItems(String provider, List<Map<String, dynamic>> fetchedOllamaModels) {
    if (provider != 'ollama') {
      return _modelsForProvider(provider, []).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList();
    }
    
    // If we have fetched models, use them
    if (fetchedOllamaModels.isNotEmpty) {
      return fetchedOllamaModels.map((m) {
        final name = m['name'] as String;
        final size = m['size_gb'] as double;
        final quality = m['quality'] as String;
        return DropdownMenuItem<String>(
          value: name,
          child: SizedBox(
            height: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.1)),
                Text('$quality (${size} GB)', style: const TextStyle(color: Colors.white54, fontSize: 9, height: 1.1), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      }).toList();
    }

    // Fallback to hardcoded list if fetch failed or still loading
    final ollamaModels = [
      {'id': 'gemma4:latest', 'desc': 'Neuestes Modell (9.6 GB)'},
      {'id': 'llama3.2:3b', 'desc': 'Schnell, gut für Sprachen'},
      {'id': 'gemma2:9b', 'desc': 'Empfohlen (Ausgewogen)'},
      {'id': 'phi4:14b', 'desc': 'Sehr logisch, hohe Qualität'},
      {'id': 'mistral:7b', 'desc': 'Gutes logisches  Verständnis'},
      {'id': 'gemma2:27b', 'desc': 'Exzellent (Langsam, viel VRAM)'},
      {'id': 'qwen2.5:7b', 'desc': 'Exzellente Grammatik (N1)'},
      {'id': 'llama3', 'desc': 'Allrounder (Hohe Qualität)'},
    ];
    return ollamaModels.map((m) {
      return DropdownMenuItem<String>(
        value: m['id']!,
        child: SizedBox(
          height: 64, // Match itemHeight
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            children: [
              Text(m['id']!, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.1)),
              Text(m['desc']!, style: const TextStyle(color: Colors.white54, fontSize: 9, height: 1.1), overflow: TextOverflow.ellipsis),
            ],
          ),
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
