class UserModel {
  final String id;
  final String username;
  final String email;
  final String? avatar;
  final int rankedPoints;
  final int wins;
  final int losses;
  final bool isOnline;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    this.rankedPoints = 1000,
    this.wins = 0,
    this.losses = 0,
    this.isOnline = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      rankedPoints: json['rankedPoints'] ?? 1000,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      isOnline: json['isOnline'] ?? false,
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar': avatar,
        'rankedPoints': rankedPoints,
        'wins': wins,
        'losses': losses,
        'isOnline': isOnline,
        'createdAt': createdAt,
      };

  UserModel copyWith({
    String? username,
    String? avatar,
    int? rankedPoints,
    int? wins,
    int? losses,
    bool? isOnline,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email,
      avatar: avatar ?? this.avatar,
      rankedPoints: rankedPoints ?? this.rankedPoints,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
    );
  }

  int get winRate =>
      (wins + losses > 0) ? ((wins / (wins + losses)) * 100).round() : 0;
}
