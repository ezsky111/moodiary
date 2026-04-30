import 'package:get/get.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/pages/assistant/diary_analysis/diary_analysis_model.dart';
import 'package:moodiary/persistence/pref.dart';

class AssistantState {
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

  AssistantState() {
    messages = {};
    aiProvider = (PrefUtil.getValue<String>('aiProvider') ?? 'openai').obs;
    aiModel = (PrefUtil.getValue<String>('aiModel') ?? '').obs;
    keyboardState = KeyboardState.closed;
  }
}
