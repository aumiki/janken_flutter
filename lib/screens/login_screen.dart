import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _showGuest = false;
  String _error = '';

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  bool _obscure = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _guestNameCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _error = '');
    });
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      Map<String, dynamic> result;
      if (_isLogin) {
        result = await AuthService.login(
            _emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        result = await AuthService.register(
          _usernameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        if (result['success'] == true) {
          setState(() {
            _isLogin = true;
            _isLoading = false;
            _passwordCtrl.clear();
          });
          _showError('✅ Registrasi berhasil! Silakan login.');
          return;
        }
      }
      if (result['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/lobby');
      } else {
        _showError(result['error'] ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      _showError('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuest() async {
    if (_guestNameCtrl.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final result =
          await AuthService.loginAsGuest(_guestNameCtrl.text.trim());
      if (result['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/lobby');
      } else {
        _showError(result['error'] ?? 'Gagal masuk sebagai tamu');
      }
    } catch (e) {
      _showError('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Center(
                          child: Text('✊',
                              style: TextStyle(fontSize: 44)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'JANKEN',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RPS Battle Arena',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Tab switcher
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _TabBtn(
                        label: 'Masuk',
                        active: _isLogin,
                        onTap: () => setState(() {
                          _isLogin = true;
                          _error = '';
                          _showGuest = false;
                        }),
                      ),
                      _TabBtn(
                        label: 'Daftar',
                        active: !_isLogin && !_showGuest,
                        onTap: () => setState(() {
                          _isLogin = false;
                          _error = '';
                          _showGuest = false;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Error / success message
                if (_error.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _error.startsWith('✅')
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error,
                      style: TextStyle(
                        color: _error.startsWith('✅')
                            ? const Color(0xFF2E7D32)
                            : AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Form
                if (!_showGuest) ...[
                  if (!_isLogin)
                    _Field(
                      controller: _usernameCtrl,
                      label: 'Username',
                      hint: 'Nama pemain kamu',
                      icon: Icons.person_outline,
                    ),
                  _Field(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'email@contoh.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _Field(
                    controller: _passwordCtrl,
                    label: 'Password',
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(_isLogin ? 'MASUK ⚡' : 'DAFTAR'),
                    ),
                  ),
                ] else ...[
                  // Guest mode
                  _Field(
                    controller: _guestNameCtrl,
                    label: 'Nama Tamu',
                    hint: 'Masukkan nama panggilanmu',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGuest,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('MASUK SEBAGAI TAMU'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Guest button
                OutlinedButton(
                  onPressed: () => setState(() {
                    _showGuest = !_showGuest;
                    _error = '';
                  }),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _showGuest ? '← Kembali ke Login' : '👥 Masuk Sebagai Tamu',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon:
              Icon(icon, color: AppColors.textSecondary, size: 20),
          suffixIcon: suffix,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
