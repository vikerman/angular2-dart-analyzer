library angular2.src.analysis.analyzer_plugin.src.selector;

import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/strings.dart';
import 'package:html/dom.dart' as html;
import 'package:source_span/source_span.dart';

/**
 * The [Selector] that matches all of the given [selectors].
 */
class AndSelector implements Selector {
  final List<Selector> selectors;

  AndSelector(this.selectors);

  @override
  bool match(html.Element element, Template template) {
    for (Selector selector in selectors) {
      if (!selector.match(element, null)) {
        return false;
      }
    }
    for (Selector selector in selectors) {
      selector.match(element, template);
    }
    return true;
  }
}

/**
 * The [Selector] that matches elements that have an attribute with the
 * given name, and (optionally) with the given value;
 */
class AttributeSelector implements Selector {
  final AngularElement nameElement;
  final String value;

  AttributeSelector(this.nameElement, this.value);

  @override
  bool match(html.Element element, Template template) {
    String name = nameElement.name;
    String val = element.attributes[name];
    // no attribute
    if (val == null) {
      return false;
    }
    // match actual value against required
    if (value != null) {
      // TODO(scheglov)
    }
    // TODO: implement resolve
    return true;
  }
}

/**
 * The [Selector] that matches elements with the given (static) classes.
 */
class ClassSelector implements Selector {
  final AngularElement nameElement;

  ClassSelector(this.nameElement);

  @override
  bool match(html.Element element, Template template) {
    // TODO: implement resolve
    return true;
  }
}

/// The element name based selector.
class ElementNameSelector implements Selector {
  final AngularElement nameElement;

  ElementNameSelector(this.nameElement);

  @override
  bool match(html.Element element, Template template) {
    String name = nameElement.name;
    // match
    if (element.localName != name) {
      return false;
    }
    // done if no template
    if (template == null) {
      return true;
    }
    // record resolution
    {
      SourceSpan span = element.sourceSpan;
      int offset = span.start.offset + '<'.length;
      SourceRange range = new SourceRange(offset, name.length);
      template.addRange(range, nameElement);
    }
    {
      SourceSpan span = element.endSourceSpan;
      if (span != null) {
        int offset = span.start.offset + '</'.length;
        SourceRange range = new SourceRange(offset, name.length);
        template.addRange(range, nameElement);
      }
    }
    return true;
  }

  @override
  String toString() => nameElement.name;
}

/**
 * The [Selector] that matches one of the given [selectors].
 */
class OrSelector implements Selector {
  final List<Selector> selectors;

  OrSelector(this.selectors);

  @override
  bool match(html.Element element, Template template) {
    for (Selector selector in selectors) {
      if (selector.match(element, template)) {
        return true;
      }
    }
    return false;
  }
}

/// The base class for all Angular selectors.
abstract class Selector {
  static final RegExp _regExp = new RegExp(r'(\:not\()|' +
      r'([-\w]+)|' +
      r'(?:\.([-\w]+))|' +
      r'(?:\[([-\w*]+)(?:=([^\]]*))?\])|' +
      r'(\))|' +
      r'(\s*,\s*)');

  /// Check whether the given [element] matches this selector.
  /// If yes, then record resolved ranges into [template].
  bool match(html.Element element, Template template);

  static Selector parse(Source source, int offset, String str) {
    if (str == null) {
      return null;
    }
    List<Selector> selectors = <Selector>[];
    int lastOffset = 0;
    Iterable<Match> matches = _regExp.allMatches(str);
    for (Match match in matches) {
      // no content should be skipped
      {
        String skipStr = str.substring(lastOffset, match.start);
        if (!isBlank(skipStr)) {
          return null;
        }
        lastOffset = match.end;
      }
      // :not start
      if (match[1] != null) {
        // TODO(scheglov) implement this
      }
      // element name
      if (match[2] != null) {
        int nameOffset = offset + match.start;
        String name = match[2];
        selectors.add(new ElementNameSelector(
            new AngularElementImpl(name, nameOffset, name.length, source)));
        continue;
      }
      // class name
      if (match[3] != null) {
        int nameOffset = offset + match.start + 1;
        String name = match[3];
        selectors.add(new ClassSelector(
            new AngularElementImpl(name, nameOffset, name.length, source)));
      }
      // attribute
      if (match[4] != null) {
        int nameIndex = match.start + '['.length;
        String name = match[4];
        int nameOffset = offset + nameIndex;
        selectors.add(new AttributeSelector(
            new AngularElementImpl(name, nameOffset, name.length, source),
            match[5]));
        continue;
      }
      // :not end
      if (match[6] != null) {
        // TODO(scheglov) implement this
      }
      // or
      if (match[7] != null) {
        Selector left = _andSelectors(selectors);
        Selector right =
            parse(source, offset + match.end, str.substring(match.end));
        return new OrSelector(<Selector>[left, right]);
      }
    }
    // final result
    return _andSelectors(selectors);
  }

  static Selector _andSelectors(List<Selector> selectors) {
    if (selectors.length == 1) {
      return selectors[0];
    }
    return new AndSelector(selectors);
  }
}
