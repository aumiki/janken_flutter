import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HpBarWidget extends StatelessWidget {
  final String playerName;
  final int hp;
  final List<String> buffs;
  final bool isMe;

  const HpBarWidget({
    super.key,
    required this.playerName,
    required this.hp,
    this.buffs = const [],
    this.isMe = false,
  });

  String _buffIcon(String buff) {
    const icons = {
      'shield': '🛡️',
      'spy': '👁️',
      'extra_time': '⏱️',
      'double_damage': '⚔️',
      'heal': '💚',
      'time_cut': '⏳',
      'hp_drain': '💀',
      'lock_random': '🔒',
      'half_damage': '🪶',
      'reveal': '🔍',
    };
    return icons[buff] ?? buff;
  }

  @override
  Widget build(BuildContext context) {
    final hpPercent = (hp.clamp(0, 100) / 100.0);
    final barColor = isMe ? AppColors.hp1 : AppColors.hp2;

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
          children: isMe
              ? [
                  Text(
                    '❤️ $hp HP',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (buffs.isNotEmpty)
                    Text(buffs.map(_buffIcon).join(''),
                        style: const TextStyle(fontSize: 12)),
                ]
              : [
                  if (buffs.isNotEmpty)
                    Text(buffs.map(_buffIcon).join(''),
                        style: const TextStyle(fontSize: 12)),
                  Text(
                    '❤️ $hp HP',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: hpPercent,
            minHeight: 10,
            backgroundColor: AppColors.rankBg,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
