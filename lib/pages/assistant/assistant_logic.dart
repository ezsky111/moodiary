import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/api/api.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'assistant_state.dart';

class AssistantLogic extends GetxController {
  final AssistantState state = AssistantState();

  //输入框控制器
  late TextEditingController textEditingController = TextEditingController();

  //控制器
  late ScrollController scrollController = ScrollController();

  //聚焦对象
  late FocusNode focusNode = FocusNode();
  late final KeyboardObserver keyboardObserver;

  List<double> heightList = [];

  @override
  void onInit() {
    keyboardObserver = KeyboardObserver(
      onStateChanged: (state) {
        switch (state) {
          case KeyboardState.opening:
            break;
          case KeyboardState.closing:
            unFocus();
            break;
          case KeyboardState.closed:
            break;
          case KeyboardState.unknown:
            break;
        }
      },
    );
    keyboardObserver.start();
    super.onInit();
  }

  @override
  void onClose() {
    keyboardObserver.stop();
    textEditingController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void handleBack() {
    if (focusNode.hasFocus) {
      unFocus();
      Future.delayed(const Duration(seconds: 1), () {
        Get.back();
      });
    } else {
      Get.back();
    }
  }

  void unFocus() {
    focusNode.unfocus();
  }

  void newChat() {
    state.messages = {};
    update();
  }

  void clearText() {
    textEditingController.clear();
  }

  // Check if AI config is available
  bool _checkAiConfig() {
    final baseUrl = PrefUtil.getValue<String>('aiBaseUrl');
    final apiKey = PrefUtil.getValue<String>('aiKey');
    if (baseUrl == null || apiKey == null || baseUrl.isEmpty || apiKey.isEmpty) {
      toast.info(message: '请先在实验室配置 AI 服务');
      return false;
    }
    return true;
  }

  //对话
  Future<void> getAi(String ask) async {
    if (!_checkAiConfig()) return;

    final provider = state.aiProvider.value;
    final model = state.aiModel.value;
    final baseUrl = PrefUtil.getValue<String>('aiBaseUrl')!;
    final apiKey = PrefUtil.getValue<String>('aiKey')!;

    //清空输入框
    clearText();
    //失去焦点
    unFocus();
    //拿到用户提问后，对话上下文中增加一项用户提问
    final askTime = DateTime.now();
    state.messages[askTime] = Message(role: 'user', content: ask);
    update();
    toBottom();

    //带着上下文请求
    final stream = provider == 'anthropic'
        ? await Api.chatWithAnthropic(baseUrl, apiKey, model,
            state.messages.values.toList())
        : await Api.chatWithOpenAI(baseUrl, apiKey, model,
            state.messages.values.toList());

    //如果收到了请求，添加一个回答上下文
    final replyTime = DateTime.now();
    state.messages[replyTime] = const Message(role: 'assistant', content: '');
    update();

    bool isFirstChunk = true;
    //接收stream
    stream?.listen((content) {
      if (content.isEmpty) return;

      if (provider == 'anthropic') {
        _parseAnthropicStream(content, replyTime, isFirstChunk);
        isFirstChunk = false;
      } else {
        _parseOpenAiStream(content, replyTime);
      }
    });
  }

  void _parseOpenAiStream(String content, DateTime replyTime) {
    if (!content.contains('data')) return;

    // Skip [DONE] signal
    if (content.contains('[DONE]')) return;

    try {
      final data = jsonDecode(content.split('data: ')[1]) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return;
      final delta = choices[0]['delta'] as Map<String, dynamic>?;
      final text = delta?['content'] as String? ?? '';
      if (text.isEmpty) return;

      final currentMessage = state.messages[replyTime]!;
      state.messages[replyTime] = currentMessage.copyWith(
        content: currentMessage.content + text,
      );
      HapticFeedback.vibrate();
      update();
    } catch (_) {
      // Skip malformed lines
    }
    toBottom();
  }

  void _parseAnthropicStream(String content, DateTime replyTime, bool isFirstChunk) {
    // Anthropic SSE format:
    // event: content_block_delta
    // data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"..."}}
    //
    // Lines may come in various forms, we extract text from content_block_delta events
    try {
      // Sometimes the event and data come in the same line
      // Try to extract JSON from "data: {...}" pattern
      if (content.contains('data:')) {
        final jsonStr = content.split('data: ').last.trim();
        if (jsonStr.startsWith('{')) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'content_block_delta') {
            final delta = data['delta'] as Map<String, dynamic>?;
            if (delta != null && delta['type'] == 'text_delta') {
              final text = delta['text'] as String? ?? '';
              if (text.isEmpty) return;

              final currentMessage = state.messages[replyTime]!;
              state.messages[replyTime] = currentMessage.copyWith(
                content: currentMessage.content + text,
              );
              if (!isFirstChunk) {
                HapticFeedback.vibrate();
              }
              update();
            }
          }
        }
      }
    } catch (_) {
      // Skip malformed lines
    }
    toBottom();
  }

  void toBottom() {
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
  }

  String getText() {
    return textEditingController.text;
  }

  Future<void> checkGetAi() async {
    final text = getText();
    if (text != '') {
      await getAi(text);
    } else {
      toast.info(message: '还没有输入问题');
    }
  }

  void changeModel(String model) {
    state.aiModel.value = model;
    PrefUtil.setValue<String>('aiModel', model);
    state.messages = {};
    update();
  }
}
