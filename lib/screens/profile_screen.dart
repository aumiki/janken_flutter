import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _editing = false;
  bool _saving = false;
  String _msg = '';
  final _usernameCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    _usernameCtrl.text = _user?.username ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await AuthService.fetchProfile();
    if (user != null && mounted) {
      setState(() {
        _user = user;
        _usernameCtrl.text = user.username;
      });
    }
  }

  void _showMsg(String msg) {
    setState(() => _msg = msg);
    Future.delayed(const Duration(seconds: 3),
        () => mounted ? setState(() => _msg = '') : null);
  }

  // ── Camera / Gallery photo picker ──────────────────────────────────────
  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text(
                'Pilih Foto Profil',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              _SheetOption(
                icon: Icons.camera_alt_outlined,
                label: '📷 Ambil Foto dengan Kamera',
                subtitle: 'Selfie untuk foto profilmu',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _SheetOption(
                icon: Icons.photo_library_outlined,
                label: '🖼️ Pilih dari Galeri',
                subtitle: 'Upload foto dari galeri',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // Request permission first
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showMsg('❌ Izin kamera ditolak. Aktifkan di pengaturan.');
        return;
      }
    } else {
      final status = await Permission.photos.request();
      if (!status.isGranted && status != PermissionStatus.limited) {
        // Try storage permission for older Android
        final storage = await Permission.storage.request();
        if (!storage.isGranted) {
          _showMsg('❌ Izin galeri ditolak. Aktifkan di pengaturan.');
          return;
        }
      }
    }

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
        preferredCameraDevice: CameraDevice.front, // selfie default
      );

      if (picked == null) return;

      _showMsg('⏳ Mengupload avatar...');
      setState(() => _saving = true);

      final bytes = await File(picked.path).readAsBytes();
      final base64 = base64Encode(bytes);
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,$base64';

      final result = await AuthService.updateProfile(avatar: dataUrl);
      if (result['success'] == true) {
        setState(() => _user = result['user']);
        _showMsg('✅ Foto profil diperbarui!');
      } else {
        _showMsg(result['error'] ?? '❌ Gagal upload foto');
      }
    } catch (e) {
      _showMsg('❌ Gagal memilih gambar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final result =
        await AuthService.updateProfile(username: _usernameCtrl.text.trim());
    if (result['success'] == true) {
      setState(() {
        _user = result['user'];
        _editing = false;
      });
      _showMsg('✅ Profil disimpan!');
    } else {
      _showMsg(result['error'] ?? '❌ Gagal menyimpan');
    }
    setState(() => _saving = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.logout();
      // Socket global sebaiknya tidak diputus hanya karena pindah screen.
      // Jika ingin memutus socket, lakukan terpusat (mis. benar-benar logout/keluar app).
      // Di sini kita biarkan socket tetap hidup supaya koneksi realtime tidak putus tiba-tiba.
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winRate = _user?.winRate ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildNavBar(),
          if (_msg.isNotEmpty) _buildMsgBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                // ── Avatar Card (Camera feature) ────────────────────────
                _buildAvatarCard(),
                const SizedBox(height: 20),

                // ── Profile Info Card ────────────────────────────────────
                _buildProfileCard(winRate),
                const SizedBox(height: 16),

                // ── Stats Card ───────────────────────────────────────────
                _buildStatsCard(winRate),
                const SizedBox(height: 16),

                // ── Info Card ────────────────────────────────────────────
                _buildInfoCard(),
              ],
            ),
          ),
          JankenBottomNav(
            currentIndex: 2,
            onTap: (i) {
              if (i == 0) Navigator.pushReplacementNamed(context, '/lobby');
              if (i == 1)
                Navigator.pushReplacementNamed(context, '/leaderboard');
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
            TextButton(
              onPressed: _logout,
              child: const Text('Keluar',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMsgBanner() {
    final isSuccess = _msg.startsWith('✅');
    final isLoading = _msg.startsWith('⏳');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isSuccess
          ? const Color(0xFFE8F5E9)
          : isLoading
              ? const Color(0xFFF5F5F5)
              : const Color(0xFFFDE8E8),
      child: Text(_msg,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isSuccess
                ? const Color(0xFF2E7D32)
                : isLoading
                    ? AppColors.textSecondary
                    : const Color(0xFFC62828),
          )),
    );
  }

  // ── Avatar card with camera button ──────────────────────────────────────
  Widget _buildAvatarCard() {
    return GestureDetector(
      onTap: _showAvatarOptions,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.rankBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3), width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _user?.avatar != null
                      ? _buildAvatarImage(_user!.avatar!)
                      : const Center(
                          child: Text('🐼', style: TextStyle(fontSize: 48))),
                ),
                // Camera badge
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: _saving
                      ? const Center(
                          child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)))
                      : const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '📷 Ketuk untuk ganti foto profil',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ambil selfie atau pilih dari galeri',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '📱 Fitur Mobile: Kamera & Galeri',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String src) {
    // Handle base64 and URL
    if (src.startsWith('data:')) {
      try {
        final commaIdx = src.indexOf(',');
        if (commaIdx > 0) {
          final b64 = src.substring(commaIdx + 1);
          final bytes = base64Decode(b64);
          return Image.memory(bytes, fit: BoxFit.cover);
        }
      } catch (_) {}
    }
    return Image.network(src,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Text('🐼', style: TextStyle(fontSize: 48))));
  }

  Widget _buildProfileCard(int winRate) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_editing) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Username baru',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => setState(() {
                    _editing = false;
                    _usernameCtrl.text = _user?.username ?? '';
                  }),
                  child: const Text('Batal',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?.username ?? '-',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _user?.email ?? '-',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _editing = true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Edit',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard(int winRate) {
    final stats = [
      _Stat(
          label: 'POIN',
          value: '${_user?.rankedPoints ?? 1000}',
          color: AppColors.primary),
      _Stat(
          label: 'MENANG',
          value: '${_user?.wins ?? 0}',
          color: AppColors.green),
      _Stat(label: 'WIN RATE', value: '$winRate%', color: AppColors.blue),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: stats.map((s) => Expanded(child: _buildStatItem(s))).toList(),
      ),
    );
  }

  Widget _buildStatItem(_Stat s) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(s.value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: s.color)),
          const SizedBox(height: 4),
          Text(s.label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    String joinDate = '-';
    if (_user?.createdAt != null) {
      try {
        final dt = DateTime.parse(_user!.createdAt!);
        joinDate = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bergabung sejak $joinDate',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Total kalah: ${_user?.losses ?? 0} game',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final Color color;
  _Stat({required this.label, required this.value, required this.color});
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
