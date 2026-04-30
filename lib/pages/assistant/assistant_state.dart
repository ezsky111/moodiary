import 'dart:convert';

import 'package:get/get.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/pages/assistant/diary_analysis/diary_analysis_model.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';

class AssistantState {
  static const _historyPrefKey = 'chatHistory';
  static const _diaryIdsPrefKey = 'chatDiaryContextIds';

  /// 最大保存消息数
  static const int _maxHistory = 100;

  /// 最多可选日记数
  static const int maxSelectedDiaries = 20;

  //对话上下文
  late Map<DateTime, Message> messages;

  // AI 提供商类型
  late RxString aiProvider;

  //模型名称（用户可配置）
  late RxString aiModel;

  late KeyboardState keyboardState;

  late int totalToken;

  /// 缓存的日记记忆上下文
  String memoryContext = '';

  /// 路由传入的特定日记上下文
  Diary? diaryContext;

  /// AI 分析总结（时间范围分析）
  DiaryAnalysis? diaryAnalysis;

  /// 用户多选添加的日记上下文
  List<Diary> selectedDiaries = [];

  AssistantState() {
    messages = {};
    aiProvider = (PrefUtil.getValue<String>('aiProvider') ?? 'openai').obs;
    aiModel = (PrefUtil.getValue<String>('aiModel') ?? '').obs;
    keyboardState = KeyboardState.closed;
  }

  /// 从 SharedPreferences 加载持久化的聊天历史
  void loadMessages() {
    final jsonStr = PrefUtil.getValue<String>(_historyPrefKey);
    if (jsonStr == null || jsonStr.isEmpty) return;
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      messages = {};
      for (final item in decoded) {
        final map = item as Map<String, dynamic>;
        final time = DateTime.parse(map['time'] as String);
        messages[time] = Message(
          role: map['role'] as String? ?? '',
          content: map['content'] as String? ?? '',
        );
      }
    } catch (_) {
      messages = {};
    }
  }

  /// 将当前聊天历史持久化到 SharedPreferences
  Future<void> saveMessages() async {
    if (messages.isEmpty) {
      await PrefUtil.removeValue(_historyPrefKey);
      return;
    }
    // 保留最近的 N 条，移除 system 消息（重建时不依赖）
    final entries = messages.entries
        .where((e) => e.value.role != 'system')
        .toList();
    // 如果超出限制，只保留最近的
    if (entries.length > _maxHistory) {
      entries.removeRange(0, entries.length - _maxHistory);
    }
    final list = entries
        .map((e) => {
              'time': e.key.toIso8601String(),
              'role': e.value.role,
              'content': e.value.content,
            })
        .toList();
    await PrefUtil.setValue<String>(_historyPrefKey, jsonEncode(list));
  }

  /// 从 SharedPreferences 加载持久化的日记上下文 IDs，重新从 Isar 加载
  Future<void> loadDiaryContext() async {
    final idsStr = PrefUtil.getValue<String>(_diaryIdsPrefKey);
    if (idsStr == null || idsStr.isEmpty) return;
    try {
      final ids = (jsonDecode(idsStr) as List<dynamic>)
          .map((e) => e as int)
          .toList();
      selectedDiaries = [];
      for (final id in ids) {
        final diary = await IsarUtil.getDiaryByID(id);
        if (diary != null && diary.show) {
          selectedDiaries.add(diary);
        }
      }
    } catch (_) {
      selectedDiaries = [];
    }
  }

  /// 持久化当前选中的日记上下文 IDs
  Future<void> saveDiaryContext() async {
    if (selectedDiaries.isEmpty) {
      await PrefUtil.removeValue(_diaryIdsPrefKey);
      return;
    }
    final ids = selectedDiaries.map((d) => d.isarId).toList();
    await PrefUtil.setValue<String>(_diaryIdsPrefKey, jsonEncode(ids));
  }
}
