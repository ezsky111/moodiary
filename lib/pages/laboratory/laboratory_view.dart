import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/tile/qr_tile.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'laboratory_logic.dart';

class LaboratoryPage extends StatelessWidget {
  const LaboratoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<LaboratoryLogic>();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingLab)),
      body: GetBuilder<LaboratoryLogic>(
        builder: (_) {
          final currentProvider =
              PrefUtil.getValue<String>('aiProvider') ?? 'openai';
          final currentBaseUrl =
              PrefUtil.getValue<String>('aiBaseUrl') ?? '';
          final currentAiKey =
              PrefUtil.getValue<String>('aiKey') ?? '';

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            children: [
              // AI Provider section
              Card.filled(
                color: context.theme.colorScheme.surfaceContainerLow,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 服务',
                        style: context.textTheme.titleMedium,
                      ),
                      const Gap(12),
                      Text(
                        '提供商',
                        style: context.textTheme.labelMedium,
                      ),
                      const Gap(8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'openai',
                            label: Text('OpenAI'),
                            icon: Icon(Icons.auto_awesome),
                          ),
                          ButtonSegment(
                            value: 'anthropic',
                            label: Text('Anthropic'),
                            icon: Icon(Icons.smart_toy),
                          ),
                        ],
                        selected: {currentProvider},
                        onSelectionChanged: (selected) {
                          logic.setAiProvider(selected.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(12),
              QrInputTile(
                title: 'AI Base URL',
                value: currentBaseUrl,
                prefix: 'aiBaseUrl',
                onValue: (value) async {
                  final res = await logic.setAiBaseUrl(value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: 'AI Key',
                value: currentAiKey,
                prefix: 'aiKey',
                onValue: (value) async {
                  final res = await logic.setAiKey(value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),

              // Qweather section
              QrInputTile(
                title: '${context.l10n.labQweather} Key',
                value: PrefUtil.getValue<String>('qweatherKey') ?? '',
                prefix: 'qweatherKey',
                onValue: (value) async {
                  final res = await logic.setQweatherKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labQweather} API Host',
                value: PrefUtil.getValue<String>('qweatherApiHost') ?? '',
                prefix: 'qweatherApiHost',
                onValue: (value) async {
                  final res = await logic.setQweatherApiHost(host: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),

              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labTianditu} Key',
                value: PrefUtil.getValue<String>('tiandituKey') ?? '',
                prefix: 'tiandituKey',
                onValue: (value) async {
                  final res = await logic.setTiandituKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  logic.exportErrorLog();
                },
                title: const Text('导出日志文件'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = await logic.aesTest();
                  if (res) {
                    toast.success(message: '加密测试通过');
                  } else {
                    toast.error(message: '加密测试失败');
                  }
                },
                title: const Text('加密测试'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = await logic.clearImageThumbnail();
                  if (res) {
                    toast.success(message: '清理成功');
                  } else {
                    toast.error(message: '清理失败');
                  }
                },
                title: const Text('清理图片缩略图缓存'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = logic.generateFTSAndKeyword();
                  if (res) {
                    toast.success(message: '重新生成成功');
                  } else {
                    toast.error(message: '重新生成失败');
                  }
                },
                title: const Text('重新进行全文搜索索引'),
              ),
            ],
          );
        },
      ),
    );
  }
}
