import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';

class OfflineGameRepository {
  OfflineGameRepository([Box<String>? box]) : _box = box ?? Hive.box<String>('offline_games');
  final Box<String> _box;

  Future<void> save(GameSnapshot snapshot) =>
      _box.put(snapshot.id, jsonEncode(snapshot.toJson()));

  GameSnapshot? find(String id) {
    final value = _box.get(id);
    if (value == null) return null;
    return GameSnapshot.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  List<GameSnapshot> unfinished() => _box.values
      .map((value) => GameSnapshot.fromJson(jsonDecode(value) as Map<String, dynamic>))
      .where((game) => game.phase != MatchPhase.finished)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> remove(String id) => _box.delete(id);
}
