/// 发现的在线对端设备
class PeerDevice {
  final String ip;
  String name;
  int port;
  DateTime lastSeen;

  PeerDevice({
    required this.ip,
    required this.name,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// 收到一次广播就刷新存活时间
  void touch() => lastSeen = DateTime.now();

  /// 超过 12 秒未收到广播视为离线
  bool get isAlive => DateTime.now().difference(lastSeen).inSeconds < 12;

  @override
  bool operator ==(Object other) => other is PeerDevice && other.ip == ip;

  @override
  int get hashCode => ip.hashCode;

  @override
  String toString() => '$name($ip:$port)';
}
