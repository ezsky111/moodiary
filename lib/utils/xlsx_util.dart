import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxUtil {
  /// 创建一个简单的 XLSX 工作簿，返回字节数组
  static List<int> createWorkbook(List<List<String>> rows) {
    final archive = Archive();

    final sheetBuffer = StringBuffer();
    sheetBuffer.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );

    for (int r = 0; r < rows.length; r++) {
      final rowNum = r + 1;
      sheetBuffer.write('<row r="$rowNum">');
      for (int c = 0; c < rows[r].length; c++) {
        final colLetter = _columnLetter(c);
        final value = rows[r][c];
        sheetBuffer.write(
          '<c r="$colLetter$rowNum" t="inlineStr"><is><t>'
          '${_escapeXml(value)}'
          '</t></is></c>',
        );
      }
      sheetBuffer.writeln('</row>');
    }

    sheetBuffer.writeln('</sheetData></worksheet>');

    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

    const workbook = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="日记" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

    const workbookRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';

    archive.addFile(ArchiveFile.string('[Content_Types].xml', contentTypes));
    archive.addFile(ArchiveFile.string('_rels/.rels', rels));
    archive.addFile(ArchiveFile.string('xl/workbook.xml', workbook));
    archive.addFile(
      ArchiveFile.string('xl/_rels/workbook.xml.rels', workbookRels),
    );
    archive.addFile(
      ArchiveFile.string('xl/worksheets/sheet1.xml', sheetBuffer.toString()),
    );

    return ZipEncoder().encode(archive);
  }

  /// 解析 XLSX 文件的字节数据，返回所有行
  static List<List<String>> parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final result = <List<String>>[];

    // 解析共享字符串（如果存在）
    final sharedStrings = <String>[];
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      final ssXml = XmlDocument.parse(utf8.decode(ssFile.content));
      for (final si in ssXml.findAllElements('si')) {
        final ts = si.findElements('t');
        sharedStrings.add(ts.isNotEmpty ? ts.first.innerText : '');
      }
    }

    // 解析工作表
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) return result;

    final sheetXml = XmlDocument.parse(utf8.decode(sheetFile.content));
    for (final row in sheetXml.findAllElements('row')) {
      final cells = <String>[];
      for (final c in row.findElements('c')) {
        final type = c.getAttribute('t');

        if (type == 's' && sharedStrings.isNotEmpty) {
          // 共享字符串
          final vs = c.findElements('v');
          final index = vs.isNotEmpty ? int.tryParse(vs.first.innerText) : null;
          cells.add(index != null && index < sharedStrings.length
              ? sharedStrings[index]
              : '');
        } else if (type == 'inlineStr') {
          // 内联字符串
          final is_ = c.findElements('is');
          final t = is_.isNotEmpty ? is_.first.findElements('t') : null;
          cells.add(t != null && t.isNotEmpty ? t.first.innerText : '');
        } else {
          // 数字或其他
          final vs = c.findElements('v');
          cells.add(vs.isNotEmpty ? vs.first.innerText : '');
        }
      }
      result.add(cells);
    }

    return result;
  }

  static String _columnLetter(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var result = '';
    var i = index;
    do {
      result = '${letters[i % 26]}$result';
      i = i ~/ 26 - 1;
    } while (i >= 0);
    return result;
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
