import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/api/api.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'diary_analysis_model.dart';
import 'diary_analysis_state.dart';

class DiaryAnalysisLogic extends GetxController {
  final DiaryAnalysisState state = DiaryAnalysisState();

  /// AI 分析回复内容（流式累积）
  String streamingReply = '';

  @override
  void onInit() {
    super.onInit();
    state.analysis = DiaryAnalysis.fromPrefs();
  }

  /// 打开日期范围选择器
  Future<void> openDatePicker(BuildContext context) async {
    final result = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarViewMode: CalendarDatePicker2Mode.day,
        calendarType: CalendarDatePicker2Type.range,
        selectableDayPredicate: (date) => date.isBefore(DateTime.now()),
      ),
      dialogSize: const Size(325, 400),
      value: state.dateRange,
      borderRadius: BorderRadius.circular(20.0),
    );
    if (result != null && result.length == 2 && result[0] != null && result[1] != null) {
      state.dateRange[0] = result[0]!;
      state.dateRange[1] = result[1]!;
      update();
    }
  }

  /// 检查 AI 配置
  bool _checkAiConfig() {
    final baseUrl = PrefUtil.getValue<String>('aiBaseUrl');
    final apiKey = PrefUtil.getValue<String>('aiKey');
    if (baseUrl == null || apiKey == null || baseUrl.isEmpty || apiKey.isEmpty) {
      toast.info(message: '请先在实验室配置 AI 服务');
      return false;
    }
    return true;
  }

  /// 开始分析
  Future<void> startAnalysis() async {
    if (!_checkAiConfig()) return;

    state.isLoading = true;
    streamingReply = '';
    update();

    try {
      final start = state.dateRange[0];
      final end = state.dateRange[1];

      // 获取时间范围内的日记
      final diaries = await IsarUtil.getDiariesByDateRange(
        DateTime(start.year, start.month, start.day),
        DateTime(end.year, end.month, end.day, 23, 59, 59),
      );

      if (diaries.isEmpty) {
        toast.info(message: '该时间范围内没有日记');
        state.isLoading = false;
        update();
        return;
      }

      diaries.sort((a, b) => a.time.compareTo(b.time));
      state.diaries = diaries;

      // 构建分析提示
      final prompt = _buildAnalysisPrompt(diaries, start, end);

      final provider = PrefUtil.getValue<String>('aiProvider') ?? 'openai';
      final model = PrefUtil.getValue<String>('aiModel') ?? '';
      final baseUrl = PrefUtil.getValue<String>('aiBaseUrl')!;
      final apiKey = PrefUtil.getValue<String>('aiKey')!;

      final stream = provider == 'anthropic'
          ? await Api.chatWithAnthropic(baseUrl, apiKey, model, [
              Message(role: 'user', content: prompt),
            ])
          : await Api.chatWithOpenAI(baseUrl, apiKey, model, [
              Message(role: 'user', content: prompt),
            ]);

      if (stream == null) {
        toast.error(message: 'AI 请求失败');
        state.isLoading = false;
        update();
        return;
      }

      stream.listen(
        (content) {
          if (content.isEmpty) return;
          try {
            String? text;
            if (provider == 'anthropic') {
              text = _parseAnthropicChunk(content);
            } else {
              text = _parseOpenAiChunk(content);
            }
            if (text != null && text.isNotEmpty) {
              streamingReply += text;
              update();
            }
          } catch (_) {
            // Skip malformed chunks
          }
        },
        onDone: () {
          // 流结束，保存分析结果
          final analysis = DiaryAnalysis(
            content: streamingReply,
            startDate: start,
            endDate: end,
            createdAt: DateTime.now(),
            diaryCount: diaries.length,
          );
          analysis.save();
          state.analysis = analysis;
          state.isLoading = false;
          update();
        },
        onError: (e) {
          toast.error(message: '分析出错：$e');
          state.isLoading = false;
          update();
        },
      );
    } catch (e) {
      toast.error(message: '分析失败：$e');
      state.isLoading = false;
      update();
    }
  }

  /// 构建发送给 AI 的分析提示
  String _buildAnalysisPrompt(
    List<dynamic> diaries,
    DateTime start,
    DateTime end,
  ) {
    final dateFmt = DateFormat('yyyy年M月d日');
    final buf = StringBuffer();
    buf.writeln('请对用户在 ${dateFmt.format(start)} 至 ${dateFmt.format(end)} 期间的日记进行全面分析总结。');
    buf.writeln('请涵盖以下几个方面：');
    buf.writeln('- 整体情绪变化趋势');
    buf.writeln('- 重要事件和生活主题');
    buf.writeln('- 各阶段的状态变化');
    buf.writeln('');
    buf.writeln('日记列表（共${diaries.length}篇）：');
    buf.writeln('');

    const maxContentLen = 200;
    for (final diary in diaries) {
      final diaryDate = DateFormat('yyyy-MM-dd').format(diary.time);
      final moodStr = _moodToString(diary.mood);
      buf.writeln('--- ID: ${diary.id} | $diaryDate | ${diary.title} | 心情：$moodStr ---');
      if (diary.contentText.isNotEmpty) {
        final preview = diary.contentText.length > maxContentLen
            ? '${diary.contentText.substring(0, maxContentLen)}...'
            : diary.contentText;
        buf.writeln(preview);
      }
      buf.writeln('');
    }

    buf.writeln('---');
    buf.writeln('请在分析中引用日记ID以便参考，输出应简洁全面，控制在1500字以内。');
    return buf.toString();
  }

  /// 清除分析结果
  Future<void> clearAnalysis() async {
    await DiaryAnalysis.clear();
    state.analysis = null;
    streamingReply = '';
    update();
  }

  static String _moodToString(double mood) {
    if (mood >= 0.8) return '非常好';
    if (mood >= 0.6) return '好';
    if (mood >= 0.4) return '一般';
    if (mood >= 0.2) return '不太好';
    return '很差';
  }

  String? _parseOpenAiChunk(String content) {
    if (!content.contains('data')) return null;
    if (content.contains('[DONE]')) return null;
    final data = jsonDecode(content.split('data: ')[1]) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    final delta = choices[0]['delta'] as Map<String, dynamic>?;
    return delta?['content'] as String?;
  }

  String? _parseAnthropicChunk(String content) {
    if (!content.contains('data:')) return null;
    final jsonStr = content.split('data: ').last.trim();
    if (!jsonStr.startsWith('{')) return null;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (data['type'] != 'content_block_delta') return null;
    final delta = data['delta'] as Map<String, dynamic>?;
    if (delta != null && delta['type'] == 'text_delta') {
      return delta['text'] as String?;
    }
    return null;
  }
}
