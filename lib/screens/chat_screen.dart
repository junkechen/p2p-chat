import 'package:flutter/material.dart';
import 'package:p2p_chat/models/device.dart';
import 'package:p2p_chat/models/message.dart';
import 'package:p2p_chat/services/p2p_service.dart';
import 'package:p2p_chat/widgets/message_bubble.dart';

/// 第三步：与某个对端聊天
class ChatScreen extends StatefulWidget {
  final PeerDevice peer;
  final String myName;
  const ChatScreen({super.key, required this.peer, required this.myName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _messages = <ChatMessage>[];
  final _scrollCtrl = ScrollController();
  final _svc = P2PService();

  @override
  void initState() {
    super.initState();
    _svc.messageStream.listen(_onMessage);
  }

  void _onMessage(ChatMessage msg) {
    // 只展示与当前对端的对话：优先用 peerId，回退到 fromIp
    final key = msg.peerId.isNotEmpty ? msg.peerId : msg.fromIp;
    if (key != widget.peer.id) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final ok = await _svc.sendMessage(widget.peer.id, text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发送失败，对方可能不在线或不通')),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWan = widget.peer.mode == ChatMode.wan;
    return Scaffold(
      appBar: AppBar(
        title: Text(isWan ? '房间 ${widget.peer.id}' : widget.peer.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                isWan ? '跨网·加密直连' : widget.peer.ip,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => MessageBubble(msg: _messages[i]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
