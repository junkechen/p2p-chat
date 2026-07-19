import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:p2p_chat/firebase_options.dart';

typedef _MapCallback = void Function(Map<String, dynamic> data);

/// 基于 Firebase Realtime Database 的信令服务
///
/// ⚠️ 只负责转发 WebRTC 的「握手」数据（SDP offer/answer 与 ICE candidate），
/// 绝不碰任何聊天内容。聊天消息建立连接后走端到端加密的数据通道直传。
///
/// 房间数据结构：
///   p2p_signaling/<roomId>/
///     ├─ callerName : 创建者昵称
///     ├─ calleeName : 加入者昵称
///     ├─ offer      : {type, sdp}       创建者写入
///     ├─ answer     : {type, sdp}       加入者写入
///     └─ candidates/<id> : {candidate, sdpMid, sdpMLineIndex, by}  双向追加
class SignalingService {
  static final SignalingService _i = SignalingService._();
  factory SignalingService() => _i;
  SignalingService._();

  bool _ready = false;

  /// 初始化 Firebase（幂等）
  Future<void> init() async {
    if (_ready) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _ready = true;
  }

  DatabaseReference _room(String id) =>
      FirebaseDatabase.instance.ref('p2p_signaling/$id');

  /// 生成一个 6 位数字房间号（好记、好输入）
  String generateRoomId() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// 创建者：写入 offer，并监听 answer 与候选
  /// [role] 为 'caller' / 'callee'，用于过滤自己发出的候选
  Future<String> createRoom({
    required String myName,
    required Map<String, dynamic> offer,
    required _MapCallback onAnswer,
    required _MapCallback onCandidate,
    required String role,
  }) async {
    final id = generateRoomId();
    final room = _room(id);
    await room.child('callerName').set(myName);
    await room.child('offer').set(offer);
    room.child('answer').onValue.listen((e) {
      if (!e.snapshot.exists || e.snapshot.value == null) return;
      final v = Map<String, dynamic>.from(e.snapshot.value as Map);
      if (v['type'] != null) onAnswer(v);
    });
    room.child('candidates').onChildAdded.listen((e) {
      if (e.snapshot.value == null) return;
      final v = Map<String, dynamic>.from(e.snapshot.value as Map);
      if (v['by'] == role) return; // 忽略自己发出的候选
      onCandidate(v);
    });
    return id;
  }

  /// 加入者：读取 offer，监听候选（answer 由调用方写完后会触发对方监听）
  Future<void> joinRoom({
    required String roomId,
    required String myName,
    required _MapCallback onOffer,
    required _MapCallback onCandidate,
    required String role,
  }) async {
    final room = _room(roomId);
    final snap = await room.child('offer').get();
    if (!snap.exists || snap.value == null) {
      throw Exception('房间不存在或对方尚未就绪');
    }
    onOffer(Map<String, dynamic>.from(snap.value as Map));
    await room.child('calleeName').set(myName);
    room.child('candidates').onChildAdded.listen((e) {
      if (e.snapshot.value == null) return;
      final v = Map<String, dynamic>.from(e.snapshot.value as Map);
      if (v['by'] == role) return;
      onCandidate(v);
    });
  }

  Future<void> sendAnswer(String roomId, Map<String, dynamic> answer) =>
      _room(roomId).child('answer').set(answer);

  Future<void> sendCandidate(String roomId, Map<String, dynamic> candidate) =>
      _room(roomId).child('candidates').push().set(candidate);
}
