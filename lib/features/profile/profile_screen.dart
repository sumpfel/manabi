import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/i18n/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/auth_state_provider.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/progress_service.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/data/course_data.dart';
import 'ai_settings_screen.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';
import '../auth/login_screen.dart';
import './edit_profile_screen.dart';
import './ai_chat_screen.dart';
import '../../main.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _apiDomainController = TextEditingController();
  bool _isBackendOnline = false;
  bool _isCheckingStatus = false;
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    Future.microtask(() {
      checkAuthStatus(ref);
      _checkBackendStatus();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final customDomain = prefs.getString('custom_api_domain') ?? '';
    setState(() {
      _apiDomainController.text = customDomain;
    });
  }

  Future<void> _saveApiDomain() async {
    final prefs = await SharedPreferences.getInstance();
    String input = _apiDomainController.text.trim();
    if (input.isEmpty) return;

    // Clean input but keep IP
    String cleaned = input.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    if (!cleaned.contains(':')) {
       // Append default port if missing, but for the 'domain' we usually just store the host
       // However, to make it easy for the user, let's keep it simple.
    }

    _apiDomainController.text = cleaned;
    await prefs.setString('custom_api_domain', cleaned);
    await ref.read(settingsProvider.notifier).updateBackendUrl(cleaned);

    _checkBackendStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Host gespeichert!')));
    }
  }

  Future<void> _checkBackendStatus() async {
    setState(() {
      _isCheckingStatus = true;
      _lastError = '';
    });

    final settings = ref.read(settingsProvider);
    final domain = settings.backendUrl;

    if (domain.isEmpty) {
      setState(() {
        _isBackendOnline = false;
        _isCheckingStatus = false;
      });
      return;
    }

    try {
      final host = domain.contains(':') ? domain.split(':').first : domain;
      final port = domain.contains(':') ? int.tryParse(domain.split(':').last) ?? 8000 : 8000;

      final url = Uri.parse('http://$host:$port/api/health');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      setState(() {
        _isBackendOnline = response.statusCode == 200;
        _isCheckingStatus = false;
        if (!_isBackendOnline) {
           _lastError = 'Status: ${response.statusCode}';
           if (response.statusCode == 404) _lastError += ' (Endpoint fehlt)';
        }
      });
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('SocketException')) {
        errMsg = 'Verbindung abgelehnt oder Host nicht erreichbar.';
      }
      setState(() {
        _isBackendOnline = false;
        _isCheckingStatus = false;
        _lastError = errMsg;
      });
    }
  }

  Future<void> _changeIcon(String iconAlias) async {
    const channel = MethodChannel('com.example.frontend_app/icon');
    try {
      await channel.invokeMethod('setIcon', {'name': iconAlias});
      await ref.read(settingsProvider.notifier).updateSelectedIcon(iconAlias);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App-Icon wurde geändert!')),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to change icon: ${e.message}");
    }
  }

  // ── Export Methods ──

  Future<void> _exportUnitsAsJson() async {
    try {
      final units = CourseData.units;
      final jsonData = units.map((u) => u.toMap()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nexus_lingua_units.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportiert: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Export: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showExportVocabDeckDialog() async {
    final repo = ref.read(vocabRepositoryProvider);
    final decks = await repo.getDecks();
    if (decks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Decks vorhanden.')),
        );
      }
      return;
    }

    if (!mounted) return;

    Deck? selectedDeck = decks.first;
    final columns = {
      'kanji': true,
      'kana': true,
      'translationDe': true,
      'translationEn': true,
      'exampleSentence': false,
      'exampleTranslation': false,
      'notes': false,
    };
    final columnLabels = {
      'kanji': 'Japanisch (Kanji)',
      'kana': 'Kana/Hiragana',
      'translationDe': 'Deutsche Übersetzung',
      'translationEn': 'Englische Übersetzung',
      'exampleSentence': 'Beispielsatz',
      'exampleTranslation': 'Beispielsatz-Übersetzung',
      'notes': 'Notizen',
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Vokabel-Deck exportieren'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deck auswählen:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButton<Deck>(
                  value: selectedDeck,
                  isExpanded: true,
                  items: decks.map((d) => DropdownMenuItem(value: d, child: Text(d.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) => setDialogState(() => selectedDeck = val),
                ),
                const SizedBox(height: 16),
                const Text('Spalten:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...columns.keys.map((key) => CheckboxListTile(
                  dense: true,
                  title: Text(columnLabels[key]!, style: const TextStyle(fontSize: 13)),
                  value: columns[key],
                  onChanged: (val) => setDialogState(() => columns[key] = val ?? false),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _exportDeckAsCsv(selectedDeck!, columns);
              },
              child: const Text('Exportieren'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportDeckAsCsv(Deck deck, Map<String, bool> columns) async {
    try {
      final repo = ref.read(vocabRepositoryProvider);
      final vocabs = await repo.getVocabForDeck(deck.id!);

      final activeColumns = columns.entries.where((e) => e.value).map((e) => e.key).toList();
      if (activeColumns.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine Spalten ausgewählt.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final headerLabels = {
        'kanji': 'Kanji',
        'kana': 'Kana',
        'translationDe': 'Deutsch',
        'translationEn': 'Englisch',
        'exampleSentence': 'Beispielsatz',
        'exampleTranslation': 'Beispiel-Übersetzung',
        'notes': 'Notizen',
      };

      final buf = StringBuffer();
      buf.writeln(activeColumns.map((c) => _csvEscape(headerLabels[c]!)).join(','));

      for (final v in vocabs) {
        final values = activeColumns.map((c) {
          switch (c) {
            case 'kanji': return v.kanji ?? '';
            case 'kana': return v.kana;
            case 'translationDe': return v.translationDe ?? v.translation;
            case 'translationEn': return v.translationEn ?? v.translation;
            case 'exampleSentence': return v.exampleSentence ?? '';
            case 'exampleTranslation': return v.exampleTranslation ?? '';
            case 'notes': return v.notes ?? '';
            default: return '';
          }
        }).map(_csvEscape);
        buf.writeln(values.join(','));
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeName = deck.name.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File('${dir.path}/nexus_lingua_${safeName}.csv');
      await file.writeAsString(buf.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportiert: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Export: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── Reset Dialog ──

  Future<void> _showResetDialog() async {
    final checks = {
      'unitProgress': false,
      'vocabStats': false,
      'customDecks': false,
      'unitDecks': false,
      'mangaDecks': false,
      'mangaBookmarks': false,
    };
    final labels = {
      'unitProgress': 'Unit-Fortschritt (Lektionen & Genauigkeit)',
      'vocabStats': 'Vokabel-Statistiken (Richtig/Falsch, Streaks)',
      'customDecks': 'Eigene Vokabel-Decks löschen',
      'unitDecks': 'Unit-Decks löschen',
      'mangaDecks': 'Manga-Decks löschen',
      'mangaBookmarks': 'Manga-Lesezeichen löschen',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Fortschritt zurücksetzen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: checks.keys.map((key) => CheckboxListTile(
                dense: true,
                title: Text(labels[key]!, style: const TextStyle(fontSize: 13)),
                value: checks[key],
                onChanged: (val) => setDialogState(() => checks[key] = val ?? false),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ausgewählte löschen'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!checks.values.any((v) => v)) return;

    final repo = ref.read(vocabRepositoryProvider);
    final deleted = <String>[];

    if (checks['unitProgress']!) {
      await repo.resetUnitProgress();
      ref.invalidate(progressProvider);
      deleted.add('Unit-Fortschritt');
    }
    if (checks['vocabStats']!) {
      await repo.deleteVocabStats();
      deleted.add('Vokabel-Statistiken');
    }
    if (checks['customDecks']!) {
      await repo.deleteCustomDecks();
      deleted.add('Eigene Decks');
    }
    if (checks['unitDecks']!) {
      await repo.deleteUnitDecks();
      deleted.add('Unit-Decks');
    }
    if (checks['mangaDecks']!) {
      await repo.deleteMangaDecks();
      deleted.add('Manga-Decks');
    }
    if (checks['mangaBookmarks']!) {
      await repo.deleteMangaBookmarks();
      deleted.add('Manga-Lesezeichen');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gelöscht: ${deleted.join(", ")}'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isLoggedIn = ref.watch(authStateProvider);
    final username = ref.watch(usernameProvider);
    final streak = ref.watch(streakProvider);
    final theme = Theme.of(context);
    final s = AppStrings.of(settings.motherTongue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Einstellungen', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {})
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: const Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLoggedIn ? (username ?? 'Nutzer') : 'Gast',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (streak > 0)
                    Text('Streak: $streak Tage 🔥', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold))
                  else if (!isLoggedIn)
                    const Text('Kein Account nötig – Für Cloud-Sync optional', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  if (isLoggedIn)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Profil bearbeiten'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Jetzt einloggen / Registrieren'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const SizedBox(height: 20),

            // Settings Section
            _buildSectionHeader(s.navSettings),
            _buildSettingsCard([
              ListTile(
                leading: const Icon(Icons.psychology),
                title: Text(s.aiLanguageLevel),
                trailing: _buildAiLevelDropdown(settings.aiLanguageLevel, s, (val) {
                  if (val != null) ref.read(settingsProvider.notifier).updateAiLevel(val);
                }),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lock),
                title: const Text('Nur bekanntes Vokabular'),
                subtitle: const Text('KI verwendet primär Wörter aus deinen Decks'),
                value: settings.restrictToKnownVocab,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).toggleRestrictVocab(val);
                },
              ),
              if (settings.restrictToKnownVocab)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Max. neue Wörter'),
                  trailing: DropdownButton<int>(
                    value: settings.maxNewWordsPerResponse,
                    items: [1, 2, 3, 5].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (val) {
                      if (val != null) ref.read(settingsProvider.notifier).updateMaxNewWords(val);
                    },
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Muttersprache'),
                subtitle: const Text('UI & Übersetzungen', style: TextStyle(fontSize: 11)),
                trailing: _buildDropdown(
                  value: settings.motherTongue == 'en' ? 'Englisch' : 'Deutsch',
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateMotherTongue(val == 'Deutsch' ? 'de' : 'en');
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Launcher Icon'),
                subtitle: const Text('Wähle dein Lieblingsdesign', style: TextStyle(fontSize: 11)),
                trailing: DropdownButton<String>(
                  value: settings.selectedIcon,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'MainActivityDefault', child: Text('Sensei 🎓')),
                    DropdownMenuItem(value: 'MainActivityManga', child: Text('Manga 📚')),
                    DropdownMenuItem(value: 'MainActivityKanji', child: Text('Kanji 🉐')),
                  ],
                  onChanged: (val) {
                    if (val != null) _changeIcon(val);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader(s.themeColor),
            _buildSettingsCard([
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Design-Modus'),
                trailing: _buildThemeDropdown(settings.themeModeIndex, (val) {
                  ref.read(settingsProvider.notifier).updateThemeMode(val ?? 0);
                }),
              ),
              ListTile(
                leading: const Icon(Icons.color_lens),
                title: Text(s.themeColor),
                trailing: _buildColorDropdown(settings.themeColorValue, (val) {
                  ref.read(settingsProvider.notifier).updateThemeColor(val ?? 0xFF2196F3);
                }),
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('Entwickler & Netzwerk'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Backend API (IP-Adresse):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isCheckingStatus ? Colors.grey : (_isBackendOnline ? Colors.green : Colors.red),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isCheckingStatus ? 'Checking...' : (_isBackendOnline ? 'Online' : 'Offline'),
                                style: TextStyle(fontSize: 12, color: _isBackendOnline ? Colors.green : Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _apiDomainController,
                              decoration: const InputDecoration(
                                hintText: 'z.B. 192.168.1.100',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _checkBackendStatus,
                            icon: const Icon(Icons.refresh),
                          ),
                          ElevatedButton(
                            onPressed: _saveApiDomain,
                            child: const Text('Speichern'),
                          ),
                        ],
                      ),
                      if (_lastError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Error: $_lastError',
                            style: const TextStyle(fontSize: 10, color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tipp: Stelle sicher, dass dein PC im selben WLAN ist und der Port 8000 in der Firewall (ufw allow 8000) offen ist.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const Divider(height: 32),
                      // AI Settings navigation
                      ListTile(
                        leading: const Icon(Icons.smart_toy),
                        title: const Text('KI-Einstellungen'),
                        subtitle: Text(
                          settings.hasAnyAiKey
                            ? '${settings.aiProvider.toUpperCase()} - ${settings.aiModel}'
                            : 'API-Key nicht konfiguriert',
                          style: TextStyle(color: settings.hasAnyAiKey ? Colors.green : Colors.orange, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (isLoggedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => logout(ref),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Abmelden', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── SRS Settings Section ──
            _buildSectionHeader('SRS Einstellungen'),
            _buildSettingsCard([
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('SRS Modus'),
                subtitle: Text(settings.srsMode == 'shared' ? 'Gemeinsam für alle Lernmethoden' : 'Individuell pro Lernmethode'),
                trailing: DropdownButton<String>(
                  value: settings.srsMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'shared', child: Text('Gemeinsam')),
                    DropdownMenuItem(value: 'individual', child: Text('Individuell')),
                  ],
                  onChanged: (val) {
                    if (val != null) ref.read(settingsProvider.notifier).updateSrsMode(val);
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome),
                title: const Text('Manga-Vokabeln automatisch in SRS'),
                subtitle: const Text('Beim Speichern aus Manga direkt zum SRS'),
                value: settings.autoAddMangaSrs,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).toggleAutoAddMangaSrs(val);
                },
              ),
            ]),

            const SizedBox(height: 20),

            // ── Reset Progress Section ──
            _buildSectionHeader('Fortschritt zurücksetzen'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showResetDialog,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  label: const Text('Fortschritt zurücksetzen', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _buildDropdown({required String value, required Function(String?) onChanged}) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 'Deutsch', child: Text('Deutsch')),
        DropdownMenuItem(value: 'Englisch', child: Text('Englisch')),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildThemeDropdown(int value, Function(int?) onChanged) {
    return DropdownButton<int>(
      value: value,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 0, child: Text('System')),
        DropdownMenuItem(value: 1, child: Text('Hell')),
        DropdownMenuItem(value: 2, child: Text('Dunkel')),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildColorDropdown(int value, Function(int?) onChanged) {
    return DropdownButton<int>(
      value: value,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 0xFF2196F3, child: Text('Blau')),
        DropdownMenuItem(value: 0xFF6750A4, child: Text('Lila')),
        DropdownMenuItem(value: 0xFF4CAF50, child: Text('Grün')),
        DropdownMenuItem(value: 0xFFF44336, child: Text('Rot')),
        DropdownMenuItem(value: 0xFFFF9800, child: Text('Orange')),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildAiLevelDropdown(String value, AppStrings s, Function(String?) onChanged) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      items: [
        DropdownMenuItem(value: 'A1', child: Text(s.aiLevelA1)),
        DropdownMenuItem(value: 'A2', child: Text(s.aiLevelA2)),
        DropdownMenuItem(value: 'B1', child: Text(s.aiLevelB1)),
        DropdownMenuItem(value: 'B2', child: Text(s.aiLevelB2)),
        DropdownMenuItem(value: 'C1', child: Text(s.aiLevelC1)),
      ],
      onChanged: onChanged,
    );
  }
}
