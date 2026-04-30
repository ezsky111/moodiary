import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:moodiary/persistence/pref.dart';

class DiaryAnalysis {
  final String content;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final int diaryCount;

  const DiaryAnalysis({
    required this.content,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.diaryCount,
  });

  static const _prefKey = 'diaryAnalysis';

  static DiaryAnalysis? fromPrefs() {
    final jsonStr = PrefUtil.getValue<String>(_prefKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return DiaryAnalysis.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    await PrefUtil.setValue<String>(_prefKey, jsonEncode(toJson()));
  }

  static Future<void> clear() async {
    await PrefUtil.removeValue('diaryAnalysis');
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'diaryCount': diaryCount,
      };

  factory DiaryAnalysis.fromJson(Map<String, dynamic> json) {
    return DiaryAnalysis(
      content: json['content'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      diaryCount: json['diaryCount'] as int? ?? 0,
    );
  }

  String toSystemPrompt() {
    final dateFmt = DateFormat('M月d日');
    return '以下是对用户日记的整体分析总结（${dateFmt.format(startDate)} 至 ${dateFmt.format(endDate)}，共$diaryCount篇）：\n\n$content';
  }
}
