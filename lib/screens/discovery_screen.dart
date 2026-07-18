import 'package:flutter/material.dart';
import 'package:p2p_chat/models/device.dart';
import 'package:p2p_chat/screens/chat_screen.dart';
import 'package:p2p_chat/services/p2p_service.dart';

/// 第二步：发现附近设备 + 手动连接
class DiscoveryScreen extends StatefulWidget {
  final String myName;
  const DiscoveryScreen({super.key, required this.myName});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _ipCtrl = TextEditingController();
  String? _localIp;
  final _svc = P2PService();

  @override
  void initState() {
    super.initState();
    _svc.localIp.then((ip) => mounted ? setState(() => _localIp = ip) : null);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  void _openChat(PeerDevice p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(peer: p, myName: widget.myName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('你好，${widget.myName}'),
        actions: [
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
          Container(
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
          ),
          Expanded(
            child: StreamBuilder<PeerDevice>(
              stream: _svc.peerStream,
              builder: (context, snapshot) {
                final peers = _svc.peers;
                if (peers.isEmpty) {
                  return const Center(
                    child: Text('正在发现附近设备...',
                        style: TextStyle(color: Colors.grey)),
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
                        subtitle: Text(p.ip),
                        trailing: const Icon(Icons.chat),
                        onTap: () => _openChat(p),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
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
                      ip: ip,
                      name: ip,
                      port: P2PService.tcpPort,
                    ));
                  },
                  child: const Text('连接'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
