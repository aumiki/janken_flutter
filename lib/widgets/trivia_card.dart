import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';

class TriviaCard extends StatelessWidget {
  final TriviaState trivia;
  final Function(String) onAnswer;

  const TriviaCard({
    super.key,
    required this.trivia,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final letters = ['A', 'B', 'C', 'D'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🎯 TRIVIA TIME!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
              Text(
                '${trivia.triviaTimer}s',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: (trivia.triviaTimer) <= 5
                      ? AppColors.coral
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question
          Text(
            trivia.question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...List.generate(trivia.options.length, (i) {
            final opt = trivia.options[i];
            final isSelected = trivia.myAnswer == opt;
            final isCorrect = trivia.correctAnswer == opt;
            final isWrong = trivia.answered && isSelected && !isCorrect;

            Color bg = Colors.white;
            Color borderColor = AppColors.border;
            Color textColor = AppColors.textPrimary;

            if (isSelected && !trivia.answered) {
              bg = const Color(0xFFF5EDED);
              borderColor = AppColors.primary;
            }
            if (trivia.answered && isCorrect) {
              bg = const Color(0xFFE8F5E9);
              borderColor = AppColors.green;
              textColor = const Color(0xFF2E7D32);
            }
            if (isWrong) {
              bg = const Color(0xFFFDE8E8);
              borderColor = AppColors.coral;
              textColor = const Color(0xFFC62828);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  if (!trivia.answered && trivia.myAnswer == null) {
                    onAnswer(opt);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text(
                        '${letters[i < letters.length ? i : 0]}. ',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Result banner
          if (trivia.answered) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: trivia.correct == true
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trivia.correct == true
                    ? '✅ Benar! Kamu dapat buff!'
                    : '❌ Salah! Kamu kena debuff!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: trivia.correct == true
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
              ),
            ),
          ],

          if (trivia.resolved) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ronde berikutnya dimulai sebentar lagi...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
