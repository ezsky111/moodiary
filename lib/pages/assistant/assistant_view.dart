import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'assistant_logic.dart';
import 'companion_persona.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  /// Normalize single newlines to double newlines for proper markdown rendering.
  /// In markdown, a single \n does not create a visible line break — it's treated
  /// as a space. Converting isolated \n to \n\n ensures paragraph breaks render.
  static String _formatContent(String content) {
    if (content.isEmpty) return content;
    return content.replaceAllMapped(
      RegExp(r'(?<!\n)\n(?!\n)'),
      (_) => '\n\n',
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AssistantLogic>();
    final state = Bind.find<AssistantLogic>().state;

    Widget buildInput() {
      return Container(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                focusNode: logic.focusNode,
                controller: logic.textEditingController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  fillColor: context.theme.colorScheme.surfaceContainerHighest,
                  filled: true,
                  isDense: true,
                  hintText: '消息',
                  border: const OutlineInputBorder(
                    borderRadius: AppBorderRadius.largeBorderRadius,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton.filled(
              onPressed: () {
                logic.checkGetAi();
              },
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      );
    }

    Widget buildChat() {
      return SliverPadding(
        padding: const EdgeInsets.all(4.0),
        sliver: SliverList.builder(
          itemBuilder: (context, index) {
            final timeList = state.messages.keys.toList();
            final messageList = state.messages.values.toList();
            if (messageList[index].role == 'user') {
              return Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 8.0,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.circleQuestion,
                            size: 16.0,
                          ),
                          Text(DateFormat.jms().format(timeList[index])),
                        ],
                      ),
                      MarkdownBlock(
                        data: _formatContent(messageList[index].content),
                        selectable: true,
                        config:
                            context.isDarkMode
                                ? MarkdownConfig.darkConfig
                                : MarkdownConfig.defaultConfig,
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Card.filled(
                color: context.theme.colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 8.0,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.bots,
                            color: context.theme.colorScheme.tertiary,
                          ),
                          Text(DateFormat.jms().format(timeList[index])),
                        ],
                      ),
                      MarkdownBlock(
                        data: _formatContent(messageList[index].content),
                        selectable: true,
                        config:
                            context.isDarkMode
                                ? MarkdownConfig.darkConfig
                                : MarkdownConfig.defaultConfig,
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          itemCount: state.messages.length,
        ),
      );
    }

    Widget buildEmpty() {
      return const Center(child: FaIcon(FontAwesomeIcons.comments, size: 46.0));
    }

    Future<void> showModelPicker(BuildContext context) async {
      final result = await showTextInputDialog(
        context: context,
        textFields: [
          DialogTextField(
            initialText: state.aiModel.value,
            hintText: '例如: gpt-4o, claude-3-sonnet-20240229',
          ),
        ],
        title: '设置模型名称',
        message: '请输入 AI 模型名称',
        style: AdaptiveStyle.material,
      );
      if (result != null && result.first.isNotEmpty) {
        logic.changeModel(result.first);
      }
    }

    return GetBuilder<AssistantLogic>(
      builder: (_) {
        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        controller: logic.scrollController,
                        slivers: [
                          SliverAppBar(
                            title: AdaptiveText(
                              context.l10n.settingFunctionAIAssistant,
                              isTitle: true,
                            ),
                            pinned: true,
                            leading: const PageBackButton(),
                            actions: [
                              GestureDetector(
                                onTap: () => showModelPicker(context),
                                child: Obx(() {
                                  return Text(
                                    state.aiModel.value.isNotEmpty
                                        ? state.aiModel.value
                                        : '选择模型',
                                  );
                                }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_outline),
                                onPressed: () =>
                                    CompanionPersona.showSettingsDialog(context),
                                tooltip: '伴侣人设',
                              ),
                              IconButton(
                                icon: const Icon(Icons.analytics_outlined),
                                onPressed: () => Get.toNamed('/assistant/analysis'),
                                tooltip: '日记分析',
                              ),
                              IconButton(
                                onPressed: () {
                                  logic.newChat();
                                },
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                          buildChat(),
                        ],
                      ),
                    ),
                    buildInput(),
                  ],
                ),
              ),
              if (state.messages.isEmpty) ...[buildEmpty()],
            ],
          ),
        );
      },
    );
  }
}
