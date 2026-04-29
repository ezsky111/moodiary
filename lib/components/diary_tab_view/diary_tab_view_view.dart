import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/components/base/clipper.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/diary_card/grid_diary_card_view.dart';
import 'package:moodiary/components/diary_card/list_diary_card_view.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import 'diary_tab_view_logic.dart';

class DiaryTabViewComponent extends StatelessWidget {
  const DiaryTabViewComponent({super.key, required this.categoryId});

  final String? categoryId;

  Widget _buildPlaceholder(double height) {
    return SliverToBoxAdapter(
      key: const ValueKey('placeholder'),
      child: SizedBox(height: height, child: const MoodiaryLoading()),
    );
  }

  Widget _buildEmpty(BuildContext context, double height) {
    return SliverToBoxAdapter(
      key: const ValueKey('empty'),
      child: SizedBox(
        height: height,
        child: Center(child: Text(context.l10n.diaryTabViewEmpty)),
      ),
    );
  }

  /// Build a year section header widget
  Widget _buildYearHeader(BuildContext context, int year) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
      child: Text(
        '$year',
        style: context.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: context.theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logicTag = categoryId ?? 'default';
    final barHeight = 46 + kToolbarHeight + MediaQuery.paddingOf(context).top;
    final logic = Get.put(
      DiaryTabViewLogic(categoryId: categoryId),
      tag: logicTag,
    );
    final state = Bind.find<DiaryTabViewLogic>(tag: logicTag).state;
    final size = MediaQuery.sizeOf(context);
    final placeholderHeight =
        size.height -
        barHeight -
        MediaQuery.paddingOf(context).bottom -
        56 -
        46;

    Widget buildGrid() {
      return Obx(() {
        return SliverWaterfallFlow(
          gridDelegate: const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return GirdDiaryCardComponent(diary: state.diaryList[index]);
          }, childCount: state.diaryList.length),
        );
      }, key: const ValueKey('grid'));
    }

    Widget buildList() {
      return Obx(() {
        final diaries = state.diaryList;
        // Build flat list: year headers + diary cards
        final items = <({int? year, Diary? diary})>[];
        int? lastYear;
        for (final diary in diaries) {
          final year = diary.time.year;
          if (year != lastYear) {
            items.add((year: year, diary: null));
            lastYear = year;
          }
          items.add((year: null, diary: diary));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              if (item.diary == null) {
                return _buildYearHeader(context, item.year!);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ListDiaryCardComponent(
                  tag: index.toString(),
                  diary: item.diary!,
                ),
              );
            },
            childCount: items.length,
          ),
        );
      }, key: const ValueKey('list'));
    }

    final sliverHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
      context,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      child: ClipRRect(
        clipper: TopRRectClipper(
          topOffset: sliverHandle.layoutExtent ?? barHeight,
        ),
        child: CustomScrollView(
          cacheExtent: size.height * 2,
          slivers: [
            SliverOverlapInjector(handle: sliverHandle),
            Obx(() {
              return SliverAnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                reverseDuration: const Duration(milliseconds: 100),
                child:
                    state.isFetching.value
                        ? _buildPlaceholder(placeholderHeight)
                        : state.diaryList.isEmpty
                        ? _buildEmpty(context, placeholderHeight)
                        : switch (logic.diaryLogic.state.viewModeType.value) {
                          ViewModeType.list => buildList(),
                          ViewModeType.grid => buildGrid(),
                        },
              );
            }),
          ],
        ),
      ),
    );
  }
}
