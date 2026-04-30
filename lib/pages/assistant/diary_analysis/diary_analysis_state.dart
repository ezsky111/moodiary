import 'package:moodiary/common/models/isar/diary.dart';

import 'diary_analysis_model.dart';

class DiaryAnalysisState {
  /// 选中的时间范围 [start, end]
  late List<DateTime> dateRange;

  /// 当前显示的分析结果（最新的一条或用户从历史中选择的）
  DiaryAnalysis? currentAnalysis;

  /// 历史记录列表（最新在前）
  List<DiaryAnalysis> history = [];

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
