/// Input boundary used by Flame components. Offline games leave this null and
/// execute local pass-and-play rules; online games send intents to the server.
abstract interface class GameCommandSink {
  void roll();
  void move(String tokenId);
}
