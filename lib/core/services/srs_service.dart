import 'dart:math';
import '../models/vocab.dart';

class SRSService {
  /// Calculates the next review date and updated SRS properties based on the SM-2 algorithm.
  /// 
  /// [quality] is a grade from 0 to 5:
  /// 5: perfect response
  /// 4: correct response after a hesitation
  /// 3: correct response recalled with serious difficulty
  /// 2: incorrect response; where the correct one seemed easy to recall
  /// 1: incorrect response; the correct one remembered
  /// 0: complete blackout
  static Vocab calculateNextReview(Vocab vocab, int quality) {
    int repetition = vocab.repetition;
    int interval = vocab.interval;
    double eFactor = vocab.efactor;

    if (quality >= 3) {
      // Correct response
      if (repetition == 0) {
        interval = 1;
      } else if (repetition == 1) {
        interval = 6;
      } else {
        interval = (interval * eFactor).round();
      }
      repetition++;
    } else {
      // Incorrect response
      repetition = 0;
      interval = 1;
    }

    // Update e-factor (Formula: EF' = EF + (0.1 - (5-q)*(0.08+(5-q)*0.02)))
    eFactor = eFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    
    // eFactor cannot be lower than 1.3
    eFactor = max(1.3, eFactor);

    // Calculate due date
    final dueDate = DateTime.now().add(Duration(days: interval)).millisecondsSinceEpoch;

    return vocab.copyWith(
      repetition: repetition,
      interval: interval,
      efactor: eFactor,
      dueDate: dueDate,
    );
  }
}
