String quillDeltaToHtml(List<dynamic> deltaOps) {
  final lines = <_QuillHtmlLine>[];
  final currentSegments = <String>[];

  for (final rawOp in deltaOps) {
    if (rawOp is! Map) continue;
    final op = rawOp.cast<Object?, Object?>();
    final insert = op['insert'];
    final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>();

    if (insert is String) {
      final parts = insert.split('\n');
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        if (part.isNotEmpty) {
          currentSegments.add(_wrapInline(part, attrs));
        }

        final isLineBreak = index < parts.length - 1;
        if (isLineBreak) {
          lines.add(
            _QuillHtmlLine(
              inlineHtml: currentSegments.join(),
              attributes: attrs,
            ),
          );
          currentSegments.clear();
        }
      }
      continue;
    }

    if (insert is Map) {
      if (insert['image'] != null) {
        currentSegments.add(
          '<img src="${_escapeHtml(insert['image'].toString())}" />',
        );
      }
    }
  }

  if (currentSegments.isNotEmpty) {
    lines.add(
      _QuillHtmlLine(inlineHtml: currentSegments.join(), attributes: const {}),
    );
  }

  if (lines.isEmpty) return '';

  final buffer = StringBuffer();
  var activeListType = '';

  void closeActiveList() {
    if (activeListType.isNotEmpty) {
      buffer.write('</$activeListType>');
      activeListType = '';
    }
  }

  for (final line in lines) {
    final attrs = line.attributes ?? const <String, dynamic>{};
    final listType = attrs['list']?.toString();
    final content = line.inlineHtml.isEmpty ? '<br>' : line.inlineHtml;

    if (listType == 'bullet' || listType == 'ordered') {
      final tag = listType == 'bullet' ? 'ul' : 'ol';
      if (activeListType != tag) {
        closeActiveList();
        buffer.write('<$tag>');
        activeListType = tag;
      }
      buffer.write('<li>$content</li>');
      continue;
    }

    closeActiveList();

    final header = attrs['header'];
    if (header != null) {
      final level = int.tryParse(header.toString())?.clamp(1, 6) ?? 1;
      buffer.write('<h$level>$content</h$level>');
      continue;
    }

    buffer.write('<p>$content</p>');
  }

  closeActiveList();
  return buffer.toString();
}

String _wrapInline(String text, Map<String, dynamic>? attrs) {
  var html = _escapeHtml(text);
  final attributes = attrs ?? const <String, dynamic>{};

  if (attributes['link'] != null) {
    final href = _escapeHtml(attributes['link'].toString());
    html = '<a href="$href">$html</a>';
  }
  if (attributes['underline'] == true) {
    html = '<u>$html</u>';
  }
  if (attributes['strike'] == true) {
    html = '<s>$html</s>';
  }
  if (attributes['italic'] == true) {
    html = '<em>$html</em>';
  }
  if (attributes['bold'] == true) {
    html = '<strong>$html</strong>';
  }

  return html;
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

class _QuillHtmlLine {
  const _QuillHtmlLine({required this.inlineHtml, required this.attributes});

  final String inlineHtml;
  final Map<String, dynamic>? attributes;
}
