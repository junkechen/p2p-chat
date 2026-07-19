/// 聊天模式
enum ChatMode { lan, wan }

/// 发现的在线对端设备
class PeerDevice {
  final String id; // 唯一标识：局域网 = IP，跨网 = 房间号
  final String ip;
  String name;
  int port;
  final ChatMode mode;
  DateTime lastSeen;

  PeerDevice({
    required this.id,
    required this.name,
    this.ip = '',
    this.port = 0,
    this.mode = ChatMode.lan,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// 收到一次广播就刷新存活时间
  void touch() => lastSeen = DateTime.now();

  /// 超过 12 秒未收到广播视为离线（仅局域网模式使用）
  bool get isAlive => DateTime.now().difference(lastSeen).inSeconds < 12;

  @override
  bool operator ==(Object other) => other is PeerDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name($id)';
}
