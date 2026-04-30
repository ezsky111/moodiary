import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/pages/diary_details/diary_details_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';

import 'diary_analysis_logic.dart';

class DiaryAnalysisPage extends StatelessWidget {
  const DiaryAnalysisPage({super.key});

  /// 替换分析内容中的 `ID: <uuid>` 为可点击的 markdown 链接
  static String _enrichContent(String content) {
    final uuidPattern = RegExp(r'ID:\s*([a-f0-9\-]{36})');
    return content.replaceAllMapped(uuidPattern, (match) {
      final id = match.group(1)!;
      final shortId = id.substring(0, 8);
      return '[📄 $shortId](https://diary.internal/view/$id)';
    });
  }

  /// 根据 UUID 导航到日记详情页
  static Future<void> _navigateToDiary(String diaryId) async {
    final hash = fastHash(diaryId);
    final diary = await IsarUtil.getDiaryByID(hash);
    if (diary == null) return;
    Bind.lazyPut(() => DiaryDetailsLogic(), tag: diary.id);
    await Get.toNamed(
      AppRoutes.diaryPage,
      arguments: [diary, true],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiaryAnalysisLogic>();
    final state = logic.state;

    return Scaffold(
      appBar: AppBar(
        title: const AdaptiveText('日记分析', isTitle: true),
        leading: const PageBackButton(),
      ),
      body: GetBuilder<DiaryAnalysisLogic>(
        builder: (_) {
          final dateFmt = DateFormat('yyyy年M月d日');
          final rangeText =
              '${dateFmt.format(state.dateRange[0])} 至 ${dateFmt.format(state.dateRange[1])}';

          return Column(
            children: [
              // 日期范围选择
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Card.filled(
                  color: context.theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.date_range,
                            color: context.theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => logic.openDatePicker(context),
                            child: Text(
                              rangeText,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_calendar, size: 20),
                          onPressed: () => logic.openDatePicker(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 操作按钮区域
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed:
                          state.isLoading ? null : () => logic.startAnalysis(),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(state.history.isNotEmpty ? '全量重新生成' : '开始分析'),
                    ),
                    if (state.currentAnalysis != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: state.isLoading
                            ? null
                            : () => logic.startIncrementalAnalysis(),
                        icon: const Icon(Icons.add_chart, size: 18),
                        label: const Text('增量更新'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: state.isLoading
                            ? null
                            : () => logic.deleteAnalysis(
                                state.currentAnalysis!.id),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: '删除当前分析',
                      ),
                    ],
                  ],
                ),
              ),

              // 内容区域
              Expanded(
                child: _buildContent(context, logic, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, DiaryAnalysisLogic logic, dynamic _) {
    final state = logic.state;

    // 加载中：显示流式内容
    if (state.isLoading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 正在分析 ${state.diaries.length} 篇日记...',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (logic.streamingReply.isNotEmpty)
              MarkdownBlock(
                data: _enrichContent(logic.streamingReply),
                config: _buildMarkdownConfig(context),
              ),
          ],
        ),
      );
    }

    // 有分析结果
    if (state.currentAnalysis != null) {
      final analysis = state.currentAnalysis!;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分析头部信息
            Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16, color: context.theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '分析完成（${analysis.diaryCount}篇）— ${DateFormat('M月d日 HH:mm').format(analysis.createdAt)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                _ModeBadge(mode: analysis.mode),
              ],
            ),
            const SizedBox(height: 12),
            MarkdownBlock(
              data: _enrichContent(analysis.content),
              selectable: true,
              config: _buildMarkdownConfig(context),
            ),

            // 历史记录区域
            if (state.history.length > 1) ...[
              const SizedBox(height: 24),
              const Divider(),
              _HistorySection(
                history: state.history,
                currentId: analysis.id,
                onSelect: (a) => logic.selectAnalysis(a),
                onDelete: (a) => _confirmDelete(context, logic, a),
              ),
            ],
          ],
        ),
      );
    }

    // 空状态
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.chartPie,
            size: 48,
            color: context.theme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '选择时间范围，开始分析你的日记',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 Markdown 配置，拦截 diary.internal 链接跳转到日记页
  MarkdownConfig _buildMarkdownConfig(BuildContext context) {
    final base = context.isDarkMode
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    return base.copy(
      configs: [
        LinkConfig(
          onTap: (url) {
            final match =
                RegExp(r'diary\.internal/view/([a-f0-9\-]{36})').firstMatch(url);
            if (match != null) {
              _navigateToDiary(match.group(1)!);
            }
          },
        ),
      ],
    );
  }

  void _confirmDelete(
      BuildContext context, DiaryAnalysisLogic logic, dynamic analysis) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分析记录'),
        content: const Text('确定要删除这条分析记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              logic.deleteAnalysis(analysis.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 分析模式标签
class _ModeBadge extends StatelessWidget {
  final String mode;

  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final isIncremental = mode == 'incremental';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isIncremental
                ? Colors.orange
                : context.theme.colorScheme.primary)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isIncremental ? '增量' : '全量',
        style: context.textTheme.labelSmall?.copyWith(
          color: isIncremental
              ? Colors.orange.shade700
              : context.theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 历史记录列表
class _HistorySection extends StatelessWidget {
  final List<dynamic> history;
  final String currentId;
  final void Function(dynamic) onSelect;
  final void Function(dynamic) onDelete;

  const _HistorySection({
    required this.history,
    required this.currentId,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '历史记录（${history.length}条）',
          style: context.textTheme.titleSmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...history.asMap().entries.map((entry) {
          final analysis = entry.value;
          final isCurrent = analysis.id == currentId;
          final dateFmt = DateFormat('M月d日');
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            color: isCurrent
                ? context.theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.3)
                : null,
            child: ListTile(
              dense: true,
              leading: _ModeBadge(mode: analysis.mode),
              title: Text(
                '${dateFmt.format(analysis.startDate)} 至 ${dateFmt.format(analysis.endDate)}',
                style: context.textTheme.bodySmall,
              ),
              subtitle: Text(
                '${analysis.diaryCount}篇 · ${DateFormat('M月d日 HH:mm').format(analysis.createdAt)}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: context.theme.colorScheme.error,
                ),
                onPressed: () => onDelete(analysis),
              ),
              onTap: isCurrent ? null : () => onSelect(analysis),
            ),
          );
        }),
      ],
    );
  }
}
