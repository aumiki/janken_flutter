import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  String _code = '';
  String _mode = 'casual';
  String? _gsFromArgs; // state P1 dari args (untuk fallback)
  bool _copied = false;
  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
        lowerBound: 0.85,
        upperBound: 1.05)
      ..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      _argsLoaded = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _code = args['code'] ?? '';
        _mode = args['mode'] ?? 'casual';
        _gsFromArgs = args['gs'] as String?;
      }
      _setupSocket();
    }
  }

  void _setupSocket() {
    // ✅ FIX: game:player_joined membawa state terbaru (dengan P2),
    // gunakan state dari server, bukan dari args yang hanya punya P1
    SocketService.off('game:player_joined');
    SocketService.on('game:player_joined', (data) {
      if (!mounted) return;
      final newState = data['state'];
      String gs;
      if (newState != null) {
        // Encode state terbaru dari server (sudah ada P1 + P2)
        try {
          gs = base64Encode(utf8.encode(jsonEncode(newState)));
        } catch (_) {
          gs = _gsFromArgs ?? '';
        }
      } else {
        gs = _gsFromArgs ?? '';
      }
      Navigator.pushReplacementNamed(context, '/game',
          arguments: {'room': _code, 'gs': gs});
    });

    // ✅ FIX: tambah listener ranked_match_found yang sebelumnya hilang
    SocketService.off('game:ranked_match_found');
    SocketService.on('game:ranked_match_found', (data) {
      if (!mounted) return;
      final roomCode = data['roomCode'] ?? _code;
      final newState = data['state'];
      String gs = '';
      if (newState != null) {
        try {
          gs = base64Encode(utf8.encode(jsonEncode(newState)));
        } catch (_) {}
      }
      Navigator.pushReplacementNamed(context, '/game',
          arguments: {'room': roomCode, 'gs': gs});
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    SocketService.off('game:player_joined');
    SocketService.off('game:ranked_match_found');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRanked = _mode == 'ranked';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('JANKEN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (isRanked) SocketService.emit('game:cancel_queue');
            Navigator.pushReplacementNamed(context, '/lobby');
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: const Text('⏳', style: TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 24),
              Text(
                isRanked ? 'Mencari lawan...' : 'Menunggu pemain lain...',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isRanked
                    ? 'Kamu ada di antrian ranked match'
                    : 'Bagikan kode room ke temanmu',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (!isRanked && _code.isNotEmpty) ...[
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: _code));
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2),
                        () => mounted ? setState(() => _copied = false) : null);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 12)
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _code,
                          style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _copied ? '✅ Disalin!' : '📋 Ketuk untuk salin kode',
                          style: TextStyle(
                              fontSize: 12,
                              color: _copied
                                  ? AppColors.green
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              const _Dots(),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  if (isRanked) SocketService.emit('game:cancel_queue');
                  Navigator.pushReplacementNamed(context, '/lobby');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: const Text(
                  'Batalkan',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.3;
            final v = ((t - delay) % 1.0).clamp(0.0, 1.0);
            final scale = 0.5 + (v < 0.5 ? v : 1.0 - v) * 1.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
