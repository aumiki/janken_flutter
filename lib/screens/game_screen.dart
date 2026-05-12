import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hp_bar_widget.dart';
import '../widgets/trivia_card.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // ✅ FIX: simpan roomCode di variable yang di-set sebelum socket setup
  String _roomCode = '';
  String? _myId;

  PlayerState _p1 = PlayerState(id: '', username: '');
  PlayerState _p2 = PlayerState(id: '', username: '');
  bool? _isP1;

  GamePhase _phase = GamePhase.waiting;
  int _round = 0;
  int _timer = 5;
  Timer? _timerTick;

  GameMove? _myMove;
  bool _opponentPicked = false;
  String? _lockedMove;
  String? _spyHint;
  String? _opponentExposed;

  RoundResultData? _roundResult;
  GameOverData? _gameOver;
  TriviaState? _trivia;
  Timer? _triviaTimer;

  List<GameEffect> _effects = [];

  bool _socketSetup = false;

  @override
  void initState() {
    super.initState();
    _myId = AuthService.currentUser?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ FIX: ambil args dan setup socket di sini, bukan di initState,
    // sehingga _roomCode sudah terisi saat event handler terdaftar
    if (!_socketSetup) {
      _socketSetup = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _roomCode = args['room'] ?? '';
        final gs = args['gs'] as String?;
        if (gs != null && gs.isNotEmpty) {
          try {
            final state = jsonDecode(utf8.decode(base64Decode(gs)));
            _applyStateFromJson(state);
          } catch (_) {}
        }
      }
      _setupSocket();
    }
  }

  void _applyStateFromJson(Map state) {
    final p1 = PlayerState.fromJson(state['p1'] ?? {});
    final p2Json = state['p2'];
    final p2 = p2Json != null ? PlayerState.fromJson(p2Json) : _p2;
    if (mounted) {
      setState(() {
        _p1 = p1;
        _p2 = p2;
      });
    }
    _determineIsP1(p1.id);
  }

  void _determineIsP1(String p1Id) {
    if (_myId == null || _isP1 != null) return;
    if (mounted) setState(() => _isP1 = _myId == p1Id);
  }

  void _setupSocket() {
    // Pastikan socket sudah connect
    SocketService.connect();

    SocketService.off('game:player_joined');
    SocketService.on('game:player_joined', (data) {
      if (data['state'] != null) _applyStateFromJson(data['state']);
    });

    SocketService.off('game:joined');
    SocketService.on('game:joined', (data) {
      if (data['state'] != null) _applyStateFromJson(data['state']);
    });

    SocketService.off('game:ranked_match_found');
    SocketService.on('game:ranked_match_found', (data) {
      if (data['state'] != null) _applyStateFromJson(data['state']);
    });

    SocketService.off('game:challenge_accepted');
    SocketService.on('game:challenge_accepted', (data) {
      if (data['state'] != null) _applyStateFromJson(data['state']);
    });

    // ✅ FIX: handle reconnect — server kirim ulang state terkini
    SocketService.off('game:reconnected');
    SocketService.on('game:reconnected', (data) {
      if (data['state'] != null) {
        final state = data['state'];
        _determineIsP1(state['p1']?['id'] ?? '');
        _applyStateFromJson(state);
      }
    });

    SocketService.off('game:round_start');
    SocketService.on('game:round_start', (data) {
      _timerTick?.cancel();
      final t = data['timer'] as int? ?? 5;
      // ✅ FIX: lockedMove dari server (buff lock_random)
      final lockedMove = data['lockedMove'] as String?;
      if (mounted) {
        setState(() {
          _phase = GamePhase.picking;
          _round = data['round'] ?? _round + 1;
          _timer = t;
          _myMove =
              lockedMove != null ? GameMoveExt.fromString(lockedMove) : null;
          _opponentPicked = false;
          _lockedMove = lockedMove;
          _spyHint = null;
          _opponentExposed = null;
          _roundResult = null;
          _trivia = null;
          _p1 = _p1.copyWith(
              hp: data['p1HP'] ?? _p1.hp,
              buffs: List<String>.from(data['p1Buffs'] ?? []));
          _p2 = _p2.copyWith(
              hp: data['p2HP'] ?? _p2.hp,
              buffs: List<String>.from(data['p2Buffs'] ?? []));
        });
      }
      int countdown = t;
      _timerTick = Timer.periodic(const Duration(seconds: 1), (timer) {
        countdown--;
        if (mounted) setState(() => _timer = countdown.clamp(0, 99));
        if (countdown <= 0) timer.cancel();
      });
    });

    SocketService.off('game:spy_reveal');
    SocketService.on('game:spy_reveal', (data) {
      if (mounted) setState(() => _spyHint = data['notPickedMove']);
    });

    SocketService.off('game:opponent_exposed');
    SocketService.on('game:opponent_exposed', (data) {
      if (mounted) setState(() => _opponentExposed = data['move']);
    });

    SocketService.off('game:move_locked');
    SocketService.on('game:move_locked', (data) {
      final lm = data['lockedMove'] as String?;
      if (mounted) {
        setState(() {
          _lockedMove = lm;
          // Tampilkan move yang di-lock seolah sudah dipilih
          if (lm != null) _myMove = GameMoveExt.fromString(lm);
        });
      }
    });

    SocketService.off('game:opponent_picked');
    SocketService.on('game:opponent_picked', (_) {
      if (mounted) setState(() => _opponentPicked = true);
    });

    SocketService.off('game:round_result');
    SocketService.on('game:round_result', (data) {
      _timerTick?.cancel();
      final result = RoundResultData.fromJson(data);
      if (mounted) {
        setState(() {
          _phase = GamePhase.reveal;
          _roundResult = result;
          _p1 = _p1.copyWith(hp: result.p1HP);
          _p2 = _p2.copyWith(hp: result.p2HP);
        });
      }
    });

    SocketService.off('game:trivia_start');
    SocketService.on('game:trivia_start', (data) {
      _triviaTimer?.cancel();
      final timeLimit = data['timeLimit'] as int? ?? 15;
      final trivia = TriviaState(
        question: data['question'] ?? '',
        options: List<String>.from(data['options'] ?? []),
        triviaTimer: timeLimit,
      );
      if (mounted)
        setState(() {
          _phase = GamePhase.trivia;
          _trivia = trivia;
        });
      int t = timeLimit;
      _triviaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        t--;
        if (mounted) setState(() => _trivia?.triviaTimer = t.clamp(0, 99));
        if (t <= 0) timer.cancel();
      });
    });

    SocketService.off('game:trivia_self_answered');
    SocketService.on('game:trivia_self_answered', (data) {
      if (mounted) {
        setState(() {
          _trivia?.answered = true;
          _trivia?.correct = data['correct'] ?? false;
          _trivia?.correctAnswer = data['correctAnswer'];
        });
      }
    });

    SocketService.off('game:effect_received');
    SocketService.on('game:effect_received', (data) {
      _showEffect(data['effect'] ?? {});
    });

    SocketService.off('game:trivia_resolved');
    SocketService.on('game:trivia_resolved', (data) {
      _triviaTimer?.cancel();
      if (mounted) {
        setState(() {
          _trivia?.resolved = true;
          _phase = GamePhase.reveal;
          _p1 = _p1.copyWith(hp: data['p1HP'] ?? _p1.hp);
          _p2 = _p2.copyWith(hp: data['p2HP'] ?? _p2.hp);
        });
      }
    });

    SocketService.off('game:over');
    SocketService.on('game:over', (data) {
      _timerTick?.cancel();
      _triviaTimer?.cancel();
      if (mounted) {
        setState(() {
          _phase = GamePhase.gameover;
          _gameOver = GameOverData.fromJson(data);
        });
      }
    });

    SocketService.off('game:player_disconnected');
    SocketService.on('game:player_disconnected', (data) {
      _showEffect({
        'id': 'dc',
        'name': '❌ ${data['username']} keluar',
        'type': 'debuff'
      });
    });
  }

  void _showEffect(Map effect) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final eff = GameEffect(
        id: id, name: effect['name'] ?? '', type: effect['type'] ?? 'buff');
    if (mounted) setState(() => _effects = [..._effects, eff]);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _effects.removeWhere((e) => e.id == id));
    });
  }

  void _sendMove(GameMove move) {
    if (_phase != GamePhase.picking || _myMove != null || _lockedMove != null)
      return;
    setState(() => _myMove = move);
    // ✅ FIX: _roomCode sudah terisi karena di-set di didChangeDependencies
    SocketService.emit('game:move', {'roomCode': _roomCode, 'move': move.name});
  }

  void _answerTrivia(String answer) {
    if (_trivia?.myAnswer != null) return;
    setState(() => _trivia?.myAnswer = answer);
    SocketService.emit(
        'game:trivia_answer', {'roomCode': _roomCode, 'answer': answer});
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    _triviaTimer?.cancel();
    for (final ev in [
      'game:player_joined',
      'game:joined',
      'game:challenge_accepted',
      'game:ranked_match_found',
      'game:reconnected',
      'game:round_start',
      'game:move_locked',
      'game:opponent_picked',
      'game:round_result',
      'game:trivia_start',
      'game:trivia_self_answered',
      'game:effect_received',
      'game:trivia_resolved',
      'game:over',
      'game:player_disconnected',
      'game:spy_reveal',
      'game:opponent_exposed',
    ]) {
      SocketService.off(ev);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isP1 = _isP1 ?? (_myId == _p1.id);
    final me = isP1 ? _p1 : _p2;
    final opponent = isP1 ? _p2 : _p1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildNavBar(isP1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    children: [
                      _buildHPSection(me, opponent),
                      const SizedBox(height: 20),
                      if (_phase == GamePhase.waiting && _round == 0)
                        _buildWaiting()
                      else if (_phase == GamePhase.picking ||
                          _phase == GamePhase.reveal) ...[
                        _buildTimerAndArena(isP1, me, opponent),
                        const SizedBox(height: 16),
                        if (_phase == GamePhase.picking) _buildMovePicker(),
                        if (_phase == GamePhase.reveal && _roundResult != null)
                          _buildRoundResult(isP1),
                      ] else if (_phase == GamePhase.trivia && _trivia != null)
                        TriviaCard(trivia: _trivia!, onAnswer: _answerTrivia)
                      else if (_phase == GamePhase.gameover &&
                          _gameOver != null)
                        _buildGameOver(isP1),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Floating effects
          Positioned(
            top: 100,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _effects.map((eff) => _buildEffect(eff)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(bool isP1) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('JANKEN',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.primary)),
                Text(
                  'RONDE $_round${_round > 0 && _round % 3 == 0 ? " • 🎯 TRIVIA BERIKUTNYA" : ""}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                _isP1 == null
                    ? '...'
                    : isP1
                        ? '● P1'
                        : '● P2',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        _isP1 == null ? AppColors.textMuted : AppColors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHPSection(PlayerState me, PlayerState opponent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(me.username.isEmpty ? 'Kamu' : me.username,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hp1)),
              const Text('vs',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              Text(opponent.username.isEmpty ? 'Lawan' : opponent.username,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hp2)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: HpBarWidget(
                    playerName: me.username,
                    hp: me.hp,
                    buffs: me.buffs,
                    isMe: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HpBarWidget(
                    playerName: opponent.username,
                    hp: opponent.hp,
                    buffs: opponent.buffs,
                    isMe: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Text('⏳', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Menunggu permainan dimulai...',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerAndArena(bool isP1, PlayerState me, PlayerState opponent) {
    final timerColor = _timer <= 2 ? AppColors.coral : AppColors.primary;

    return Column(
      children: [
        if (_phase == GamePhase.picking)
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: timerColor, width: 4),
                boxShadow: _timer <= 2
                    ? [
                        BoxShadow(
                            color: AppColors.coral.withOpacity(0.25),
                            blurRadius: 16,
                            spreadRadius: 4)
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${_timer.clamp(0, 99)}',
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: timerColor,
                          height: 1)),
                  const Text('DETIK',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildPlayerSide(isMe: true, isP1: isP1)),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: const Center(
                child: Text('VS',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ),
            Expanded(child: _buildPlayerSide(isMe: false, isP1: isP1)),
          ],
        ),
        if (_spyHint != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              '👁️ Spy: Lawan TIDAK memilih ${GameMoveExt.fromString(_spyHint)?.label ?? _spyHint}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32)),
            ),
          ),
        if (_opponentExposed != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              '🔍 Lawan memilih: ${GameMoveExt.fromString(_opponentExposed)?.label ?? _opponentExposed}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE65100)),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerSide({required bool isMe, required bool isP1}) {
    String icon = '?';
    if (_phase == GamePhase.reveal && _roundResult != null) {
      final moveKey = isMe
          ? (isP1 ? _roundResult!.p1Move : _roundResult!.p2Move)
          : (isP1 ? _roundResult!.p2Move : _roundResult!.p1Move);
      icon = GameMoveExt.fromString(moveKey)?.icon ?? '?';
    } else if (isMe) {
      icon = _myMove?.icon ?? (_lockedMove != null ? '🔒' : '?');
    } else {
      icon = _opponentExposed != null
          ? (GameMoveExt.fromString(_opponentExposed)?.icon ?? '?')
          : (_opponentPicked ? '✅' : '?');
    }

    return Column(
      children: [
        Text(
          isMe ? 'KAMU' : 'LAWAN',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: isMe ? AppColors.hp1 : AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? const Color(0xFFF4A090) : const Color(0xFFF5EFEF),
            border: Border.all(
                color: isMe ? AppColors.primary : const Color(0xFFE8D8D8),
                width: isMe ? 3 : 2),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 42)),
          ),
        ),
        if (isMe && _lockedMove != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('🔒 Terkunci',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.coral,
                    fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _buildMovePicker() {
    return Column(
      children: [
        const Text('PILIH SENJATAMU',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 2)),
        const SizedBox(height: 14),
        Row(
          children: GameMove.values.map((move) {
            final isLocked = _lockedMove != null && _lockedMove != move.name;
            final isSelected = _myMove == move ||
                (_lockedMove != null && _lockedMove == move.name);
            final isDisabled = _myMove != null || _lockedMove != null;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    if (!isDisabled && !isLocked) _sendMove(move);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2.5 : 2),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.15),
                                  blurRadius: 16)
                            ]
                          : [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10)
                            ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
                    child: Opacity(
                      opacity: isLocked ? 0.3 : 1.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(move.emoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 8),
                          Text(
                            move.label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                letterSpacing: 0.5),
                          ),
                          if (isLocked)
                            const Text('🔒', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoundResult(bool isP1) {
    if (_roundResult == null) return const SizedBox();
    String myResult;
    if (_roundResult!.result == 'DRAW') {
      myResult = 'DRAW';
    } else if (isP1) {
      myResult = _roundResult!.result == 'P1_WIN' ? 'WIN' : 'LOSE';
    } else {
      myResult = _roundResult!.result == 'P2_WIN' ? 'WIN' : 'LOSE';
    }

    final dmg = isP1 ? _roundResult!.damageToPl1 : _roundResult!.damageToPl2;
    final dmgToOpp =
        isP1 ? _roundResult!.damageToPl2 : _roundResult!.damageToPl1;

    return Column(
      children: [
        Text(
          myResult == 'WIN'
              ? '🎉 MENANG!'
              : myResult == 'LOSE'
                  ? '💔 KALAH!'
                  : '🤝 SERI!',
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: myResult == 'WIN'
                  ? AppColors.green
                  : myResult == 'LOSE'
                      ? AppColors.coral
                      : AppColors.textSecondary),
        ),
        if (_roundResult!.result != 'DRAW') ...[
          const SizedBox(height: 6),
          Text(
            myResult == 'WIN'
                ? 'Damage ke lawan: -$dmgToOpp HP'
                : 'Kamu kena: -$dmg HP',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildGameOver(bool isP1) {
    if (_gameOver == null) return const SizedBox();
    final iWon = _gameOver!.winnerId == _myId;
    final delta = isP1 ? _gameOver!.p1Delta : _gameOver!.p2Delta;

    return Column(
      children: [
        Text(iWon ? '🏆' : '💀', style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        Text(
          iWon ? 'MENANG!' : 'KALAH!',
          style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: iWon ? AppColors.green : AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Pemenang: ${_gameOver!.winnerName} • Total ${_gameOver!.totalRounds} ronde',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        if (delta != 0) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('PERUBAHAN POIN RANKED',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  '${delta > 0 ? "+" : ""}$delta PTS',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: delta > 0 ? AppColors.green : AppColors.coral),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/lobby'),
              child: const Text('Kembali ke Lobby'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/leaderboard'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: const Text('Lihat Ranking',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEffect(GameEffect eff) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: eff.type == 'buff'
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFDE8E8),
          border: Border.all(
              color: eff.type == 'buff' ? AppColors.green : AppColors.coral,
              width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          eff.name,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: eff.type == 'buff'
                  ? const Color(0xFF2E7D32)
                  : AppColors.primary),
        ),
      ),
    );
  }
}
