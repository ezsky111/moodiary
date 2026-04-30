import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:uuid/uuid.dart';

class DiaryAnalysis {
  final String id;
  final String content;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final int diaryCount;
  final String mode; // 'full' or 'incremental'

  const DiaryAnalysis({
    required this.id,
    required this.content,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.diaryCount,
    this.mode = 'full',
  });

  static const _historyKey = 'diaryAnalysisHistory';
  static const _oldKey = 'diaryAnalysis';
  static const _uuid = Uuid();

  /// 创建新的分析记录（自动生成 id）
  factory DiaryAnalysis.create({
    required String content,
    required DateTime startDate,
    required DateTime endDate,
    required int diaryCount,
    String mode = 'full',
  }) {
    return DiaryAnalysis(
      id: _uuid.v4(),
      content: content,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
      diaryCount: diaryCount,
      mode: mode,
    );
  }

  /// 获取历史记录列表（最新在前）
  static List<DiaryAnalysis> getHistory() {
    _migrateIfNeeded();
    final jsonStr = PrefUtil.getValue<String>(_historyKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => DiaryAnalysis.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取最新的分析结果
  static DiaryAnalysis? getLatest() {
    final history = getHistory();
    return history.isNotEmpty ? history.first : null;
  }

  /// 向后兼容
  static DiaryAnalysis? fromPrefs() => getLatest();

  /// 保存当前对象到历史记录
  Future<void> save() async {
    final history = DiaryAnalysis.getHistory();
    final idx = history.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      history[idx] = this;
    } else {
      history.insert(0, this);
    }
    await _saveHistory(history);
  }

  /// 删除指定 id 的分析记录
  static Future<bool> deleteById(String id) async {
    final history = getHistory();
    final before = history.length;
    history.removeWhere((a) => a.id == id);
    if (history.length == before) return false;
    await _saveHistory(history);
    return true;
  }

  /// 保存历史列表到 prefs
  static Future<void> _saveHistory(List<DiaryAnalysis> history) async {
    final jsonStr = jsonEncode(history.map((a) => a.toJson()).toList());
    await PrefUtil.setValue<String>(_historyKey, jsonStr);
  }

  /// 从旧 key 迁移单条数据
  static void _migrateIfNeeded() {
    final oldJson = PrefUtil.getValue<String>(_oldKey);
    if (oldJson == null || oldJson.isEmpty) return;
    try {
      final currentData = PrefUtil.getValue<String>(_historyKey);
      if (currentData == null || currentData.isEmpty) {
        final oldData = jsonDecode(oldJson) as Map<String, dynamic>;
        final migrated = DiaryAnalysis.fromJson(oldData);
        _saveHistory([migrated]);
      }
      PrefUtil.removeValue(_oldKey);
    } catch (_) {}
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'diaryCount': diaryCount,
        'mode': mode,
      };

  factory DiaryAnalysis.fromJson(Map<String, dynamic> json) {
    return DiaryAnalysis(
      id: json['id'] as String? ?? _uuid.v4(),
      content: json['content'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      diaryCount: json['diaryCount'] as int? ?? 0,
      mode: json['mode'] as String? ?? 'full',
    );
  }

  String toSystemPrompt() {
    final dateFmt = DateFormat('M月d日');
    return '以下是对用户日记的整体分析总结（${dateFmt.format(startDate)} 至 ${dateFmt.format(endDate)}，共$diaryCount篇）：\n\n$content';
  }
}
