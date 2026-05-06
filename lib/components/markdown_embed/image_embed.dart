import 'package:flutter/material.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/pages/image/image_view.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:uuid/uuid.dart';

class MarkdownImageEmbed extends StatelessWidget {
  final bool isEdit;
  final String imageName;

  /// All image names in the current diary, used for swiping between images
  /// in the preview page. Pass empty list to only show the current image.
  final List<String> allImageNames;

  const MarkdownImageEmbed({
    super.key,
    required this.isEdit,
    required this.imageName,
    this.allImageNames = const [],
  });

  @override
  Widget build(BuildContext context) {
    final imagePath =
        isEdit ? imageName : FileUtil.getRealPath('image', imageName);
    final heroPrefix = const Uuid().v4();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return MoodiaryImage(
          imagePath: imagePath,
          size: 300,
          maxWidth: maxWidth > 0 && maxWidth.isFinite ? maxWidth : null,
          heroTag: '${heroPrefix}0',
          borderRadius: AppBorderRadius.mediumBorderRadius,
          showBorder: true,
          padding: const EdgeInsets.all(8.0),
          onTap: () {
            if (!isEdit) {
              final paths = allImageNames.isEmpty
                  ? [imagePath]
                  : allImageNames
                      .map((name) => FileUtil.getRealPath('image', name))
                      .toList();
              final index = allImageNames.isEmpty
                  ? 0
                  : allImageNames
                      .indexOf(imageName)
                      .clamp(0, allImageNames.length - 1);
              showImageView(context, paths, index, heroTagPrefix: heroPrefix);
            }
          },
        );
      },
    );
  }
}
