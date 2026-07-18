import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p2p_chat/models/device.dart';
import 'package:p2p_chat/models/message.dart';

/// P2P 通信核心服务（单例）
///
/// 发现：UDP 广播（端口 [udpPort]），每 2 秒播一次，接收端据此维护在线列表
/// 传输：TCP（端口 [tcpPort]）短连接，发消息时主动连对方 -> 发送 -> 关闭
/// 接收：本地起 ServerSocket 监听，每条连接读取一整条消息后关闭
class P2PService {
  static const int udpPort = 5005;
  static const int tcpPort = 5006;

  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  String myName = '匿名';

  final Map<String, PeerDevice> _peers = {};
  RawDatagramSocket? _udp;
  ServerSocket? _tcpServer;
  Timer? _broadcastTimer;
  Timer? _sweepTimer;

  final _peerController = StreamController<PeerDevice>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();

  /// 设备上线/刷新事件（UI 用 StreamBuilder 订阅）
  Stream<PeerDevice> get peerStream => _peerController.stream;

  /// 收到新消息事件
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// 当前存活的对端列表（按昵称排序）
  List<PeerDevice> get peers {
    final alive = _peers.values.where((p) => p.isAlive).toList();
    alive.sort((a, b) => a.name.compareTo(b.name));
    return alive;
  }

  /// 获取本机 IPv4 地址（用于展示）
  Future<String?> get localIp async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // 跳过常见的虚拟/蜂窝网段，优先返回 WiFi 段
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            return ip;
          }
        }
      }
      // 没匹配到常见段就返回第一个
      for (final iface in interfaces) {
        if (iface.addresses.isNotEmpty) return iface.addresses.first.address;
      }
    } catch (_) {
      // 忽略，返回 null
    }
    return null;
  }

  /// 启动服务（输入昵称）
  Future<void> start(String name) async {
    myName = name.trim().isEmpty ? '匿名' : name.trim();

    _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
    _udp!.broadcastEnabled = true;
    _udp!.listen(_onUdpEvent);

    _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
    _tcpServer!.listen(_onTcpConnection);

    _broadcastTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _broadcast());
    _broadcast();

    _sweepTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sweep());
  }

  /// 主动重新广播一次
  void reAnnounce() => _broadcast();

  void _broadcast() {
    if (_udp == null) return;
    final payload = jsonEncode({
      'type': 'announce',
      'name': myName,
      'port': tcpPort,
    });
    _udp!.send(utf8.encode(payload), InternetAddress('255.255.255.255'), udpPort);
  }

  void _onUdpEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _udp!.receive();
    if (dg == null) return;
    try {
      final data = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
      if (data['type'] != 'announce') return;
      final ip = dg.address.address;
      // 忽略自己发给自己（同一台机器多网卡情况）
      final name = data['name'] as String? ?? '未知';
      final port = (data['port'] as int?) ?? tcpPort;
      _upsertPeer(ip, name, port);
    } catch (_) {
      // 忽略非法包
    }
  }

  void _upsertPeer(String ip, String name, int port) {
    final existing = _peers[ip];
    if (existing != null) {
      existing.name = name;
      existing.port = port;
      existing.touch();
    } else {
      _peers[ip] = PeerDevice(ip: ip, name: name, port: port);
    }
    _peerController.add(_peers[ip]!);
  }

  void _sweep() {
    final now = DateTime.now();
    final dead = _peers.entries
        .where((e) => now.difference(e.value.lastSeen).inSeconds >= 12)
        .map((e) => e.key)
        .toList();
    for (final k in dead) {
      _peers.remove(k);
    }
    _broadcast();
    // 通知 UI 列表可能变化（即便没有新 peer 事件）
    for (final p in _peers.values) {
      _peerController.add(p);
    }
  }

  void _onTcpConnection(Socket socket) async {
    final chunks = <int>[];
    try {
      await for (final data in socket) {
        chunks.addAll(data);
      }
      final json = jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
      final msg = ChatMessage.fromJson(json, isMe: false);
      _messageController.add(msg);
    } catch (_) {
      // 忽略损坏的连接
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  /// 向指定 IP 发送一条消息，返回是否成功
  Future<bool> sendMessage(String peerIp, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    try {
      final peer = _peers[peerIp];
      final port = peer?.port ?? tcpPort;
      final socket = await Socket.connect(
        peerIp,
        port,
        timeout: const Duration(seconds: 5),
      );
      final msg = ChatMessage(
        fromName: myName,
        fromIp: await localIp ?? '0.0.0.0',
        text: trimmed,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isMe: true,
      );
      socket.add(utf8.encode(msg.toRaw()));
      await socket.flush();
      await socket.close();
      // 本地回显（自己发出的气泡）
      _messageController.add(msg.copyWith(fromIp: peerIp));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 停止服务
  void stop() {
    _broadcastTimer?.cancel();
    _sweepTimer?.cancel();
    _broadcastTimer = null;
    _sweepTimer = null;
    try {
      _udp?.close();
    } catch (_) {}
    try {
      _tcpServer?.close();
    } catch (_) {}
    _udp = null;
    _tcpServer = null;
  }
}
