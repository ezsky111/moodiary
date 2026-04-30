import 'package:intl/intl.dart';
import 'package:moodiary/persistence/isar.dart';

class DiaryMemoryService {
  static const int recentDays = 14;
  static const int maxEntries = 30;
  static const int maxContentLength = 100;

  /// Build a memory context string from recent diary entries.
  /// Returns empty string if no diaries found.
  static Future<String> buildMemoryContext() async {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: recentDays));
    final diaries = await IsarUtil.getDiariesByDateRange(startDate, now);

    if (diaries.isEmpty) return '';

    diaries.sort((a, b) => b.time.compareTo(a.time));
    final limited = diaries.take(maxEntries).toList();

    final buf = StringBuffer('你对用户的近期生活有以下了解：');
    for (final diary in limited) {
      final dateStr = DateFormat('M月d日').format(diary.time);
      buf.writeln('\n\n[$dateStr] ${diary.title}');
      if (diary.contentText.isNotEmpty) {
        final preview = diary.contentText.length > maxContentLength
            ? '${diary.contentText.substring(0, maxContentLength)}...'
            : diary.contentText;
        buf.writeln('内容：$preview');
      }
      buf.writeln('心情：${_moodToString(diary.mood)}');
    }

    return buf.toString();
  }

  static String _moodToString(double mood) {
    if (mood >= 0.8) return '非常好';
    if (mood >= 0.6) return '好';
    if (mood >= 0.4) return '一般';
    if (mood >= 0.2) return '不太好';
    return '很差';
  }
}
