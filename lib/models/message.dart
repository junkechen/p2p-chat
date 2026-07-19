import 'dart:convert';

/// 一条聊天消息
class ChatMessage {
  final String fromName;
  final String fromIp;
  final String text;
  final int timestamp;
  final bool isMe;
  final String peerId; // 用于匹配当前会话对端（局域网=对方IP，跨网=房间号）

  ChatMessage({
    required this.fromName,
    required this.fromIp,
    required this.text,
    required this.timestamp,
    this.isMe = false,
    this.peerId = '',
  });

  Map<String, dynamic> toJson() => {
        'fromName': fromName,
        'fromIp': fromIp,
        'text': text,
        'timestamp': timestamp,
        'peerId': peerId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json, {bool isMe = false}) =>
      ChatMessage(
        fromName: json['fromName'] as String? ?? '未知',
        fromIp: json['fromIp'] as String? ?? '',
        text: json['text'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
        isMe: isMe,
        peerId: json['peerId'] as String? ?? '',
      );

  /// 序列化为 TCP 传输用的原始 JSON 字符串
  String toRaw() => jsonEncode(toJson());

  ChatMessage copyWith({
    String? fromName,
    String? fromIp,
    String? text,
    int? timestamp,
    bool? isMe,
    String? peerId,
  }) =>
      ChatMessage(
        fromName: fromName ?? this.fromName,
        fromIp: fromIp ?? this.fromIp,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
        isMe: isMe ?? this.isMe,
        peerId: peerId ?? this.peerId,
      );
}
