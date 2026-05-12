class AppConfig {
  // Ganti dengan URL server kamu
  static const String baseUrl =
      'https://rps-game-website-production.up.railway.app';
  static const String socketUrl =
      'https://rps-game-website-production.up.railway.app';

  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String guestEndpoint = '/api/auth/guest';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String profileEndpoint = '/api/profile';
  static const String leaderboardEndpoint = '/api/leaderboard';

  // Push notification channel
  static const String notifChannelId = 'janken_challenge';
  static const String notifChannelName = 'Janken Challenge';
  static const String notifChannelDesc =
      'Notifikasi challenge dari pemain lain';
}
