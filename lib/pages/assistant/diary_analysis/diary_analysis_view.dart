import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/text.dart';

import 'diary_analysis_logic.dart';

class DiaryAnalysisPage extends StatelessWidget {
  const DiaryAnalysisPage({super.key});

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: context.theme.colorScheme.primary),
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
                      onPressed: state.isLoading ? null : () => logic.startAnalysis(),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(state.analysis != null ? '重新生成' : '开始分析'),
                    ),
                    if (state.analysis != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: state.isLoading ? null : () => logic.clearAnalysis(),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清除结果'),
                      ),
                    ],
                  ],
                ),
              ),

              // 分析结果显示
              Expanded(
                child: _buildContent(context, logic, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, DiaryAnalysisLogic logic, _) {
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
              MarkdownBlock(data: logic.streamingReply),
          ],
        ),
      );
    }

    // 有分析结果
    if (state.analysis != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: context.theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '分析完成（${state.analysis!.diaryCount}篇）— ${DateFormat('M月d日 HH:mm').format(state.analysis!.createdAt)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MarkdownBlock(
              data: state.analysis!.content,
              selectable: true,
              config: context.isDarkMode
                  ? MarkdownConfig.darkConfig
                  : MarkdownConfig.defaultConfig,
            ),
          ],
        ),
      );
    }

    // 空状态
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(FontAwesomeIcons.chartPie, size: 48, color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
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
}
