import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/deck.dart';
import '../../../core/models/vocab.dart';
import '../../../core/services/settings_service.dart';
import '../../study/deck_study_screen.dart';
import '../deck_listen_screen.dart';
import '../vocab_detail_screen.dart';
import '../simple_flashcard_screen.dart';
import '../srs_flashcard_screen.dart';
import '../../../core/services/deck_session_service.dart';

class DeckStudyMethodBottomSheet extends ConsumerWidget {
  final Deck deck;
  final List<Vocab> vocabList;
  /// The parent navigator context (not the bottom sheet context)
  final BuildContext parentContext;

  const DeckStudyMethodBottomSheet({
    super.key,
    required this.deck,
    required this.vocabList,
    required this.parentContext,
  });

  static Future<void> show(BuildContext context, Deck deck, List<Vocab> vocabList) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DeckStudyMethodBottomSheet(deck: deck, vocabList: vocabList, parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                deck.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${vocabList.length} Vokabeln',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // ── Karteikarten (asks SRS or Normal) ──
            _StudyTile(
              icon: Icons.style,
              color: Colors.purple,
              title: 'Karteikarten',
              subtitle: 'Karten durchgehen & umdrehen',
              onTap: () {
                Navigator.pop(context); // close this bottom sheet
                _showFlashcardModeChoice();
              },
            ),

            // ── Gemischte Übungen ──
            _buildMethodTile(
              context, ref,
              method: 'all',
              icon: Icons.quiz,
              color: Colors.blue,
              title: 'Gemischte Übungen',
              subtitle: 'Multiple Choice, Tippen, Hören & Sprechen',
              settings: settings,
            ),

            // ── Übersetzen (Deutsch → Japanisch) ──
            _buildMethodTile(
              context, ref,
              method: 'typing_writing',
              icon: Icons.translate,
              color: Colors.teal,
              title: 'Übersetzen (Deutsch → Japanisch)',
              subtitle: 'Deutsche Bedeutung sehen, japanisch eintippen',
              settings: settings,
            ),

            // ── Lesen (Japanisch → Deutsch) ──
            _buildMethodTile(
              context, ref,
              method: 'reading_to_translation',
              icon: Icons.menu_book,
              color: Colors.orange,
              title: 'Lesen (Japanisch → Deutsch)',
              subtitle: 'Japanisches Wort sehen, Bedeutung eintippen',
              settings: settings,
            ),

            // ── Vorlesen ──
            _StudyTile(
              icon: Icons.headset,
              color: Colors.indigo,
              title: 'Vorlesen',
              subtitle: 'Vokabeln und Übersetzungen anhören',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(builder: (_) => DeckListenScreen(deck: deck)),
                );
              },
            ),

            const Divider(height: 1),

            // ── Vokabelliste ──
            _StudyTile(
              icon: Icons.list_alt,
              color: Colors.grey,
              title: 'Vokabelliste',
              subtitle: 'Alle Vokabeln anzeigen & bearbeiten',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(builder: (_) => VocabDetailScreen(deck: deck)),
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFlashcardModeChoice() {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Karteikarten-Modus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _StudyTile(
              icon: Icons.swipe,
              color: Colors.deepPurple,
              title: 'SRS (Spaced Repetition)',
              subtitle: 'Wischen: links = nicht gewusst, rechts = gewusst',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(builder: (_) => SrsFlashcardScreen(deck: deck, vocabList: vocabList)),
                );
              },
            ),
            _StudyTile(
              icon: Icons.style,
              color: Colors.purple,
              title: 'Normal durchgehen',
              subtitle: 'Frei vor- und zurückblättern',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(builder: (_) => SimpleFlashcardScreen(deck: deck, vocabList: vocabList)),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTile(
    BuildContext context,
    WidgetRef ref, {
    required String method,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required AppSettings settings,
  }) {
    final sessionService = ref.watch(deckSessionServiceProvider);

    return FutureBuilder<DeckSession?>(
      future: sessionService.getLatestSession(deck.id!, method),
      builder: (context, snapshot) {
        final session = snapshot.data;
        final double progress = session?.progressPercent ?? 0.0;
        final bool isCompleted = session?.isCompleted ?? false;

        return _StudyTile(
          icon: icon,
          color: isCompleted ? Colors.green : color,
          title: title,
          subtitle: subtitle,
          trailing: progress > 0 && !isCompleted
              ? SizedBox(
                  width: 40, height: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey.withAlpha(50),
                  ),
                )
              : isCompleted
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
          onTap: () {
            Navigator.pop(context);
            DeckStudyScreen.start(
              parentContext, deck, vocabList,
              method: method,
              speakingEnabled: settings.speakingExercisesEnabled,
              contentLang: settings.contentLanguage,
            );
          },
        );
      },
    );
  }
}

class _StudyTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _StudyTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}
