import 'dart:convert';
import 'dart:io';
import 'dart:developer';

Future<void> runGenerator() async {
  final configFile = File('resources/config.json');

  if (!await configFile.exists()) {
    log(
      'El archivo config.json no existe en resources/',
      name: 'ModelGenerator',
    );
    return;
  }

  final configContent = await configFile.readAsString();
  final configData = json.decode(configContent);

  final author = configData['author'] ?? 'Unknown';
  final project = configData['project'] ?? 'Unknown Project';
  final packageName = configData['package'] ?? 'ventas';
  final generatedDate = DateTime.now();

  Map<String, dynamic> globalGenerate = {};
  if (configData.containsKey('generate')) {
    globalGenerate = Map<String, dynamic>.from(configData['generate']);
  }

  final files = List<Map<String, dynamic>>.from(configData['files']);
  final List<String> exports = [];
  final Set<String> outputFolders = {};

  for (var fileConfig in files) {
    final inputPath = fileConfig['input'];
    final outputSubPath = normalizePath(
      fileConfig['output'].replaceFirst(RegExp(r'^lib/'), ''),
    );

    final generate =
        fileConfig.containsKey('generate')
            ? Map<String, dynamic>.from(fileConfig['generate'])
            : globalGenerate;

    final data = await readJsonFile(inputPath);
    if (data == null) continue;

    final className = data['className'];
    final fields = List<Map<String, dynamic>>.from(data['fields']);

    final allFieldsAreFinal = generate['setter'] != true;
    final requiresImmutable = allFieldsAreFinal;
    final needsListEquals = fields.any(
      (f) => (f['type'] as String).startsWith('List<'),
    );

    await ensureDirectory('lib/$outputSubPath');
    outputFolders.add(outputSubPath.split('/').first);

    final fileName = toSnakeCase(className) + '.dart';
    final relativePath = '$outputSubPath/$fileName';
    exports.add("export 'package:$packageName/$relativePath';");

    final buffer = StringBuffer();
    buffer.writeln('// AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.');
    buffer.writeln('// Author: $author');
    buffer.writeln('// Project: $project');
    buffer.writeln('// Generated: ${generatedDate.toIso8601String()}');
    buffer.writeln();

    if (requiresImmutable || needsListEquals) {
      buffer.writeln("import 'package:flutter/foundation.dart';");
    }

    for (var f in fields) {
      if (f['relation'] == true) {
        final type = f['type'] as String;
        final importName =
            type.startsWith('List<')
                ? type.substring(5, type.length - 1)
                : type;
        final folder =
            outputSubPath.split('/').length > 1
                ? '../${toSnakeCase(importName)}/${toSnakeCase(importName)}.dart'
                : '${toSnakeCase(importName)}/${toSnakeCase(importName)}.dart';
        buffer.writeln("import '$folder';");
      }
    }

    if (requiresImmutable) {
      buffer.writeln();
      buffer.writeln('@immutable');
    }

    buffer.writeln('class $className {');
    buffer.writeln(generateFields(fields, allFieldsAreFinal));
    buffer.writeln(generateConstructor(className, fields, allFieldsAreFinal));

    if (generate['getter'] == true) buffer.writeln(generateGetters(fields));
    if (generate['setter'] == true) buffer.writeln(generateSetters(fields));
    if (generate['toString'] == true)
      buffer.writeln(generateToString(className, fields));
    if (generate['builder'] == true)
      buffer.writeln(
        '  static ${className}Builder builder() => ${className}Builder();',
      );
    if (generate['copyWith'] == true)
      buffer.writeln(generateCopyWith(className, fields));
    if (generate['json'] == true)
      buffer.writeln(generateJsonMethods(className, fields));
    buffer.writeln(generateHashCodeEquals(className, fields));
    buffer.writeln('}');

    if (generate['builder'] == true)
      buffer.writeln(generateBuilder(className, fields));

    await writeFile('lib/$relativePath', buffer.toString());
    log(
      'Modelo generado exitosamente en: lib/$relativePath',
      name: 'ModelGenerator',
    );
  }

  exports.sort();
  final indexBuffer = StringBuffer();
  indexBuffer.writeln('// AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.');
  indexBuffer.writeln('// Author: $author');
  indexBuffer.writeln('// Project: $project');
  indexBuffer.writeln('// Generated: ${generatedDate.toIso8601String()}');
  indexBuffer.writeln();
  indexBuffer.writeln(exports.join('\n'));

  final baseFolder = outputFolders.isNotEmpty ? outputFolders.first : 'models';
  await ensureDirectory('lib/$baseFolder');
  await writeFile('lib/$baseFolder/index.dart', indexBuffer.toString());
  log(
    'Archivo index.dart generado exitosamente en: lib/$baseFolder/index.dart',
    name: 'ModelGenerator',
  );
}

Future<void> recreateDirectory(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
  await dir.create(recursive: true);
}

Future<void> ensureDirectory(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<Map<String, dynamic>?> readJsonFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    log('El archivo de entrada no existe: $path', name: 'ModelGenerator');
    return null;
  }

  final content = await file.readAsString();
  final data = json.decode(content);
  if (data is! Map<String, dynamic>) {
    log(
      'Formato inválido en $path. Debe ser un objeto JSON.',
      name: 'ModelGenerator',
    );
    return null;
  }
  return data;
}

Future<void> writeFile(String path, String content) async {
  final file = File(path);
  await file.writeAsString(content, flush: true);
}

String normalizePath(String path) => path.replaceAll('\\', '/');

String formatDefaultValue(Map<String, dynamic> field) {
  final defaultValue = field['default'];
  final type = field['type'];
  if (defaultValue == null) return 'null';
  if (type == 'String') return "'${defaultValue}'";
  return '$defaultValue';
}

String generateFields(List fields, bool allFinal) {
  final buffer = StringBuffer();
  for (var f in fields) {
    final description = f['description'] ?? '';
    final originalType = f['type'] as String;
    final alreadyNullable = originalType.endsWith('?');
    final isNullable = f['nullable'] == true;
    final type =
        (isNullable && !alreadyNullable) ? '${originalType}?' : originalType;
    final modifier = allFinal ? 'final' : 'late';
    if (description.isNotEmpty) buffer.writeln('  /// $description');
    buffer.writeln('  $modifier $type _${f['name']};');
  }
  return buffer.toString();
}

String generateConstructor(String className, List fields, bool allFinal) {
  final buffer = StringBuffer();
  buffer.writeln(
    allFinal ? '  const $className.full({' : '  $className.full({',
  );
  for (var f in fields) {
    final originalType = f['type'] as String;
    final alreadyNullable = originalType.endsWith('?');
    final isNullable = f['nullable'] == true;
    final type =
        (isNullable && !alreadyNullable) ? '${originalType}?' : originalType;
    final hasDefault = f['default'] != null;
    final requiredPrefix = (!isNullable && !hasDefault) ? 'required ' : '';
    buffer.writeln(
      '    $requiredPrefix$type ${f['name']}${hasDefault ? ' = ${formatDefaultValue(f)}' : ''},',
    );
  }
  buffer.writeln('  })');
  for (var i = 0; i < fields.length; i++) {
    final f = fields[i];
    final prefix = (i == 0) ? ':' : ',';
    buffer.writeln('      $prefix _${f['name']} = ${f['name']}');
  }
  buffer.writeln(';');
  return buffer.toString();
}

String generateCopyWith(String className, List fields) {
  final buffer = StringBuffer();
  buffer.writeln('  $className copyWith({');
  for (var f in fields) {
    final originalType = f['type'] as String;
    final alreadyNullable = originalType.endsWith('?');
    final isNullable = f['nullable'] == true;
    final type =
        (isNullable && !alreadyNullable) ? '${originalType}?' : originalType;
    buffer.writeln('    $type? ${f['name']},');
  }
  buffer.writeln('  }) {');
  buffer.writeln('    return $className.full(');
  for (var f in fields) {
    buffer.writeln('      ${f['name']}: ${f['name']} ?? _${f['name']},');
  }
  buffer.writeln('    );');
  buffer.writeln('  }');
  return buffer.toString();
}

String generateToString(String className, List fields) {
  final buffer = StringBuffer();
  buffer.writeln('  @override');
  buffer.writeln('  String toString() {');
  buffer.write("    return '$className{");

  for (var i = 0; i < fields.length; i++) {
    final f = fields[i];
    final name = f['name'];
    final isNullable = f['nullable'] == true;
    final separator = (i == fields.length - 1) ? '' : ', ';
    final type = f['type'] as String;

    final accessor = isNullable ? '?.' : '.';

    if (type.startsWith('List<')) {
      buffer.write(
        "$name: \${_${name}${accessor}map((e) => e.toString()).toList()}$separator",
      );
    } else if (f['relation'] == true) {
      buffer.write("$name: \${_${name}${accessor}toString()}$separator");
    } else {
      buffer.write("$name: \${_${name}}$separator");
    }
  }

  buffer.writeln("}';");
  buffer.writeln('  }');
  return buffer.toString();
}

String generateGetters(List fields) {
  final buffer = StringBuffer();
  for (var f in fields) {
    final type = f['nullable'] == true ? '${f['type']}?' : f['type'];
    buffer.writeln('  $type get${capitalize(f['name'])}() => _${f['name']};');
  }
  return buffer.toString();
}

String generateSetters(List fields) {
  final buffer = StringBuffer();
  for (var f in fields) {
    final type = f['nullable'] == true ? '${f['type']}?' : f['type'];
    buffer.writeln(
      '  void set${capitalize(f['name'])}($type ${f['name']}) => _${f['name']} = ${f['name']};',
    );
  }
  return buffer.toString();
}

String generateJsonMethods(String className, List fields) {
  final buffer = StringBuffer();
  buffer.writeln('  Map<String, dynamic> toJson() => {');
  for (var f in fields) {
    final name = f['name'];
    if (f['relation'] == true) {
      if ((f['type'] as String).startsWith('List<')) {
        buffer.writeln(
          "    '$name': _${name}.map((e) => e.toJson()).toList(),",
        );
      } else {
        buffer.writeln("    '$name': _${name}.toJson(),");
      }
    } else {
      buffer.writeln("    '$name': _${name},");
    }
  }
  buffer.writeln('  };\n');

  buffer.writeln(
    '  static $className fromJson(Map<String, dynamic> json) => $className.full(',
  );
  for (var f in fields) {
    final name = f['name'];
    final nullable = f['nullable'] == true;
    final type = f['type'] as String;
    if (f['relation'] == true) {
      if (type.startsWith('List<')) {
        final relatedType = type.substring(5, type.length - 1);
        buffer.writeln(
          "      $name: (json['$name'] as List).map((e) => $relatedType.fromJson(e)).toList(),",
        );
      } else {
        buffer.writeln(
          "      $name: ${nullable ? "json['$name'] != null ? ${type}.fromJson(json['$name']) : null" : "${type}.fromJson(json['$name'])"},",
        );
      }
    } else {
      buffer.writeln("      $name: json['$name'],");
    }
  }
  buffer.writeln('  );');
  return buffer.toString();
}

String generateHashCodeEquals(String className, List fields) {
  final buffer = StringBuffer();
  buffer.writeln('  @override');
  buffer.writeln('  bool operator ==(Object other) {');
  buffer.writeln('    if (identical(this, other)) return true;');
  buffer.writeln('    return other is $className &&');
  for (var i = 0; i < fields.length; i++) {
    final f = fields[i];
    final type = f['type'] as String;
    final name = f['name'];
    final isList = type.startsWith('List<');
    final comparator =
        isList ? 'listEquals(_$name, other._$name)' : '_$name == other._$name';
    final separator = i == fields.length - 1 ? ';' : ' &&';
    buffer.writeln('      $comparator$separator');
  }
  buffer.writeln('  }\n');

  buffer.writeln('  @override');
  buffer.writeln('  int get hashCode =>');
  for (var i = 0; i < fields.length; i++) {
    final f = fields[i];
    final name = f['name'];
    final type = f['type'] as String;
    final isList = type.startsWith('List<');
    final hashPart = isList ? 'Object.hashAll(_$name)' : '_${name}.hashCode';
    final separator = i == fields.length - 1 ? ';' : ' ^';
    buffer.writeln('      $hashPart$separator');
  }
  return buffer.toString();
}

String generateBuilder(String className, List fields) {
  final buffer = StringBuffer();
  buffer.writeln('class ${className}Builder {');
  for (var f in fields) {
    final type = f['nullable'] == true ? '${f['type']}?' : f['type'];
    final isNullable = f['nullable'] == true;
    final hasDefault = f['default'] != null;
    final lateModifier = (!isNullable && !hasDefault) ? 'late ' : '';
    final defaultValue = hasDefault ? ' = ${formatDefaultValue(f)}' : '';
    buffer.writeln('  ${lateModifier}$type _${f['name']}$defaultValue;');
  }
  for (var f in fields) {
    final type = f['nullable'] == true ? '${f['type']}?' : f['type'];
    buffer.writeln(
      '  ${className}Builder set${capitalize(f['name'])}($type ${f['name']}) { _${f['name']} = ${f['name']}; return this; }',
    );
  }
  buffer.writeln('  $className build() => $className.full(');
  for (var f in fields) {
    buffer.writeln('    ${f['name']}: _${f['name']},');
  }
  buffer.writeln('  );');
  buffer.writeln('}');
  return buffer.toString();
}

String capitalize(String text) => text[0].toUpperCase() + text.substring(1);

String toSnakeCase(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (Match m) => '${m[1]}_${m[2]}',
      )
      .toLowerCase();
}
