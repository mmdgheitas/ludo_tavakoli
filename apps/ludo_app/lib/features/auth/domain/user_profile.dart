class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.coinBalance,
    this.email,
    required this.fattahBalance,
    this.avatarUrl,
    this.vipExpiresAt,
  });

  final String id;
  final String username;
  final String? email;
  final int coinBalance;
  final int fattahBalance;
  final String? avatarUrl;
  final DateTime? vipExpiresAt;

  bool get isVip => vipExpiresAt?.isAfter(DateTime.now()) ?? false;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String?,
    coinBalance: (json['coinBalance'] as num?)?.toInt() ?? 0,
    fattahBalance: (json['fattahBalance'] as num?)?.toInt() ?? 0,
    avatarUrl: json['avatarUrl'] as String?,
    vipExpiresAt: json['vipExpiresAt'] == null
        ? null
        : DateTime.parse(json['vipExpiresAt'] as String),
  );
}
