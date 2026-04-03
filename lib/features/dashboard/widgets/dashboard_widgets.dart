import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/vocab_repository.dart';
import '../../../core/models/vocab.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/app_strings.dart';
import '../../profile/ai_chat_screen.dart';
import '../../../main.dart';

class RandomVocabWidget extends ConsumerStatefulWidget {
  const RandomVocabWidget({super.key});

  @override
  ConsumerState<RandomVocabWidget> createState() => _RandomVocabWidgetState();
}

class _RandomVocabWidgetState extends ConsumerState<RandomVocabWidget> with SingleTickerProviderStateMixin {
  Vocab? _vocab;
  bool _revealed = false;
  bool _loading = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _loadRandom();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadRandom() async {
    final vocabRepo = ref.read(vocabRepositoryProvider);
    final all = await vocabRepo.getAllVocab();
    if (all.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _vocab = all[Random().nextInt(all.length)];
        _revealed = false;
        _loading = false;
      });
      _animController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final s = AppStrings(settings.appLanguage);
    
    // Minimalist Dark Styling
    final cardColor = const Color(0xFF1A1A1A);
    final borderColor = Colors.white.withOpacity(0.08);

    if (_loading) return _buildContainer(child: const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())), color: cardColor, border: borderColor);
    if (_vocab == null) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () {
        if (_revealed) {
          _loadRandom();
        } else {
          setState(() => _revealed = true);
        }
      },
      child: FadeTransition(
        opacity: _animController,
        child: _buildContainer(
          color: cardColor,
          border: borderColor,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(s.randomVocab.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                   const Icon(Icons.casino_outlined, color: Colors.white24, size: 14),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _vocab!.kanji ?? _vocab!.kana,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              if (_vocab!.kanji != null) ...[
                const SizedBox(height: 4),
                Text(_vocab!.kana, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
              const SizedBox(height: 16),
              AnimatedCrossFade(
                firstChild: Text(s.tapToReveal, style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                secondChild: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _vocab!.localizedTranslation(settings.contentLanguage),
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                crossFadeState: _revealed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContainer({required Widget child, required Color color, required Color border, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class AIAssistantTeaserSmall extends StatelessWidget {
  const AIAssistantTeaserSmall({super.key});

  @override
  Widget build(BuildContext context) {
    final cardColor = const Color(0xFF1A1A1A);
    final borderColor = Colors.white.withOpacity(0.08);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 20),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sensei Chat', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
                  Text('Frag mich was zu Japanisch!', style: TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}
