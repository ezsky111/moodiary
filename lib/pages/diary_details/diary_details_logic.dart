import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/api/api.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'diary_details_state.dart';

class DiaryDetailsLogic extends GetxController {
  final DiaryDetailsState state = DiaryDetailsState();

  //点击分享跳转到分享页面
  Future<void> toSharePage() async {
    Get.toNamed(AppRoutes.sharePage, arguments: state.diary);
  }

  //编辑日记
  Future<void> toEditPage(Diary diary) async {
    //这里参数为diary，表示编辑日记，等待跳转结果为changed，重新获取日记
    if ((await Get.toNamed(AppRoutes.editPage, arguments: diary.clone())) ==
        'changed') {
      //重新获取日记
      state.diary = (await IsarUtil.getDiaryByID(state.diary.isarId))!;
      update();
    }
  }

  //放入回收站
  Future<void> delete(Diary diary) async {
    final newDiary = diary.clone()..show = false;
    await IsarUtil.updateADiary(oldDiary: diary, newDiary: newDiary);
    Get.back(result: 'delete');
  }

  //检查 AI 配置
  bool _checkAiConfig() {
    final baseUrl = PrefUtil.getValue<String>('aiBaseUrl');
    final apiKey = PrefUtil.getValue<String>('aiKey');
    if (baseUrl == null || apiKey == null || baseUrl.isEmpty || apiKey.isEmpty) {
      toast.info(message: '请先在实验室配置 AI 服务');
      return false;
    }
    return true;
  }

  //收集 AI 流式响应全文
  Future<String> _collectAiResponse(
    String provider,
    String baseUrl,
    String apiKey,
    String model,
    List<Message> messages,
  ) async {
    final stream = provider == 'anthropic'
        ? await Api.chatWithAnthropic(baseUrl, apiKey, model, messages)
        : await Api.chatWithOpenAI(baseUrl, apiKey, model, messages);

    if (stream == null) return '';

    final completer = Completer<String>();
    final buffer = StringBuffer();

    stream.listen(
      (content) {
        if (content.isEmpty) return;
        if (provider == 'anthropic') {
          _parseAnthropicChunk(content, buffer);
        } else {
          _parseOpenAiChunk(content, buffer);
        }
      },
      onDone: () => completer.complete(buffer.toString()),
      onError: (e) => completer.complete(buffer.toString()),
    );

    return completer.future;
  }

  void _parseOpenAiChunk(String content, StringBuffer buffer) {
    if (!content.contains('data')) return;
    if (content.contains('[DONE]')) return;

    try {
      final data =
          jsonDecode(content.split('data: ')[1]) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return;
      final delta = choices[0]['delta'] as Map<String, dynamic>?;
      final text = delta?['content'] as String? ?? '';
      buffer.write(text);
    } catch (_) {}
  }

  void _parseAnthropicChunk(String content, StringBuffer buffer) {
    try {
      if (content.contains('data:')) {
        final jsonStr = content.split('data: ').last.trim();
        if (jsonStr.startsWith('{')) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = data['type'] as String?;
          if (type == 'content_block_delta') {
            final delta = data['delta'] as Map<String, dynamic>?;
            if (delta != null && delta['type'] == 'text_delta') {
              buffer.write(delta['text'] as String? ?? '');
            }
          }
        }
      }
    } catch (_) {}
  }

  //AI 润色
  Future<void> aiPolish({
    required BuildContext context,
    required bool setTitle,
    required bool setMood,
    required bool setCategory,
  }) async {
    if (!_checkAiConfig()) return;

    final diary = state.diary;
    final provider = PrefUtil.getValue<String>('aiProvider') ?? 'openai';
    final model = PrefUtil.getValue<String>('aiModel') ?? '';
    final baseUrl = PrefUtil.getValue<String>('aiBaseUrl')!;
    final apiKey = PrefUtil.getValue<String>('aiKey')!;

    final prompt = StringBuffer();
    prompt.writeln('你是一个日记润色助手。请根据以下日记内容，执行指定的操作。');
    prompt.writeln('请以JSON格式返回结果，只返回JSON，不要包含其他内容。');
    prompt.writeln();

    if (diary.title.isNotEmpty) {
      prompt.writeln('当前标题：${diary.title}');
    }
    prompt.writeln('日记内容：${diary.contentText}');
    prompt.writeln('当前心情指数：${diary.mood}（0-1之间，0代表最差，1代表最好）');
    prompt.writeln();

    if (setCategory) {
      final categories = await IsarUtil.getAllCategoryAsync();
      if (categories.isNotEmpty) {
        prompt.writeln('当前可用分类：');
        for (final cat in categories) {
          prompt.writeln('- ${cat.categoryName} (ID: ${cat.id})');
        }
        prompt.writeln();
      }
    }

    final List<String> instructions = [];
    if (setTitle) {
      instructions.add(
        '"title": "根据内容生成一个简洁的标题，不要加书名号"',
      );
    }
    if (setMood) {
      instructions.add(
        '"mood": 分析内容给出心情值(0-1之间，一位小数)',
      );
    }
    if (setCategory) {
      instructions.add(
        '"categoryId": "从当前可用分类中选择最合适的ID，不设置则为空字符串"',
      );
    }

    prompt.writeln('请返回以下JSON字段：{${instructions.join(', ')}}');

    final messages = [
      const Message(role: 'system', content: '你是一个专业的日记润色助手。'),
      Message(role: 'user', content: prompt.toString()),
    ];

    final response = await _collectAiResponse(
      provider,
      baseUrl,
      apiKey,
      model,
      messages,
    );

    if (response.isEmpty) {
      if (context.mounted) {
        toast.error(message: 'AI 响应为空');
      }
      return;
    }

    await _applyPolishResult(
      response,
      setTitle: setTitle,
      setMood: setMood,
      setCategory: setCategory,
    );
  }

  Future<void> _applyPolishResult(
    String response, {
    required bool setTitle,
    required bool setMood,
    required bool setCategory,
  }) async {
    try {
      // Extract JSON from response (handle markdown code blocks)
      var jsonStr = response.trim();
      if (jsonStr.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(
          jsonStr,
        );
        if (match != null) {
          jsonStr = match.group(1)!.trim();
        }
      }

      // Find JSON object boundaries
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace > firstBrace) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final newDiary = state.diary.clone();
      var hasChanges = false;

      if (setTitle && data.containsKey('title')) {
        final title = data['title'] as String?;
        if (title != null && title.isNotEmpty) {
          newDiary.title = title;
          hasChanges = true;
        }
      }
      if (setMood && data.containsKey('mood')) {
        final mood = data['mood'];
        if (mood is num) {
          newDiary.mood = mood.toDouble().clamp(0.0, 1.0);
          hasChanges = true;
        }
      }
      if (setCategory && data.containsKey('categoryId')) {
        final categoryId = data['categoryId'] as String?;
        newDiary.categoryId = (categoryId != null && categoryId.isNotEmpty)
            ? categoryId
            : null;
        hasChanges = true;
      }

      if (!hasChanges) {
        toast.info(message: '未能解析 AI 返回结果');
        return;
      }

      await IsarUtil.updateADiary(oldDiary: state.diary, newDiary: newDiary);
      state.diary = (await IsarUtil.getDiaryByID(state.diary.isarId))!;
      update();

      toast.success(message: 'AI 润色完成');
    } catch (e) {
      toast.error(message: 'AI 润色失败：${e.toString()}');
    }
  }

  //AI 聊天
  Future<void> aiChat(Diary diary) async {
    if (!_checkAiConfig()) return;
    Get.toNamed(AppRoutes.assistantPage, arguments: diary);
  }
}
