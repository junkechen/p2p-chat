import 'package:flutter/material.dart';
import 'package:p2p_chat/models/device.dart';
import 'package:p2p_chat/screens/discovery_screen.dart';
import 'package:p2p_chat/services/p2p_service.dart';

/// 第一步：输入昵称并选择连接模式，启动 P2P 服务
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ctrl = TextEditingController();
  ChatMode _mode = ChatMode.lan;
  bool _starting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称')),
      );
      return;
    }
    setState(() => _starting = true);
    try {
      await P2PService().start(name, mode: _mode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败：$e')),
        );
        setState(() => _starting = false);
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DiscoveryScreen(myName: name, mode: _mode),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.08, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text('P2P 聊天',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('点对点直连 · 不依赖中心服务器',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  labelText: '你的昵称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('连接模式',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ChatMode>(
                segments: const [
                  ButtonSegment(
                    value: ChatMode.lan,
                    label: Text('局域网'),
                    icon: Icon(Icons.wifi),
                  ),
                  ButtonSegment(
                    value: ChatMode.wan,
                    label: Text('跨网'),
                    icon: Icon(Icons.public),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == ChatMode.lan
                    ? '同一 WiFi 下自动发现，纯直连，完全不经任何服务器'
                    : '不同 WiFi / 不同网络也能聊；握手走 Firebase，消息端到端直连加密',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _starting ? null : _start,
                  child: _starting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('开始', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
