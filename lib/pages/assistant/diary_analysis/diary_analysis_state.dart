import 'package:moodiary/common/models/isar/diary.dart';

import 'diary_analysis_model.dart';

class DiaryAnalysisState {
  /// 选中的时间范围 [start, end]
  late List<DateTime> dateRange;

  /// AI 分析结果
  DiaryAnalysis? analysis;

  /// 是否正在生成分析
  bool isLoading = false;

  /// 当前范围内的日记列表
  List<Diary> diaries = [];

  DiaryAnalysisState() {
    final now = DateTime.now();
    dateRange = [
      DateTime(now.year, now.month - 1, now.day),
      DateTime(now.year, now.month, now.day),
    ];
  }
}
