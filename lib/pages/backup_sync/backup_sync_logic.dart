import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/xlsx_util.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupSyncLogic extends GetxController {
  /// 尝试刷新首页数据
  Future<void> _refreshHomePage() async {
    if (Get.isRegistered<DiaryLogic>()) {
      try {
        await Get.find<DiaryLogic>().refreshAll();
      } catch (_) {
        // 刷新失败不影响导入结果
      }
    }
  }
  Future<void> exportFile() async {
    toast.info(message: '正在处理中');
    final dataPath = FileUtil.getRealPath('', '');
    final zipPath = FileUtil.getCachePath('');
    final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
    final path = await FileUtil.zipFileUseRust(isolateParams);
    final res = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)]),
    );
    if (res.status == ShareResultStatus.success) {
      await File(path).delete();
    }
  }

  //导入
  Future<void> import() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['zip'],
      type: FileType.custom,
    );
    if (result != null) {
      toast.info(message: '数据导入中，请不要离开页面');
      await FileUtil.extractFile(result.files.single.path!);
      toast.success(message: '导入成功，请重启应用');
    } else {
      toast.info(message: '取消文件选择');
    }
  }

  /// 下载 Excel 导入模板
  Future<void> downloadXlsxTemplate() async {
    try {
      final rows = [
        ['日期 (Date)', '内容 (Content)'],
        ['2024/01/01 12:00', '今天开始了第一篇日记！'],
      ];
      final bytes = XlsxUtil.createWorkbook(rows);

      if (bytes.isEmpty) {
        toast.error(message: '生成模板失败');
        return;
      }

      final dir = await getApplicationCacheDirectory();
      final path = p.join(dir.path, '日记导入模板.xlsx');
      await File(path).writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)]),
      );
    } catch (e) {
      toast.error(message: '下载模板失败：$e');
    }
  }

  /// 从 Excel 文件导入日记
  Future<void> importFromXlsx() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['xlsx'],
      type: FileType.custom,
    );

    if (result == null || result.files.single.path == null) {
      toast.info(message: '取消文件选择');
      return;
    }

    toast.info(message: '正在导入日记...');

    try {
      final bytes = await File(result.files.single.path!).readAsBytes();
      final rows = XlsxUtil.parseBytes(bytes);

      if (rows.isEmpty) {
        toast.error(message: 'Excel 文件中没有数据');
        return;
      }

      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 2) continue;

        final dateStr = row[0].trim();
        final content = row[1].trim();

        // 跳过标题行
        if (i == 0 && _isHeaderRow(dateStr, content)) continue;
        if (content.isEmpty) {
          errorCount++;
          continue;
        }

        final dateTime = _parseDateTime(dateStr);
        if (dateTime == null) {
          errorCount++;
          continue;
        }

        try {
          final title =
              content.length > 50 ? content.substring(0, 50) : content;
          // Quill Delta 格式：type=text/richText 的日记 content 需为 Delta JSON
          final delta = [
            {'insert': '$content\n'},
          ];
          final diary = Diary()
            ..title = title
            ..content = jsonEncode(delta)
            ..contentText = content
            ..time = dateTime
            ..lastModified = dateTime
            ..type = DiaryType.text.value
            ..show = true;

          await IsarUtil.insertADiary(diary);
          successCount++;
        } catch (e) {
          errorCount++;
        }
      }

      // 刷新首页数据
      await _refreshHomePage();

      if (errorCount > 0) {
        toast.info(
          message: '导入完成：成功 $successCount 条，失败 $errorCount 条',
        );
      } else {
        toast.success(message: '成功导入 $successCount 条日记');
      }
    } catch (e) {
      toast.error(message: '导入失败：$e');
    }
  }

  bool _isHeaderRow(String colA, String colB) {
    return (colA.contains('日期') ||
            colA.contains('Date') ||
            colA.contains('date')) ||
        (colB.contains('内容') ||
            colB.contains('Content') ||
            colB.contains('content'));
  }

  DateTime? _parseDateTime(String dateStr) {
    if (dateStr.isEmpty) return null;

    const formats = [
      'yyyy/MM/dd HH:mm',
      'yyyy-MM-dd HH:mm',
      'yyyy/MM/dd',
      'yyyy-MM-dd',
      'yyyyMMdd HH:mm',
      'yyyyMMdd',
      'MM/dd/yyyy HH:mm',
      'M/d/yyyy HH:mm',
      'yyyy/M/d HH:mm',
      'yyyy-M-d HH:mm',
      'MM/dd/yyyy',
      'M/d/yyyy',
      'yyyy/M/d',
      'yyyy-M-d',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(dateStr);
      } catch (_) {
        continue;
      }
    }

    return DateTime.tryParse(dateStr);
  }
}
