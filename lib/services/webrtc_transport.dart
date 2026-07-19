import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:p2p_chat/models/device.dart';
import 'package:p2p_chat/models/message.dart';
import 'package:p2p_chat/services/signaling_service.dart';

/// 一条跨网 WebRTC 连接（数据通道）
///
/// 封装 RTCPeerConnection + RTCDataChannel，对外只暴露：
/// - [connect]        发起连接（创建者自动建 offer，加入者读 offer 回 answer）
/// - [send]           发送一条文本消息
/// - [onMessage]      收到消息回调
/// - [onConnected]    通道打开、对端就绪回调
/// - [isConnected]    当前是否可通信
///
/// 使用公共 STUN 服务器做 NAT 穿透，无需自建 turn（多数家庭宽带可直连）。
class WebRtcTransport {
  final String roomId;
  final bool isOfferer;
  final String myName;
  final String role; // 'caller' / 'callee'
  final SignalingService signaling;

  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;

  Function(ChatMessage)? onMessage;
  Function(PeerDevice)? onConnected;
  Function(String)? onError;

  PeerDevice? peer;

  WebRtcTransport({
    required this.roomId,
    required this.isOfferer,
    required this.myName,
    required this.role,
    required this.signaling,
  });

  bool get isConnected =>
      _dc != null && _dc!.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> connect() async {
    try {
      _pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });

      // 本地 ICE 候选产生 -> 经信令转发给对方
      _pc!.onIceCandidate = (c) {
        signaling.sendCandidate(roomId, {
          ...c.toMap(),
          'by': role,
        });
      };

      // 加入者侧：对方创建的数据通道到达
      _pc!.onDataChannel = (dc) {
        _dc = dc;
        _setupDataChannel();
      };

      if (isOfferer) {
        // 创建者：主动建数据通道并发 offer
        _dc = await _pc!.createDataChannel('chat', RTCDataChannelInit());
        _setupDataChannel();
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        await signaling.createRoom(
          myName: myName,
          offer: offer.toMap(),
          role: role,
          onAnswer: (ans) async {
            await _pc!.setRemoteDescription(
              RTCSessionDescription(ans['sdp'], ans['type']),
            );
          },
          onCandidate: (c) async {
            await _pc!.addCandidate(
              RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
            );
          },
        );
      } else {
        // 加入者：读 offer、回 answer
        await signaling.joinRoom(
          roomId: roomId,
          myName: myName,
          role: role,
          onOffer: (off) async {
            await _pc!.setRemoteDescription(
              RTCSessionDescription(off['sdp'], off['type']),
            );
            final answer = await _pc!.createAnswer();
            await _pc!.setLocalDescription(answer);
            await signaling.sendAnswer(roomId, answer.toMap());
          },
          onCandidate: (c) async {
            await _pc!.addCandidate(
              RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
            );
          },
        );
      }
    } catch (e) {
      onError?.call('连接失败：$e');
      rethrow;
    }
  }

  void _setupDataChannel() {
    _dc!.onMessage = (msg) {
      if (msg.type != MessageType.text) return;
      try {
        final json = jsonDecode(msg.text) as Map<String, dynamic>;
        final m = ChatMessage.fromJson(json, isMe: false)
            .copyWith(peerId: roomId);
        onMessage?.call(m);
      } catch (_) {
        // 忽略非法包
      }
    };
    _dc!.onDataChannelState = (s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        peer = PeerDevice(
          id: roomId,
          name: '房间 $roomId',
          mode: ChatMode.wan,
        );
        onConnected?.call(peer!);
      }
    };
  }

  Future<bool> send(String text) async {
    if (!isConnected) return false;
    final msg = ChatMessage(
      fromName: myName,
      fromIp: '',
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isMe: true,
      peerId: roomId,
    );
    _dc!.send(RTCDataChannelMessage(msg.toRaw()));
    onMessage?.call(msg); // 本地回显
    return true;
  }

  void close() {
    try {
      _dc?.close();
    } catch (_) {}
    try {
      _pc?.close();
    } catch (_) {}
  }
}
