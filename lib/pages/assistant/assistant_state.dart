import 'package:get/get.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
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

  AssistantState() {
    messages = {};
    aiProvider = (PrefUtil.getValue<String>('aiProvider') ?? 'openai').obs;
    aiModel = (PrefUtil.getValue<String>('aiModel') ?? '').obs;
    keyboardState = KeyboardState.closed;

    ///Initialize variables
  }
}
