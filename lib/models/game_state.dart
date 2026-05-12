class PlayerState {
  final String id;
  final String username;
  final int hp;
  final List<String> buffs;

  PlayerState({
    required this.id,
    required this.username,
    this.hp = 100,
    this.buffs = const [],
  });

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        id: json['id'] ?? '',
        username: json['username'] ?? '',
        hp: json['hp'] ?? 100,
        buffs: List<String>.from(json['buffs'] ?? []),
      );

  PlayerState copyWith({int? hp, List<String>? buffs}) => PlayerState(
        id: id,
        username: username,
        hp: hp ?? this.hp,
        buffs: buffs ?? this.buffs,
      );
}

enum GamePhase { waiting, picking, reveal, trivia, gameover }

enum GameMove { rock, paper, scissors }

enum RoundResult { p1Win, p2Win, draw }

extension GameMoveExt on GameMove {
  String get name {
    switch (this) {
      case GameMove.rock:
        return 'ROCK';
      case GameMove.paper:
        return 'PAPER';
      case GameMove.scissors:
        return 'SCISSORS';
    }
  }

  String get label {
    switch (this) {
      case GameMove.rock:
        return 'BATU';
      case GameMove.paper:
        return 'KERTAS';
      case GameMove.scissors:
        return 'GUNTING';
    }
  }

  String get emoji {
    switch (this) {
      case GameMove.rock:
        return '💎';
      case GameMove.paper:
        return '📄';
      case GameMove.scissors:
        return '✂️';
    }
  }

  String get icon {
    switch (this) {
      case GameMove.rock:
        return '✊';
      case GameMove.paper:
        return '🖐️';
      case GameMove.scissors:
        return '✌️';
    }
  }

  static GameMove? fromString(String? s) {
    if (s == null) return null;
    switch (s.toUpperCase()) {
      case 'ROCK':
        return GameMove.rock;
      case 'PAPER':
        return GameMove.paper;
      case 'SCISSORS':
        return GameMove.scissors;
      default:
        return null;
    }
  }
}

class TriviaState {
  final String question;
  final List<String> options;
  String? correctAnswer;
  int triviaTimer;
  String? myAnswer;
  bool answered;
  bool? correct;
  bool resolved;

  TriviaState({
    required this.question,
    required this.options,
    this.correctAnswer,
    this.triviaTimer = 15,
    this.myAnswer,
    this.answered = false,
    this.correct,
    this.resolved = false,
  });
}

class RoundResultData {
  final String result;
  final String? p1Move;
  final String? p2Move;
  final int p1HP;
  final int p2HP;
  final int damageToPl1;
  final int damageToPl2;

  RoundResultData({
    required this.result,
    this.p1Move,
    this.p2Move,
    required this.p1HP,
    required this.p2HP,
    this.damageToPl1 = 0,
    this.damageToPl2 = 0,
  });

  factory RoundResultData.fromJson(Map<String, dynamic> json) =>
      RoundResultData(
        result: json['result'] ?? 'DRAW',
        p1Move: json['p1Move'],
        p2Move: json['p2Move'],
        p1HP: json['p1HP'] ?? 100,
        p2HP: json['p2HP'] ?? 100,
        damageToPl1: json['damageToPl1'] ?? 0,
        damageToPl2: json['damageToPl2'] ?? 0,
      );
}

class GameOverData {
  final String? winnerId;
  final String winnerName;
  final int totalRounds;
  final int p1Delta;
  final int p2Delta;

  GameOverData({
    this.winnerId,
    required this.winnerName,
    required this.totalRounds,
    this.p1Delta = 0,
    this.p2Delta = 0,
  });

  factory GameOverData.fromJson(Map<String, dynamic> json) => GameOverData(
        winnerId: json['winnerId'],
        winnerName: json['winnerName'] ?? '',
        totalRounds: json['totalRounds'] ?? 0,
        p1Delta: json['p1Delta'] ?? 0,
        p2Delta: json['p2Delta'] ?? 0,
      );
}

class GameEffect {
  final String id;
  final String name;
  final String type; // 'buff' | 'debuff'

  GameEffect({required this.id, required this.name, required this.type});
}

class ChallengeData {
  final String challengerId;
  final String challengerName;
  final int challengerPoints;

  ChallengeData({
    required this.challengerId,
    required this.challengerName,
    required this.challengerPoints,
  });

  factory ChallengeData.fromJson(Map<String, dynamic> json) => ChallengeData(
        challengerId: json['challengerId'] ?? '',
        challengerName: json['challengerName'] ?? '',
        challengerPoints: json['challengerPoints'] ?? 1000,
      );
}
