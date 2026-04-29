import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/pages/image/image_view.dart';
import 'package:moodiary/utils/file_util.dart';

class ImageBlockEmbed extends BlockEmbed {
  const ImageBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'image';

  static ImageBlockEmbed fromName(String name) => ImageBlockEmbed(name);

  String get name => data as String;
}

class ImageEmbedBuilder extends EmbedBuilder {
  final bool isEdit;

  /// All image names in the current diary, used for swiping between images
  /// in the preview page. Pass empty list to only show the current image.
  final List<String> allImageNames;

  ImageEmbedBuilder({required this.isEdit, this.allImageNames = const []});

  @override
  String get key => ImageBlockEmbed.embedType;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageEmbed = ImageBlockEmbed(embedContext.node.value.data);
    // 从数据构造 ImageBlockEmbed
    final imagePath =
        isEdit
            ? imageEmbed.name
            : FileUtil.getRealPath('image', imageEmbed.name);
    final image = MoodiaryImage(
      imagePath: imagePath,
      size: 300,
      heroTag: '${imageEmbed.name}0',
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
                  .indexOf(imageEmbed.name)
                  .clamp(0, allImageNames.length - 1);
          showImageView(
            context,
            paths,
            index,
            heroTagPrefix: imageEmbed.name,
          );
        }
      },
    );
    return Center(child: image);
  }
}
