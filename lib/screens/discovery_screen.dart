import 'package:flutter/material.dart';
import 'package:p2p_chat/models/device.dart';
import 'package:p2p_chat/screens/chat_screen.dart';
import 'package:p2p_chat/services/p2p_service.dart';

/// 第二步：发现设备（局域网）或房间配对（跨网）
class DiscoveryScreen extends StatefulWidget {
  final String myName;
  final ChatMode mode;
  const DiscoveryScreen({
    super.key,
    required this.myName,
    required this.mode,
  });

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _ipCtrl = TextEditingController();
  final _joinCtrl = TextEditingController();
  String? _localIp;
  String? _roomId;
  bool _creating = false;
  bool _joining = false;
  final _svc = P2PService();

  @override
  void initState() {
    super.initState();
    _svc.localIp.then((ip) => mounted ? setState(() => _localIp = ip) : null);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _joinCtrl.dispose();
    super.dispose();
  }

  void _openChat(PeerDevice p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(peer: p, myName: widget.myName),
      ),
    );
  }

  Future<void> _createRoom() async {
    setState(() => _creating = true);
    try {
      final id = await _svc.createRoom();
      setState(() => _roomId = id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建房间失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _joinRoom() async {
    final id = _joinCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _joining = true);
    final ok = await _svc.joinRoom(id);
    setState(() => _joining = false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入失败，请检查房间号是否正确')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('你好，${widget.myName}'),
        actions: [
          if (widget.mode == ChatMode.lan)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: () {
                _svc.reAnnounce();
                setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _topHint(),
          Expanded(
            child: StreamBuilder<PeerDevice>(
              stream: _svc.peerStream,
              builder: (context, snapshot) {
                final peers = _svc.peers;
                if (peers.isEmpty) {
                  return Center(
                    child: Text(
                      widget.mode == ChatMode.lan
                          ? '正在发现附近设备...'
                          : '还没有已连接的对端',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: peers.length,
                  itemBuilder: (_, i) {
                    final p = peers[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading:
                            const CircleAvatar(child: Icon(Icons.smartphone)),
                        title: Text(p.name),
                        subtitle: Text(p.id),
                        trailing: const Icon(Icons.chat),
                        onTap: () => _openChat(p),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _bottomAction(),
        ],
      ),
    );
  }

  /// 顶部提示区（按模式不同）
  Widget _topHint() {
    if (widget.mode == ChatMode.lan) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '本机 IP：${_localIp ?? '获取中...'}\n请确保双方连接同一 WiFi（同一网段）',
          style: const TextStyle(fontSize: 14),
        ),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _roomId == null
            ? '跨网模式：创建一个房间，把 6 位房间号发给对方；或输入对方房间号加入。\n消息走端到端加密直连，不经服务器。'
            : '已将房间号发给对方，等待对方加入...',
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  /// 底部操作区（按模式不同）
  Widget _bottomAction() {
    if (widget.mode == ChatMode.lan) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                  labelText: '手动输入对方 IP',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final ip = _ipCtrl.text.trim();
                if (ip.isEmpty) return;
                _openChat(PeerDevice(
                  id: ip,
                  name: ip,
                  ip: ip,
                  port: P2PService.tcpPort,
                ));
              },
              child: const Text('连接'),
            ),
          ],
        ),
      );
    }

    // 跨网模式：创建房间 / 显示房间号 / 加入房间
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _roomId == null
          ? Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _creating ? null : _createRoom,
                    child: _creating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('创建房间'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _joinCtrl,
                        decoration: const InputDecoration(
                          labelText: '输入对方房间号',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _joining ? null : _joinRoom,
                      child: _joining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('加入'),
                    ),
                  ],
                ),
              ],
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('你的房间号', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  SelectableText(
                    _roomId!,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('把它发给对方，对方输入即可加入',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
    );
  }
}
