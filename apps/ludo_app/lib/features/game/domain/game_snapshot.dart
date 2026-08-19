enum MatchPhase { waitingForRoll, waitingForMove, finished }

enum Team { blue, red, green, yellow }

class TokenSnapshot {
  const TokenSnapshot({required this.id, required this.team, required this.progress});
  final String id;
  final Team team;
  final int progress; // -1 base, 0..55 board/path, 56 finished

  Map<String, dynamic> toJson() => {'id': id, 'team': team.name, 'progress': progress};
  factory TokenSnapshot.fromJson(Map<String, dynamic> json) => TokenSnapshot(
    id: json['id'] as String,
    team: Team.values.byName(json['team'] as String),
    progress: (json['progress'] as num).toInt(),
  );
}

class GameSnapshot {
  const GameSnapshot({
    required this.id,
    required this.version,
    required this.teams,
    required this.currentTurn,
    required this.phase,
    required this.tokens,
    required this.updatedAt,
    this.pendingDice,
    this.winner,
  });

  final String id;
  final int version;
  final List<Team> teams;
  final int currentTurn;
  final MatchPhase phase;
  final List<TokenSnapshot> tokens;
  final DateTime updatedAt;
  final int? pendingDice;
  final Team? winner;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'teams': teams.map((e) => e.name).toList(),
    'currentTurn': currentTurn,
    'phase': phase.name,
    'tokens': tokens.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
    'pendingDice': pendingDice,
    'winner': winner?.name,
  };

  factory GameSnapshot.fromJson(Map<String, dynamic> json) => GameSnapshot(
    id: json['id'] as String,
    version: (json['version'] as num?)?.toInt() ?? 0,
    teams: (json['teams'] as List).map((e) => Team.values.byName(e as String)).toList(),
    currentTurn: (json['currentTurn'] as num).toInt(),
    phase: MatchPhase.values.byName(json['phase'] as String),
    tokens: (json['tokens'] as List).map((e) => TokenSnapshot.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    pendingDice: (json['pendingDice'] as num?)?.toInt(),
    winner: json['winner'] == null ? null : Team.values.byName(json['winner'] as String),
  );
}
