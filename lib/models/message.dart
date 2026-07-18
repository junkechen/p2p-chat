import 'dart:convert';

/// 一条聊天消息
class ChatMessage {
  final String fromName;
  final String fromIp;
  final String text;
  final int timestamp;
  final bool isMe;

  ChatMessage({
    required this.fromName,
    required this.fromIp,
    required this.text,
    required this.timestamp,
    this.isMe = false,
  });

  Map<String, dynamic> toJson() => {
        'fromName': fromName,
        'fromIp': fromIp,
        'text': text,
        'timestamp': timestamp,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json, {bool isMe = false}) =>
      ChatMessage(
        fromName: json['fromName'] as String? ?? '未知',
        fromIp: json['fromIp'] as String? ?? '',
        text: json['text'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
        isMe: isMe,
      );

  /// 序列化为 TCP 传输用的原始 JSON 字符串
  String toRaw() => jsonEncode(toJson());

  ChatMessage copyWith({
    String? fromName,
    String? fromIp,
    String? text,
    int? timestamp,
    bool? isMe,
  }) =>
      ChatMessage(
        fromName: fromName ?? this.fromName,
        fromIp: fromIp ?? this.fromIp,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
        isMe: isMe ?? this.isMe,
      );
}
