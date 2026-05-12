# TODO

## Bugfix: Flutter tidak menerima `game:challenge_received` setelah reconnect

- [ ] Pindahkan/ubah setup listener challenge di `LobbyScreen` agar re-register saat socket reconnect (tanpa off yang menghapus listener tanpa re-register).
- [ ] Pastikan event handler `game:challenge_received` hanya di-register setelah `socket` connect/reconnect.
- [ ] (opsional follow-up) Buat listener `game:challenge_received` lebih global (mis. NotificationService/SocketService) agar tidak hilang saat user pindah screen.
- [ ] Jalankan `flutter analyze` dan `flutter test` (atau minimal build) untuk memastikan tidak ada error.

