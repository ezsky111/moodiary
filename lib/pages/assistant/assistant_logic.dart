import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/api/api.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'assistant_diary_memory.dart';
import 'assistant_state.dart';
import 'companion_persona.dart';
import 'diary_analysis/diary_analysis_model.dart';

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
    // 异步构建日记记忆上下文
    _refreshMemoryContext();
    // 加载已保存的 AI 分析总结
    state.diaryAnalysis = DiaryAnalysis.fromPrefs();
    // 加载持久化的聊天历史
    state.loadMessages();
    // 加载持久化的日记上下文
    state.loadDiaryContext();
    // 从路由参数中获取日记上下文
    final diaryArg = Get.arguments;
    if (diaryArg is Diary) {
      state.diaryContext = diaryArg;
      state.messages[DateTime.now()] = Message(
        role: 'system',
        content:
            '以下是一篇日记的内容，请基于此背景回答用户的问题：\n\n标题：${diaryArg.title}\n内容：${diaryArg.contentText}\n心情指数：${diaryArg.mood}',
      );
      update();
    }
    super.onInit();
  }

  @override
  void onClose() {
    keyboardObserver.stop();
    state.saveDiaryContext();
    state.saveMessages();
    textEditingController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  /// 刷新日记记忆缓存
  Future<void> _refreshMemoryContext() async {
    state.memoryContext = await DiaryMemoryService.buildMemoryContext();
  }

  /// 构建包含人设和记忆的系统提示
  Future<String> _buildSystemPrompt() async {
    final parts = <String>[];

    // 1. 人设信息
    final persona = CompanionPersona.fromPrefs();
    parts.add(persona.toSystemPrompt());

    // 2. 日记记忆（近期日记内容）
    if (state.memoryContext.isNotEmpty) {
      parts.add(state.memoryContext);
    }

    // 3. 用户选中的多篇日记上下文
    if (state.selectedDiaries.isNotEmpty) {
      final buf = StringBuffer('用户选中的以下日记内容供参考：');
      for (final diary in state.selectedDiaries) {
        final dateStr = DateFormat('yyyy-MM-dd').format(diary.time);
        buf.writeln('\n\n[$dateStr] 标题：${diary.title}');
        if (diary.contentText.isNotEmpty) {
          const maxLen = 300;
          final preview = diary.contentText.length > maxLen
              ? '${diary.contentText.substring(0, maxLen)}...'
              : diary.contentText;
          buf.writeln('内容：$preview');
        }
        buf.writeln('心情：${_moodToString(diary.mood)}');
      }
      parts.add(buf.toString());
    }

    // 4. 已有的系统消息（例如从路由传入的日记上下文）
    for (final msg in state.messages.values) {
      if (msg.role == 'system') {
        parts.add(msg.content);
      }
    }

    // 5. AI 分析总结（用户主动触发的日记范围分析）
    if (state.diaryAnalysis != null) {
      parts.add(state.diaryAnalysis!.toSystemPrompt());
    }

    return parts.join('\n\n');
  }

  static String _moodToString(double mood) {
    if (mood >= 0.8) return '非常好';
    if (mood >= 0.6) return '好';
    if (mood >= 0.4) return '一般';
    if (mood >= 0.2) return '不太好';
    return '很差';
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
    state.diaryContext = null;
    state.selectedDiaries = [];
    state.diaryAnalysis = DiaryAnalysis.fromPrefs();
    state.saveMessages();
    state.saveDiaryContext();
    _refreshMemoryContext();
    update();
  }

  void clearText() {
    textEditingController.clear();
  }

  /// 打开日记多选选择器
  Future<void> openDiaryPicker(BuildContext context) async {
    final diaries = await IsarUtil.getAllDiariesSorted();
    if (diaries.isEmpty) {
      toast.info(message: '没有可选的日记');
      return;
    }

    // 已选中的 isarId 集合
    final selectedIds = state.selectedDiaries.map((d) => d.isarId).toSet();

    // 在副本中维护选择状态
    final tempSelected = <Diary>[...state.selectedDiaries];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.library_books_outlined),
                        const SizedBox(width: 8),
                        Text(
                          '选择日记',
                          style: context.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${tempSelected.length}/${AssistantState.maxSelectedDiaries}',
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: diaries.length,
                      itemBuilder: (context, index) {
                        final diary = diaries[index];
                        final isSelected = selectedIds.contains(diary.isarId) ||
                            tempSelected.any((d) => d.isarId == diary.isarId);
                        final isFull = tempSelected.length >=
                                AssistantState.maxSelectedDiaries &&
                            !isSelected;
                        final dateStr =
                            DateFormat('MM/dd').format(diary.time);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: isFull
                              ? null
                              : (_) {
                                  setState(() {
                                    if (isSelected) {
                                      tempSelected.removeWhere(
                                        (d) => d.isarId == diary.isarId,
                                      );
                                      selectedIds.remove(diary.isarId);
                                    } else {
                                      tempSelected.add(diary);
                                      selectedIds.add(diary.isarId);
                                    }
                                  });
                                },
                          secondary: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                context.theme.colorScheme.primaryContainer,
                            child: Text(
                              dateStr,
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context
                                    .theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            diary.title.isEmpty ? '无标题' : diary.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            diary.contentText.length > 50
                                ? '${diary.contentText.substring(0, 50)}...'
                                : diary.contentText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: tempSelected.isEmpty
                              ? null
                              : () {
                                  state.selectedDiaries =
                                      List.from(tempSelected);
                                  state.saveDiaryContext();
                                  update();
                                  Navigator.pop(ctx);
                                },
                          child: Text('添加 (${tempSelected.length})'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 移除选中的日记
  void removeSelectedDiary(Diary diary) {
    state.selectedDiaries.removeWhere((d) => d.isarId == diary.isarId);
    state.saveDiaryContext();
    update();
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
    state.saveMessages();
    update();
    toBottom();

    // 构建系统提示（人设 + 记忆），排除已有的系统消息避免重复
    final systemContent = await _buildSystemPrompt();
    final apiMessages = <Message>[
      Message(role: 'system', content: systemContent),
      ...state.messages.values.where((m) => m.role != 'system'),
    ];

    //带着上下文请求
    final stream = provider == 'anthropic'
        ? await Api.chatWithAnthropic(baseUrl, apiKey, model, apiMessages)
        : await Api.chatWithOpenAI(baseUrl, apiKey, model, apiMessages);

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
    }, onDone: () {
      state.saveMessages();
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
