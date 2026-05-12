import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../models/game_state.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/challenge_dialog.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  UserModel? _user;
  List<UserModel> _topPlayers = [];
  bool _showJoin = false;
  ChallengeData? _challenge;
  String _notif = '';
  final _joinCtrl = TextEditingController();
  bool _socketInitialized = false; // ✅ TAMBAH: track socket readiness

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    _loadData();
    _setupSocket();
  }

  void _loadData() async {
    final players = await ApiService.fetchLeaderboard();
    if (mounted) {
      setState(() => _topPlayers = players.take(3).toList());
    }
  }

  void _setupSocket() {
    final socket = SocketService.connect();

    // ✅ FIX: Set _socketInitialized saat connect
    socket.on('connect', (_) {
      if (mounted) setState(() => _socketInitialized = true);
      print('[Socket] Connected to lobby');
    });

    socket.on('game:room_created', (data) {
      final stateB64 = _encodeState(data['state']);
      final roomCode = data['roomCode'];
      Navigator.pushNamed(context, '/waiting',
          arguments: {'code': roomCode, 'mode': 'casual', 'gs': stateB64});
    });

    socket.on('game:joined', (data) {
      final stateB64 = _encodeState(data['state']);
      Navigator.pushNamed(context, '/game',
          arguments: {'room': data['roomCode'], 'gs': stateB64});
    });

    socket.on('game:ranked_match_found', (data) {
      final stateB64 = _encodeState(data['state']);
      Navigator.pushNamed(context, '/game',
          arguments: {'room': data['roomCode'], 'gs': stateB64});
    });

    socket.on('game:challenge_accepted', (data) {
      final stateB64 = _encodeState(data['state']);
      Navigator.pushNamed(context, '/game',
          arguments: {'room': data['roomCode'], 'gs': stateB64});
    });

    socket.on('game:challenge_received', (data) {
      if (mounted) {
        setState(() => _challenge = ChallengeData.fromJson(data));
        _showChallengeDialog();
      }
    });

    socket.on('game:queued', (_) {
      Navigator.pushNamed(context, '/waiting',
          arguments: {'code': 'RANKED', 'mode': 'ranked'});
    });

    socket.on('error', (e) {
      if (mounted) {
        final msg = e is Map ? (e['message'] ?? 'Terjadi kesalahan') : e.toString();
        setState(() => _notif = msg);
        // ✅ FIX: Hapus leave_room + forfeit emit
        Future.delayed(const Duration(seconds: 3),
            () => mounted ? setState(() => _notif = '') : null);
      }
    });
  }

  String _encodeState(dynamic state) {
    if (state == null) return '';
    try {
      return base64Encode(utf8.encode(jsonEncode(state)));
    } catch (_) {
      return '';
    }
  }

  void _showChallengeDialog() {
    if (_challenge == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChallengeDialog(
        challenge: _challenge!,
        onAccept: () {
          Navigator.pop(context);
          SocketService.emit('game:accept_challenge',
              {'challengerId': _challenge!.challengerId});
          setState(() => _challenge = null);
        },
        onDecline: () {
          Navigator.pop(context);
          setState(() => _challenge = null);
        },
      ),
    );
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    SocketService.off('game:room_created');
    SocketService.off('game:joined');
    SocketService.off('game:ranked_match_found');
    SocketService.off('game:challenge_accepted');
    SocketService.off('game:challenge_received');
    SocketService.off('game:queued');
    SocketService.off('error');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildNavBar(),
          if (_notif.isNotEmpty) _buildNotif(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _buildRankedBanner(),
                const SizedBox(height: 20),
                _buildCasualButtons(),
                if (_showJoin) ...[
                  const SizedBox(height: 16),
                  _buildJoinInput(),
                ],
                const SizedBox(height: 28),
                _buildTopLegends(),
              ],
            ),
          ),
          JankenBottomNav(
            currentIndex: 0,
            onTap: (i) {
              if (i == 1)
                Navigator.pushReplacementNamed(context, '/leaderboard');
              if (i == 2) Navigator.pushReplacementNamed(context, '/profile');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFE8737A),
                  borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: _user?.avatar != null
                  ? Image.network(_user!.avatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text('🐼', style: TextStyle(fontSize: 20))))
                  : const Center(
                      child: Text('🐼', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('JANKEN',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primary)),
                // ✅ FIX: Tampilkan status socket connecting
                Text(
                  '● ${_user?.rankedPoints ?? 1000} PTS${!_socketInitialized ? " (🔌 Connecting...)" : ""}',
                  style: TextStyle(
                      fontSize: 11,
                      color: _socketInitialized ? AppColors.green : Colors.orange,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Spacer(),
            const Text('🔔', style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotif() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFFDE8E8),
      child: Row(
        children: [
          Expanded(
            child: Text(_notif,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          // ✅ FIX: Hapus leave_room + forfeit, cuma close notif
          GestureDetector(
            onTap: () => setState(() => _notif = ''),
            child: const Text('✕',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedBanner() {
    // ✅ FIX: Tambah guard untuk socket readiness
    return GestureDetector(
      onTap: _socketInitialized
          ? () => SocketService.emit('game:create_room', {'mode': 'RANKED'})
          : () => setState(() => _notif = 'Socket sedang terhubung...'),
      child: Opacity(
        opacity: _socketInitialized ? 1.0 : 0.6,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(28),
          child: Stack(
            children: [
              const Positioned(
                right: -20,
                top: -10,
                child: Text('✊',
                    style: TextStyle(fontSize: 120, color: Colors.white10)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'SEASON 1 LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'RANKED MATCH',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Menangkan untuk +1 poin, kalah -1 poin.\nTrivia twists setiap 3 ronde!',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Text(
                      'PLAY RANKED ⚡',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCasualButtons() {
    return Row(
      children: [
        Expanded(
          child: _CasualCard(
            icon: '➕',
            iconBg: const Color(0xFFA8DCE7),
            title: 'BUAT ROOM',
            subtitle: 'Main bareng teman',
            color: AppColors.blue,
            isDisabled: !_socketInitialized, // ✅ FIX: Add guard
            onTap: _socketInitialized
                ? () =>
                    SocketService.emit('game:create_room', {'mode': 'CASUAL'})
                : () => setState(() => _notif = 'Socket sedang terhubung...'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _CasualCard(
            icon: '🔢',
            iconBg: AppColors.green,
            title: 'JOIN CODE',
            subtitle: 'Masukkan kode room',
            color: const Color(0xFF1A6A4A),
            isDisabled: !_socketInitialized, // ✅ FIX: Add guard
            onTap: _socketInitialized
                ? () => setState(() => _showJoin = !_showJoin)
                : () => setState(() => _notif = 'Socket sedang terhubung...'),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinInput() {
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _joinCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              enabled: _socketInitialized, // ✅ FIX: Disable until ready
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))
              ],
              decoration: const InputDecoration(
                hintText: 'Masukkan kode room (6 huruf)',
                counterText: '',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(
                  letterSpacing: 2, fontWeight: FontWeight.w700, fontSize: 15),
              onSubmitted: (_) => _joinRoom(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _socketInitialized ? _joinRoom : null, // ✅ FIX: Guard
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }

  void _joinRoom() {
    final code = _joinCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _notif = 'Kode room harus minimal 4 karakter');
      return;
    }
    SocketService.emit('game:join_room', {'roomCode': code});
  }

  Widget _buildTopLegends() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📊 TOP LEGENDS',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary),
            ),
            GestureDetector(
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/leaderboard'),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._topPlayers.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2))
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Text('#${i + 1}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                _PlayerAvatar(avatar: p.avatar, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      if (p.isOnline)
                        const Text('● ONLINE',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.green,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Text('${p.rankedPoints} pts',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CasualCard extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled; // ✅ FIX: Add disabled state

  const _CasualCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: color)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final String? avatar;
  final double size;

  const _PlayerAvatar({this.avatar, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: AppColors.rankBg, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: avatar != null
          ? Image.network(avatar!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                  child: Text('🧑', style: TextStyle(fontSize: 18))))
          : const Center(child: Text('🧑', style: TextStyle(fontSize: 18))),
    );
  }
}
