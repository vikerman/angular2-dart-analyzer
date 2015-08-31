library angular2.src.analysis.analyzer_plugin.src.tasks;

import 'package:analyzer/src/generated/ast.dart' as ast;
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/dart.dart';
import 'package:analyzer/src/task/general.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/resolver.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:angular2_analyzer_plugin/tasks.dart';

/// The [Template]s of a [LibrarySpecificUnit].
/// This result is produced for templates specified directly in Dart files.
final ListResultDescriptor<Template> DART_TEMPLATES =
    new ListResultDescriptor<Template>(
        'ANGULAR_DART_TEMPLATE_RANGES', Template.EMPTY_LIST);

/// The errors produced while building [DART_TEMPLATES].
/// This result is produced for templates specified directly in Dart files.
final ListResultDescriptor<AnalysisError> DART_TEMPLATES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'DART_TEMPLATES_ERRORS', AnalysisError.NO_ERRORS);

/// The Angular [AbstractDirective]s of a [LibrarySpecificUnit].
final ListResultDescriptor<AbstractDirective> DIRECTIVES =
    new ListResultDescriptor<AbstractDirective>(
        'ANGULAR_DIRECTIVES', AbstractDirective.EMPTY_LIST);

/// The errors produced while building [DIRECTIVES].
///
/// The list will be empty if there were no errors, but will not be `null`.
///
/// The result is only available for [LibrarySpecificUnit]s.
final ListResultDescriptor<AnalysisError> DIRECTIVES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_DIRECTIVES_ERRORS', AnalysisError.NO_ERRORS);

/// The [View]s of a [LibrarySpecificUnit].
final ListResultDescriptor<View> VIEWS =
    new ListResultDescriptor<View>('ANGULAR_VIEWS', View.EMPTY_LIST);

/// The errors produced while building [VIEWS].
///
/// The list will be empty if there were no errors, but will not be `null`.
///
/// The result is only available for [LibrarySpecificUnit]s.
final ListResultDescriptor<AnalysisError> VIEWS_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'VIEWS_ERRORS', AnalysisError.NO_ERRORS);

/// A task that builds [AbstractDirective]s of a [CompilationUnit].
class BuildUnitDirectivesTask extends SourceBasedAnalysisTask
    with _AnnotationProcessorMixin {
  static const String UNIT_INPUT = 'UNIT_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitDirectivesTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[DIRECTIVES, DIRECTIVES_ERRORS]);

  BuildUnitDirectivesTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    initAnnotationProcessor(target);
    //
    // Prepare inputs.
    //
    ast.CompilationUnit unit = getRequiredInput(UNIT_INPUT);
    //
    // Process all classes.
    //
    List<AbstractDirective> directives = <AbstractDirective>[];
    for (ast.CompilationUnitMember unitMember in unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        ClassElement classElement = unitMember.element;
        for (ast.Annotation annotationNode in unitMember.metadata) {
          AbstractDirective directive =
              _createDirective(classElement, annotationNode);
          if (directive != null) {
            directives.add(directive);
          }
        }
      }
    }
    //
    // Record outputs.
    //
    outputs[DIRECTIVES] = directives;
    outputs[DIRECTIVES_ERRORS] = errorListener.errors;
  }

  /// Returns an Angular [AbstractDirective] for to the given [node].
  /// Returns `null` if not an Angular annotation.
  AbstractDirective _createDirective(
      ClassElement classElement, ast.Annotation node) {
    // TODO(scheglov) add support for all the arguments
    if (_isAngularAnnotation(node, 'Component')) {
      Selector selector = _parseSelector(node);
      if (selector == null) {
        return null;
      }
      List<PropertyElement> properties = _parseProperties(classElement, node);
      return new Component(classElement,
          selector: selector, properties: properties);
    }
    if (_isAngularAnnotation(node, 'Directive')) {
      Selector selector = _parseSelector(node);
      if (selector == null) {
        return null;
      }
      List<PropertyElement> properties = _parseProperties(classElement, node);
      return new Directive(classElement,
          selector: selector, properties: properties);
    }
    return null;
  }

  List<PropertyElement> _parseProperties(
      ClassElement classElement, ast.Annotation node) {
    ast.Expression expression = _getNamedArgument(node, 'properties');
    if (expression == null || expression is! ast.ListLiteral) {
      return PropertyElement.EMPTY_LIST;
    }
    ast.ListLiteral descList = expression;
    // Create a property for each element;
    List<PropertyElement> properties = <PropertyElement>[];
    for (ast.Expression element in descList.elements) {
      PropertyElement property = _parseProperty(classElement, element);
      if (property != null) {
        properties.add(property);
      }
    }
    return properties;
  }

  PropertyElement _parseProperty(
      ClassElement classElement, ast.Expression element) {
    if (element is ast.SimpleStringLiteral) {
      int offset = element.contentsOffset;
      String value = element.value;
      // TODO(scheglov) support for pipes
      int colonIndex = value.indexOf(':');
      if (colonIndex == -1) {
        String name = value;
        // TODO(scheglov) test that a valid property name
        PropertyAccessorElement setter =
            classElement.lookUpSetter(name, classElement.library);
        // TODO(scheglov) test that "setter" was found
        return new PropertyElement(name, offset, target.source, setter,
            new SourceRange(offset, name.length));
      } else {
        String setterName = value.substring(0, colonIndex).trimRight();
        PropertyAccessorElement setter =
            classElement.lookUpSetter(setterName, classElement.library);
        // TODO(scheglov) test that "setter" was found
        int propertyOffset = colonIndex;
        while (true) {
          propertyOffset++;
          if (propertyOffset >= value.length) {
            // TODO(scheglov) report a warning
            return null;
          }
          if (value.substring(propertyOffset, propertyOffset + 1) != ' ') {
            break;
          }
        }
        String propertyName = value.substring(propertyOffset);
        // TODO(scheglov) test that a valid property name
        return new PropertyElement(propertyName, offset + propertyOffset,
            target.source, setter, new SourceRange(offset, setterName.length));
      }
    } else {
      // TODO(scheglov) report a warning
      return null;
    }
  }

  Selector _parseSelector(ast.Annotation node) {
    // Find the "selector" argument.
    ast.Expression expression = _getNamedArgument(node, 'selector');
    if (expression == null) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.ARGUMENT_SELECTOR_MISSING, node);
      return null;
    }
    // Compute the selector text.
    String selectorStr;
    int selectorOffset;
    if (expression is ast.SimpleStringLiteral) {
      selectorStr = expression.value;
      selectorOffset = expression.contentsOffset;
    } else {
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
      return null;
    }
    // Parse the selector text.
    Selector selector =
        Selector.parse(target.source, selectorOffset, selectorStr);
    if (selector == null) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.CANNOT_PARSE_SELECTOR, expression);
      return null;
    }
    return selector;
  }

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(LibrarySpecificUnit target) {
    return <String, TaskInput>{UNIT_INPUT: RESOLVED_UNIT.of(target)};
  }

  /// Create a task based on the given [target] in the given [context].
  static BuildUnitDirectivesTask createTask(
      AnalysisContext context, LibrarySpecificUnit target) {
    return new BuildUnitDirectivesTask(context, target);
  }
}

/// A task that builds [View]s of a [CompilationUnit].
class BuildUnitViewsTask extends SourceBasedAnalysisTask
    with _AnnotationProcessorMixin {
  static const String DIRECTIVES_INPUT = 'DIRECTIVES_INPUT';
  static const String UNIT_INPUT = 'UNIT_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitViewsTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[VIEWS, VIEWS_ERRORS]);

  List<AbstractDirective> _allDirectives;

  BuildUnitViewsTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    initAnnotationProcessor(target);
    //
    // Prepare inputs.
    //
    List<List<AbstractDirective>> directiveListList =
        getRequiredInput(DIRECTIVES_INPUT);
    ast.CompilationUnit unit = getRequiredInput(UNIT_INPUT);
    //
    // Process inputs.
    //
    _allDirectives = directiveListList.expand((_) => _).toList();
    //
    // Process all classes.
    //
    List<View> views = <View>[];
    for (ast.CompilationUnitMember unitMember in unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        ClassElement classElement = unitMember.element;
        for (ast.Annotation annotation in unitMember.metadata) {
          if (_isAngularAnnotation(annotation, 'View')) {
            View view = _createView(classElement, annotation);
            if (view != null) {
              views.add(view);
            }
          }
        }
      }
    }
    //
    // Record outputs.
    //
    outputs[VIEWS] = views;
    outputs[VIEWS_ERRORS] = errorListener.errors;
  }

  /// Return the corresponding [Component] annotation, otherwise reports an
  /// error and returns `null`.
  void _addDirectiveOrReportError(List<AbstractDirective> directives,
      ast.Expression expression, ClassElement classElement) {
    for (AbstractDirective directive in _allDirectives) {
      if (directive.classElement == classElement) {
        directives.add(directive);
        return;
      }
    }
    errorReporter.reportErrorForNode(
        AngularWarningCode.DIRECTIVE_TYPE_LITERAL_EXPECTED, expression);
  }

  /// Create a new [View] for the given [annotation], may return `null`
  /// if [annotation] or [classElement] don't provide enough information.
  View _createView(ClassElement classElement, ast.Annotation annotation) {
    String templateUrl = _getNamedArgumentString(annotation, 'templateUrl');
    // Try to find inline "template".
    String templateText;
    int templateOffset = 0;
    {
      ast.Expression expression = _getNamedArgument(annotation, 'template');
      if (expression != null) {
        if (expression is ast.SimpleStringLiteral) {
          templateText = expression.value;
          templateOffset = expression.contentsOffset;
        } else {
          errorReporter.reportErrorForNode(
              AngularWarningCode.STRING_VALUE_EXPECTED, expression);
        }
      }
    }
    // Find the corresponding Component.
    Component component = _findComponentAnnotationOrReportError(classElement);
    if (component == null) {
      return null;
    }
    // Prepare directives.
    List<AbstractDirective> directives = <AbstractDirective>[];
    {
      ast.Expression listExpression =
          _getNamedArgument(annotation, 'directives');
      if (listExpression is ast.ListLiteral) {
        for (ast.Expression element in listExpression.elements) {
          if (element is ast.Identifier &&
              element.staticElement is ClassElement) {
            _addDirectiveOrReportError(
                directives, element, element.staticElement);
          } else {
            errorReporter.reportErrorForNode(
                AngularWarningCode.TYPE_LITERAL_EXPECTED, element);
          }
        }
      }
    }
    // Create View.
    return new View(classElement, component, directives,
        templateText: templateText,
        templateOffset: templateOffset,
        templateUrl: templateUrl);
  }

  Component _findComponentAnnotationOrReportError(ClassElement classElement) {
    for (AbstractDirective directive in _allDirectives) {
      if (directive is Component && directive.classElement == classElement) {
        return directive;
      }
    }
    errorReporter.reportErrorForElement(
        AngularWarningCode.COMPONENT_ANNOTATION_MISSING, classElement, []);
    return null;
  }

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(LibrarySpecificUnit target) {
    return <String, TaskInput>{
      DIRECTIVES_INPUT: IMPORT_EXPORT_SOURCE_CLOSURE
          .of(target.library)
          .toMapOf(UNITS)
          .toFlattenList((Source library, Source unit) =>
              DIRECTIVES.of(new LibrarySpecificUnit(library, unit))),
      UNIT_INPUT: RESOLVED_UNIT.of(target)
    };
  }

  /// Create a task based on the given [target] in the given [context].
  static BuildUnitViewsTask createTask(
      AnalysisContext context, LibrarySpecificUnit target) {
    return new BuildUnitViewsTask(context, target);
  }
}

/// A task that builds [Template]s of a [LibrarySpecificUnit].
class ResolveDartTemplatesTask extends SourceBasedAnalysisTask {
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';
  static const String VIEWS_INPUT = 'VIEWS_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'ResolveDartTemplatesTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[DART_TEMPLATES, DART_TEMPLATES_ERRORS]);

  RecordingErrorListener errorListener = new RecordingErrorListener();

  ResolveDartTemplatesTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    //
    // Prepare inputs.
    //
    TypeProvider typeProvider = getRequiredInput(TYPE_PROVIDER_INPUT);
    List<View> views = getRequiredInput(VIEWS_INPUT);
    //
    // Resolve inline view templates.
    //
    List<Template> templates = <Template>[];
    for (View view in views) {
      Template template =
          new DartTemplateResolver(typeProvider, view, errorListener).resolve();
      if (template != null) {
        templates.add(template);
      }
    }
    //
    // Record outputs.
    //
    outputs[DART_TEMPLATES] = templates;
    outputs[DART_TEMPLATES_ERRORS] = errorListener.errors;
  }

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(LibrarySpecificUnit target) {
    return <String, TaskInput>{
      TYPE_PROVIDER_INPUT: TYPE_PROVIDER.of(AnalysisContextTarget.request),
      VIEWS_INPUT: VIEWS.of(target),
    };
  }

  /// Create a task based on the given [target] in the given [context].
  static ResolveDartTemplatesTask createTask(
      AnalysisContext context, LibrarySpecificUnit target) {
    return new ResolveDartTemplatesTask(context, target);
  }
}

/// Helper for processing Angular annottations.
class _AnnotationProcessorMixin {
  RecordingErrorListener errorListener = new RecordingErrorListener();
  ErrorReporter errorReporter;

  /// The evaluator of constant values, such as annotation arguments.
  final ast.ConstantEvaluator _constantEvaluator = new ast.ConstantEvaluator();

  /// Initialize the processor working in the given [target].
  void initAnnotationProcessor(AnalysisTarget target) {
    assert(errorReporter == null);
    errorReporter = new ErrorReporter(errorListener, target.source);
  }

  /// Returns the [String] value of the given [expression].
  /// If [expression] does not have a [String] value, reports an error
  /// and returns `null`.
  String _getExpressionString(ast.Expression expression) {
    if (expression != null) {
      Object value = expression.accept(_constantEvaluator);
      if (value is String) {
        return value;
      }
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
    }
    return null;
  }

  /// Returns the value of the argument with the given [name].
  /// Returns `null` if not found.
  ast.Expression _getNamedArgument(ast.Annotation node, String name) {
    if (node.arguments != null) {
      List<ast.Expression> arguments = node.arguments.arguments;
      for (ast.Expression argument in arguments) {
        if (argument is ast.NamedExpression &&
            argument.name != null &&
            argument.name.label != null &&
            argument.name.label.name == name) {
          return argument.expression;
        }
      }
    }
    return null;
  }

  /// Returns the [String] value of the argument with the given [name].
  /// If the argument does not have a [String] value, reports an error
  /// and returns `null`.
  Object _getNamedArgumentString(ast.Annotation node, String name) {
    ast.Expression expression = _getNamedArgument(node, name);
    return _getExpressionString(expression);
  }

  /// Returns `true` is the given [node] is resolved to a creation of an Angular
  /// annotation class with the given [name].
  bool _isAngularAnnotation(ast.Annotation node, String name) {
    if (node.element is ConstructorElement) {
      ClassElement clazz = node.element.enclosingElement;
      return clazz.library.name == 'angular2.src.core.metadata' &&
          clazz.name == name;
    }
    return false;
  }
}