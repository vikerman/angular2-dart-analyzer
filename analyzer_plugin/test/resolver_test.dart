library angular2.src.analysis.analyzer_plugin.src.resolver_test;

import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';
import 'element_assert.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(TemplateResolverTest);
}

void assertPropertyElement(AngularElement element,
    {nameMatcher, sourceMatcher}) {
  expect(element, new isInstanceOf<InputElement>());
  InputElement inputElement = element;
  if (nameMatcher != null) {
    expect(inputElement.name, nameMatcher);
  }
  if (sourceMatcher != null) {
    expect(inputElement.source.fullName, sourceMatcher);
  }
}

@reflectiveTest
class TemplateResolverTest extends AbstractAngularTest {
  String dartCode;
  String htmlCode;
  Source dartSource;
  Source htmlSource;

  List<AbstractDirective> directives;

  Template template;
  List<ResolvedRange> ranges;

  void test_attribute_mixedCase() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    _addHtmlSource(r"""
<svg viewBox='0, 0, 24 24'></svg>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(0));
  }

  void test_attributeInterpolation() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String aaa; // 1
  String bbb; // 2
}
''');
    _addHtmlSource(r"""
<span title='Hello {{aaa}} and {{bbb}}!'></span>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2));
    _assertElement('aaa}}').dart.getter.at('aaa; // 1');
    _assertElement('bbb}}').dart.getter.at('bbb; // 2');
  }

  void test_expression_eventBinding() {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    _addHtmlSource(r"""
<div (click)='handleClick()'></div>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    _assertElement('handleClick').dart.method.at('handleClick(MouseEvent');
  }

  void test_expression_eventBinding_on() {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    _addHtmlSource(r"""
<div on-click='handleClick()'></div>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    _assertElement('handleClick()').dart.method.at('handleClick(MouseEvent');
  }

  void test_expression_inputBinding() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span [title]='text'></span>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    _assertElement("text'>").dart.getter.at('text; // 1');
  }

  void test_expression_inputBinding_bind() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span bind-title='text'></span>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    _assertElement("text'>").dart.getter.at('text; // 1');
  }

  void test_inheritedFields() {
    _addDartSource(r'''
class BaseComponent {
  String text; // 1
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel extends BaseComponent {
  main() {
    text.length;
  }
}
''');
    _addHtmlSource(r"""
<div>
  Hello {{text}}!
</div>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    _assertElement("text}}").dart.getter.at('text; // 1');
    errorListener.assertNoErrors();
  }

  void test_inputReference() {
    _addDartSource(r'''
@Component(
    selector: 'name-panel',
    inputs: const ['aaa', 'bbb', 'ccc'])
@View(template: r"<div>AAA</div>")
class NamePanel {
  int aaa;
  int bbb;
  int ccc;
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NamePanel])
class TestPanel {}
''');
    _addHtmlSource(r"""
<name-panel aaa='1' [bbb]='2' bind-ccc='3'></name-panel>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("aaa=").input.at("aaa', ");
    _assertElement("bbb]=").input.at("bbb', ");
    _assertElement("ccc=").input.at("ccc']");
  }

  void test_localVariable_camelCaseName() {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleKeyUp(Element e) {}
}
''');
    _addHtmlSource(r"""
<div (keyup)='handleKeyUp(myTargetElement)'>
  <div #myTargetElement></div>
</div>
""");
    _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("myTargetElement)").local.at("myTargetElement>");
  }

  void test_localVariable_exportAs() {
    _addDartSource(r'''
@Directive(selector: '[myDirective]', exportAs: 'exportedValue')
class MyDirective {
  String aaa; // 1
}

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [MyDirective])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div myDirective #value='exportedValue'>
  {{value.aaa}}
</div>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("myDirective #").selector.at("myDirective]");
    _assertElement("value=").local.declaration.type('MyDirective');
    _assertElement("exportedValue'>").angular.at("exportedValue')");
    _assertElement("value.aaa").local.at("value=");
    _assertElement("aaa}}").dart.getter.at('aaa; // 1');
  }

  void test_localVariable_scope_forwardReference() {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'aaa', inputs: const ['target'])
@View(template: '')
class ComponentA {
  void set target(ComponentB b) {}
}

@Component(selector: 'bbb')
@View(template: '')
class ComponentB {}

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [ComponentA, ComponentB])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div>
  <aaa [target]='handle'></aaa>
  <bbb #handle></bbb>
</div>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("handle'>").local.at("handle></bbb>").type('ComponentB');
  }

  void test_ngContent() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {}
''');
    _addHtmlSource(r"""
<ng-content></ng-content>>
""");
    _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  void test_ngFor_iterableElementType() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  MyIterable<String> items = new MyIterable<String>();
}
class BaseIterable<T> {
  Iterator<T> get iterator => <T>[].iterator;
}
class MyIterable<T> extends BaseIterable<T> {
}
''');
    _addHtmlSource(r"""
<li template='ngFor #item of items'>
  {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("item.").local.at('item of').type('String');
    _assertElement("length}}").dart.getter;
  }

  void test_ngFor_operatorLocalVariable() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> operators = [];
}
''');
    _addHtmlSource(r"""
<li *ngFor='#operator of operators'>
  {{operator.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    expect(template.ranges, hasLength(7));
    _assertElement("ngFor=").selector.inFileName('ng_for.dart');
    _assertElement("operator of").local.declaration.type('String');
    _assertElement("length}}").dart.getter;
    errorListener.assertNoErrors();
  }

  void test_ngFor_star() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li *ngFor='#item of items; #i = index'>
  {{i}} {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    expect(template.ranges, hasLength(10));
    _assertElement("ngFor=").selector.inFileName('ng_for.dart');
    _assertElement("item of").local.declaration.type('String');
    _assertSelectorElement("of items")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("of items")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items;").dart.getter.at('items = []');
    _assertElement("i = index").local.declaration.type('int');
    _assertElement("i}}").local.at('i = index');
    _assertElement("item.").local.at('item of');
    _assertElement("length}}").dart.getter;
  }

  void test_ngFor_star_itemVisibleInElement() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li *ngFor='var item of items' [visible]='item != null'>
</li>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("item != null").local.at('item of items');
  }

  void test_ngFor_templateAttribute() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li template='ngFor #item of items; #i = index'>
  {{i}} {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("ngFor #").selector.inFileName('ng_for.dart');
    _assertElement("item of").local.declaration.type('String');
    _assertSelectorElement("of items")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("of items")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items;").dart.getter.at('items = []');
    _assertElement("i = index").local.declaration.type('int');
    _assertElement("i}}").local.at('i = index');
    _assertElement("item.").local.at('item of');
    _assertElement("length}}").dart.getter;
  }

  void test_ngFor_templateAttribute2() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li template='ngFor: #item, of = items, #i=index'>
  {{i}} {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("ngFor:").selector.inFileName('ng_for.dart');
    _assertElement("item, of").local.declaration.type('String');
    _assertSelectorElement("of = items,")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("of = items,")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items,").dart.getter.at('items = []');
    _assertElement("i=index").local.declaration.type('int');
    _assertElement("i}}").local.at('i=index');
    _assertElement("item.").local.at('item, of');
    _assertElement("length}}").dart.getter;
  }

  void test_ngFor_templateElement() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<template ngFor #item [ngForOf]='items' #i='index'>
  <li>{{i}} {{item.length}}</li>
</template>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement("ngFor #").selector.inFileName('ng_for.dart');
    _assertElement("item [").local.declaration.type('String');
    _assertSelectorElement("ngForOf]")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("ngForOf]")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items'").dart.getter.at('items = []');
    _assertElement("i='index").local.declaration.type('int');
    _assertElement("i}}").local.at("i='index");
    _assertElement("item.").local.at('item [');
    _assertElement("length}}").dart.getter;
  }

  void test_ngIf_star() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span *ngIf='text.length != 0'>
""");
    _resolveSingleTemplate(dartSource);
    _assertSelectorElement("ngIf=").selector.inFileName('ng_if.dart');
    _assertInputElement("ngIf=").input.inFileName('ng_if.dart');
    _assertElement("text.").dart.getter.at('text; // 1');
    _assertElement("length != 0").dart.getter;
  }

  void test_ngIf_templateAttribute() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span template='ngIf text.length != 0'>
""");
    _resolveSingleTemplate(dartSource);
    _assertSelectorElement("ngIf text").selector.inFileName('ng_if.dart');
    _assertInputElement("ngIf text").input.inFileName('ng_if.dart');
    _assertElement("text.").dart.getter.at('text; // 1');
    _assertElement("length != 0").dart.getter;
  }

  void test_ngIf_templateElement() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<template [ngIf]='text.length != 0'></template>
""");
    _resolveSingleTemplate(dartSource);
    _assertSelectorElement("ngIf]").selector.inFileName('ng_if.dart');
    _assertInputElement("ngIf]").input.inFileName('ng_if.dart');
    _assertElement("text.").dart.getter.at('text; // 1');
    _assertElement("length != 0").dart.getter;
  }

  void test_standardHtmlComponent() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void inputChange(String value, String validationMessage) {}
}
''');
    _addHtmlSource(r"""
<input #inputEl M
       (change)='inputChange(inputEl.value, inputEl.validationMessage)'>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement('input #').selector.inCoreHtml.at('input");');
    _assertElement('inputEl M').local.at('inputEl M');
    _assertElement('inputChange(inputEl').dart.method.at('inputChange(Str');
    _assertElement('inputEl.value').local.at('inputEl M');
    _assertElement('value, ').dart.getter.inCoreHtml;
    _assertElement('inputEl.validationMessage').local.at('inputEl M');
    _assertElement('validationMessage)').dart.getter.inCoreHtml;
    errorListener.assertNoErrors();
    expect(ranges, hasLength(7));
  }

  void test_template_attribute_withoutValue() {
    _addDartSource(r'''
@Directive(selector: '[deferred-content]')
class DeferredContentDirective {}

@Component(selector: 'test-panel')
@View(
    templateUrl: 'test_panel.html',
    directives: const [DeferredContentDirective])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div *deferred-content>Deferred content</div>
""");
    _resolveSingleTemplate(dartSource);
    _assertElement('deferred-content>').selector.at("deferred-content]')");
  }

  void test_textInterpolation() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String aaa; // 1
  String bbb; // 2
}
''');
    _addHtmlSource(r"""
<div>
  Hello {{aaa}} and {{bbb}}!
</div>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2));
    _assertElement('aaa}}').dart.getter.at('aaa; // 1');
    _assertElement('bbb}}').dart.getter.at('bbb; // 2');
  }

  void _addDartSource(String code) {
    dartCode = '''
import '/angular2/angular2.dart';
$code
''';
    dartSource = newSource('/test_panel.dart', dartCode);
  }

  void _addHtmlSource(String code) {
    htmlCode = code;
    htmlSource = newSource('/test_panel.html', htmlCode);
  }

  ElementAssert _assertElement(String atString,
      [ResolvedRangeCondition condition]) {
    ResolvedRange resolvedRange = _findResolvedRange(atString, condition);
    return new ElementAssert(context, dartCode, dartSource, htmlCode,
        htmlSource, resolvedRange.element, resolvedRange.range.offset);
  }

  ElementAssert _assertInputElement(String atString) {
    return _assertElement(atString, _isInputElement);
  }

  ElementAssert _assertSelectorElement(String atString) {
    return _assertElement(atString, _isSelectorName);
  }

  /**
   * Return the [ResolvedRange] that starts at the position of the give
   * [search] and, if specified satisfies the given [condition].
   */
  ResolvedRange _findResolvedRange(String search,
      [ResolvedRangeCondition condition]) {
    return getResolvedRangeAtString(htmlCode, ranges, search, condition);
  }

  /**
   * Compute all the views declared in the given [dartSource], and resolve the
   * external template of the last one.
   */
  void _resolveSingleTemplate(Source dartSource) {
    directives = computeLibraryDirectives(dartSource);
    List<View> views = computeLibraryViews(dartSource);
    View view = views.last;
    // resolve this View
    computeResult(view, HTML_TEMPLATE);
    template = outputs[HTML_TEMPLATE];
    ranges = template.ranges;
    fillErrorListener(HTML_TEMPLATE_ERRORS);
  }

  static bool _isInputElement(ResolvedRange region) {
    return region.element is InputElement;
  }

  static bool _isSelectorName(ResolvedRange region) {
    return region.element is SelectorName;
  }
}
