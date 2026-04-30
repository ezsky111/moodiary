import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

class CompanionPersona {
  final String name;
  final String personality;
  final String speakingStyle;
  final String relationship;

  const CompanionPersona({
    this.name = '小M',
    this.personality = '温柔、善解人意',
    this.speakingStyle = '用温暖亲切的语气，偶尔使用表情符号',
    this.relationship = '你',
  });

  static const _prefKey = 'companionPersona';

  static CompanionPersona fromPrefs() {
    final jsonStr = PrefUtil.getValue<String>(_prefKey);
    if (jsonStr == null || jsonStr.isEmpty) return const CompanionPersona();
    try {
      return CompanionPersona.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return const CompanionPersona();
    }
  }

  Future<void> save() async {
    await PrefUtil.setValue<String>(_prefKey, jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'personality': personality,
        'speakingStyle': speakingStyle,
        'relationship': relationship,
      };

  factory CompanionPersona.fromJson(Map<String, dynamic> json) {
    return CompanionPersona(
      name: json['name'] as String? ?? '小M',
      personality: json['personality'] as String? ?? '温柔、善解人意',
      speakingStyle: json['speakingStyle'] as String? ?? '用温暖亲切的语气，偶尔使用表情符号',
      relationship: json['relationship'] as String? ?? '你',
    );
  }

  String toSystemPrompt() {
    return '你是一位用户的 AI 日记伴侣，负责陪伴用户、倾听用户的心事、与用户聊天。\n\n'
        '你的人设信息：\n'
        '- 名字：$name\n'
        '- 性格：$personality\n'
        '- 说话风格：$speakingStyle\n'
        '- 对用户的称呼：$relationship\n\n'
        '请严格按照以上人设与用户对话，自然地聊用户日记中记载的生活点滴。';
  }

  static Future<void> showSettingsDialog(BuildContext context) async {
    final persona = fromPrefs();
    final nameCtrl = TextEditingController(text: persona.name);
    final personalityCtrl = TextEditingController(text: persona.personality);
    final styleCtrl = TextEditingController(text: persona.speakingStyle);
    final relationCtrl = TextEditingController(text: persona.relationship);

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('伴侣人设'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名字',
                    hintText: '例如：小M',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: personalityCtrl,
                  decoration: const InputDecoration(
                    labelText: '性格',
                    hintText: '例如：温柔、善解人意',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: styleCtrl,
                  decoration: const InputDecoration(
                    labelText: '说话风格',
                    hintText: '例如：用温暖亲切的语气，偶尔使用表情符号',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationCtrl,
                  decoration: const InputDecoration(
                    labelText: '对你的称呼',
                    hintText: '例如：你、主人、朋友',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final updated = CompanionPersona(
                  name: nameCtrl.text.isNotEmpty ? nameCtrl.text : '小M',
                  personality:
                      personalityCtrl.text.isNotEmpty ? personalityCtrl.text : '温柔、善解人意',
                  speakingStyle: styleCtrl.text.isNotEmpty
                      ? styleCtrl.text
                      : '用温暖亲切的语气，偶尔使用表情符号',
                  relationship:
                      relationCtrl.text.isNotEmpty ? relationCtrl.text : '你',
                );
                await updated.save();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  toast.success(message: '人设已保存');
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}
