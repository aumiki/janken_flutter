import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _connectedToken;

  static IO.Socket? get socket => _socket;
  static bool get isConnected => _socket?.connected ?? false;

  static IO.Socket connect() {
    final token = AuthService.token;

    // Reset socket jika token berubah (ganti akun / re-login)
    if (_socket != null && _connectedToken != token) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _connectedToken = null;
    }

    if (_socket != null && _socket!.connected) return _socket!;

    _connectedToken = token;
    print('[Socket] 🔑 Token saat connect: "$token"'); // ← tambah ini
    _socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setPath('/api/socket')
          .setTransports(['websocket']) // ← websocket only, skip polling
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .setTimeout(30000)
          .setExtraHeaders({
            'Authorization': 'Bearer ${token ?? ''}', // ← pindah ke header
          })
          .setAuth({'token': token ?? ''})
          .build(),
    );

    _socket!.onConnect((_) {
      print('[Socket] ✅ Connected: ${_socket!.id}');
    });
    _socket!.onDisconnect((reason) {
      print('[Socket] ❌ Disconnected: $reason');
    });
    _socket!.onConnectError((e) {
      print('[Socket] ⚠️ Connect error: $e');
    });
    _socket!.onReconnect((_) {
      print('[Socket] 🔄 Reconnected');
    });
    _socket!.onError((e) {
      print('[Socket] Error: $e');
    });

    _socket!.connect();
    return _socket!;
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _connectedToken = null;
  }

  static void emit(String event, [dynamic data]) {
    if (_socket == null || !_socket!.connected) {
      print('[Socket] Emit "$event" gagal — belum connected');
      return;
    }
    _socket!.emit(event, data);
  }

  static void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  static void off(String event) {
    _socket?.off(event);
  }
}
