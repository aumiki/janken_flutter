import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/game_state.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/challenge_dialog.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  UserModel? _user;
  List<UserModel> _players = [];
  bool _loading = true;
  String? _challenging;
  String _notif = '';
  ChallengeData? _pendingChallenge;

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    _fetchLeaderboard();
    _refreshMyPoints();
    _setupSocket();

    // Handle challenge received from notification tap (app was in background)
    NotificationService.onChallengeReceived = (data) {
      if (mounted) {
        setState(() => _pendingChallenge = data);
        _showChallengeDialog(data);
      }
    };
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _loading = true);
    final players = await ApiService.fetchLeaderboard();
    if (mounted)
      setState(() {
        _players = players;
        _loading = false;
      });
  }

  Future<void> _refreshMyPoints() async {
    final user = await AuthService.fetchProfile();
    if (user != null && mounted) setState(() => _user = user);
  }

  void _setupSocket() {
    final socket = SocketService.socket;
    if (socket == null) return;

    socket.on('user:online', (_) => _fetchLeaderboard());
    socket.on('user:offline', (_) => _fetchLeaderboard());

    socket.on('game:over', (_) {
      Future.delayed(const Duration(seconds: 1), () {
        _fetchLeaderboard();
        _refreshMyPoints();
      });
    });

    // ── Challenge received via Socket.IO ──
    // This fires when the app is in FOREGROUND
    // For background/killed state, FCM handles it via NotificationService
    socket.on('game:challenge_received', (data) async {
      print('[CHALLENGE RECEIVED][LEADERBOARD]');
      print(data);
      final challenge = ChallengeData.fromJson(data);

      if (mounted) {
        setState(() => _pendingChallenge = challenge);
        // Show in-app dialog
        _showChallengeDialog(challenge);
        // Also fire a system push notification (visible even if screen is off)
        await NotificationService.notifyChallenge(challenge);
      }
    });

    socket.on('game:challenge_accepted', (data) {
      final stateB64 = _encodeState(data['state']);
      if (mounted) {
        Navigator.pushNamed(context, '/game',
            arguments: {'room': data['roomCode'], 'gs': stateB64});
      }
    });

    socket.on('game:ranked_match_found', (data) {
      final stateB64 = _encodeState(data['state']);
      if (mounted) {
        Navigator.pushNamed(context, '/game',
            arguments: {'room': data['roomCode'], 'gs': stateB64});
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

  void _showChallengeDialog(ChallengeData challenge) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChallengeDialog(
        challenge: challenge,
        onAccept: () {
          Navigator.pop(context);
          SocketService.emit('game:accept_challenge',
              {'challengerId': challenge.challengerId});
          setState(() => _pendingChallenge = null);
        },
        onDecline: () {
          Navigator.pop(context);
          setState(() => _pendingChallenge = null);
        },
      ),
    );
  }

  void _challengePlayer(String targetId) {
    setState(() {
      _challenging = targetId;
      _notif = '⚔️ Challenge terkirim! Menunggu respons...';
    });
    SocketService.emit('game:challenge_player', {'targetUserId': targetId});
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted)
        setState(() {
          _challenging = null;
          _notif = '';
        });
    });
  }

  @override
  void dispose() {
    SocketService.off('user:online');
    SocketService.off('user:offline');
    SocketService.off('game:over');
    SocketService.off('game:challenge_received');
    SocketService.off('game:challenge_accepted');
    SocketService.off('game:ranked_match_found');
    NotificationService.onChallengeReceived = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myRank = _players.indexWhere((p) => p.id == _user?.id);
    final myData = myRank >= 0 ? _players[myRank] : null;
    final displayUser = myData != null
        ? _user?.copyWith(
            rankedPoints: myData.rankedPoints,
            wins: myData.wins,
            losses: myData.losses,
          )
        : _user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildNavBar(),
          if (_notif.isNotEmpty) _buildNotifBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchLeaderboard,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  const Text(
                    '📊 RANKED LEADERBOARD',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(40),
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ))
                  else if (_players.isEmpty)
                    _buildEmptyState()
                  else
                    ..._players
                        .asMap()
                        .entries
                        .map((e) => _buildPlayerRow(e.key, e.value)),
                  const SizedBox(height: 20),
                  // My rank card
                  if (_user != null && myRank >= 0)
                    _buildMyRankCard(myRank + 1, displayUser!),
                ],
              ),
            ),
          ),
          JankenBottomNav(
            currentIndex: 1,
            onTap: (i) {
              if (i == 0) Navigator.pushReplacementNamed(context, '/lobby');
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('JANKEN',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.primary)),
            GestureDetector(
              onTap: _fetchLeaderboard,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('🔄 Refresh',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFE8F5E9),
      child: Text(_notif,
          style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const Column(
        children: [
          Text('👥', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('Belum ada pemain terdaftar',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Text('Daftar akun untuk muncul di sini!',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(int idx, UserModel p) {
    final rank = idx + 1;
    final isMe = p.id == _user?.id;
    const medals = ['🥇', '🥈', '🥉'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFDE8E8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: const Color(0xFFF0E8E8)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              rank <= 3 ? medals[rank - 1] : '#$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: rank <= 3 ? 18 : 13,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          _Avatar(avatar: p.avatar, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(p.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    if (isMe)
                      const Text(' (Kamu)',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
                Text('${p.wins}W / ${p.losses}L',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Row(
            children: [
              // Challenge button (only for online players who are not me)
              if (p.isOnline && !isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _challenging == null
                        ? () => _challengePlayer(p.id)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _challenging == p.id
                            ? Colors.grey
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _challenging == p.id ? '⏳' : '⚔️',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              if (p.isOnline)
                const Text('●',
                    style: TextStyle(fontSize: 7, color: AppColors.green)),
              const SizedBox(width: 6),
              Text('${p.rankedPoints}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankCard(int rank, UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _Avatar(avatar: user.avatar, size: 44, bg: const Color(0xFFF4A090)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RANKMU SAAT INI',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white60,
                        letterSpacing: 1.5)),
                Text('#$rank',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('POIN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white60,
                      letterSpacing: 1)),
              Text('${user.rankedPoints}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatar;
  final double size;
  final Color? bg;

  const _Avatar({this.avatar, required this.size, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: bg ?? AppColors.rankBg, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: avatar != null
          ? Image.network(avatar!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                  child: Text('🧑', style: TextStyle(fontSize: 16))))
          : const Center(child: Text('🧑', style: TextStyle(fontSize: 16))),
    );
  }
}
