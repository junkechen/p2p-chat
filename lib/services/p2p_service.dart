import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p2p_chat/models/device.dart';
import 'package:p2p_chat/models/message.dart';
import 'package:p2p_chat/services/signaling_service.dart';
import 'package:p2p_chat/services/webrtc_transport.dart';

/// P2P 通信核心服务（单例）
///
/// 两种模式：
/// - [ChatMode.lan] 局域网：UDP 广播发现（端口 5005）+ TCP 直连收发（端口 5006），纯 P2P。
/// - [ChatMode.wan] 跨网：   WebRTC 数据通道 + Firebase 信令（仅握手不碰消息），可跨不同 WiFi/网络。
class P2PService {
  static const int udpPort = 5005;
  static const int tcpPort = 5006;

  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  String myName = '匿名';
  ChatMode _mode = ChatMode.lan;
  ChatMode get mode => _mode;

  // ---- 局域网相关 ----
  final Map<String, PeerDevice> _peers = {};
  RawDatagramSocket? _udp;
  ServerSocket? _tcpServer;
  Timer? _broadcastTimer;
  Timer? _sweepTimer;

  // ---- 跨网相关 ----
  final SignalingService _signaling = SignalingService();
  final Map<String, WebRtcTransport> _wan = {};

  final _peerController = StreamController<PeerDevice>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();

  /// 设备上线/刷新事件（UI 用 StreamBuilder 订阅）
  Stream<PeerDevice> get peerStream => _peerController.stream;

  /// 收到新消息事件
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// 当前存活的对端列表
  List<PeerDevice> get peers {
    if (_mode == ChatMode.wan) {
      return _wan.values
          .where((t) => t.isConnected && t.peer != null)
          .map((t) => t.peer!)
          .toList();
    }
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
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            return ip;
          }
        }
      }
      for (final iface in interfaces) {
        if (iface.addresses.isNotEmpty) return iface.addresses.first.address;
      }
    } catch (_) {}
    return null;
  }

  /// 启动服务（输入昵称 + 模式）
  Future<void> start(String name, {ChatMode mode = ChatMode.lan}) async {
    myName = name.trim().isEmpty ? '匿名' : name.trim();
    _mode = mode;
    if (mode == ChatMode.lan) {
      await _startLan();
    } else {
      await _startWan();
    }
  }

  // ============ 局域网 ============

  Future<void> _startLan() async {
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
      final name = data['name'] as String? ?? '未知';
      final port = (data['port'] as int?) ?? tcpPort;
      _upsertPeer(ip, name, port);
    } catch (_) {}
  }

  void _upsertPeer(String ip, String name, int port) {
    final existing = _peers[ip];
    if (existing != null) {
      existing.name = name;
      existing.port = port;
      existing.touch();
    } else {
      _peers[ip] = PeerDevice(id: ip, name: name, ip: ip, port: port);
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
      _messageController.add(msg.copyWith(peerId: msg.fromIp));
    } catch (_) {}
    try {
      await socket.close();
    } catch (_) {}
  }

  Future<bool> _sendLan(String peerIp, String text) async {
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
        text: text,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isMe: true,
        peerId: peerIp,
      );
      socket.add(utf8.encode(msg.toRaw()));
      await socket.flush();
      await socket.close();
      _messageController.add(msg.copyWith(fromIp: peerIp));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============ 跨网（WebRTC + Firebase 信令） ============

  Future<void> _startWan() async {
    try {
      await _signaling.init();
    } catch (e) {
      throw Exception(
          'Firebase 初始化失败，请确认 lib/firebase_options.dart 已填入真实配置：$e');
    }
  }

  /// 创建房间，返回 6 位房间号（发给对方输入即可加入）
  Future<String> createRoom() async {
    if (_mode != ChatMode.wan) throw Exception('当前不是跨网模式');
    final id = _signaling.generateRoomId();
    final t = WebRtcTransport(
      roomId: id,
      isOfferer: true,
      myName: myName,
      role: 'caller',
      signaling: _signaling,
    );
    _attachWan(id, t);
    await t.connect();
    return id;
  }

  /// 加入指定房间号，返回是否成功
  Future<bool> joinRoom(String roomIdRaw) async {
    if (_mode != ChatMode.wan) return false;
    final id = roomIdRaw.trim();
    if (id.isEmpty || _wan.containsKey(id)) return false;
    final t = WebRtcTransport(
      roomId: id,
      isOfferer: false,
      myName: myName,
      role: 'callee',
      signaling: _signaling,
    );
    _attachWan(id, t);
    try {
      await t.connect();
      return true;
    } catch (e) {
      _wan.remove(id);
      return false;
    }
  }

  void _attachWan(String id, WebRtcTransport t) {
    t.onMessage = (m) => _messageController.add(m);
    t.onConnected = (p) => _peerController.add(p);
    t.onError = (e) => print('[WAN] $e');
    _wan[id] = t;
  }

  // ============ 统一收发 ============

  /// 发送消息。局域网 [targetId] 为对方 IP；跨网为房间号
  Future<bool> sendMessage(String targetId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value(false);
    if (_mode == ChatMode.wan) {
      final t = _wan[targetId];
      if (t == null) return Future.value(false);
      return t.send(trimmed);
    }
    return _sendLan(targetId, trimmed);
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
    for (final t in _wan.values) {
      t.close();
    }
    _wan.clear();
  }
}
