# Flutter Model Generator

Generador automático de modelos Flutter/Dart inspirado en el estilo Lombok de Java.

---

## 🚀 ¿Cómo usarlo?

1. Agrega la dependencia en tu `pubspec.yaml`:

```yaml
dependencies:
  lomtter: ^1.0.2
```

2. Descarga las dependencias:

```bash
flutter pub get
```

3. Crea una carpeta `resources/` en tu proyecto.
4. Dentro de `resources/`, crea dos tipos de archivos:
   - `config.json` ➔ Configuración general.
   - `*.json` ➔ Definiciones de cada modelo a generar.

5. Crea un archivo `bin/generate_models.dart` con el siguiente contenido:

```dart
import 'package:lomtter/lomtter.dart';

void main() {
  runGenerator();
}
```

6. Ejecuta el generador:

```bash
dart run bin/generate_models.dart
```

👉 Automáticamente se crearán tus modelos en las carpetas indicadas, junto con un `index.dart` para facilitar las importaciones.

---

## 📄 Ejemplo de `resources/config.json`

```json
{
  "author": "Carlos Franklin",
  "project": "Ventas App",
  "package": "ventas",
  "generate": {
    "toString": true,
    "getter": true,
    "setter": true,
    "builder": true,
    "copyWith": true,
    "json": true
  },
  "files": [
    { "input": "resources/user_model.json", "output": "lib/models/user" },
    { "input": "resources/product_model.json", "output": "lib/models/product" },
    { "input": "resources/sale_model.json", "output": "lib/models" }
  ]
}
```

### 🔹 Explicación rápida

| Campo    | Descripción |
| -------- | ----------- |
| `author`   | Nombre del autor. |
| `project`  | Nombre del proyecto. |
| `package`  | Nombre del paquete para las rutas de exportación. |
| `generate` | Opciones para qué métodos generar en cada modelo. |
| `files`    | Lista de modelos: de dónde leer el JSON y a qué carpeta escribir el `.dart` generado. |

---

## 📄 Ejemplo de modelo `resources/user_model.json`

```json
{
  "className": "User",
  "fields": [
    { "type": "String", "name": "id", "nullable": false, "default": "", "description": "Identificador único del usuario" },
    { "type": "String", "name": "name", "nullable": false, "default": "", "description": "Nombre completo del usuario" },
    { "type": "int", "name": "age", "nullable": false, "default": 0, "description": "Edad del usuario" },
    { "type": "bool", "name": "isActive", "nullable": false, "default": true, "description": "Indica si el usuario está activo" }
  ]
}
```

---

## 📚 Datos válidos en los archivos de modelo

| Campo       | Tipo    | Obligatorio | Descripción |
| ----------- | ------- | ----------- | ------------ |
| `type`        | String  | ✅ | Tipo Dart (`String`, `int`, `bool`, `double`, `List<Type>`, etc.). |
| `name`        | String  | ✅ | Nombre del atributo (en camelCase). |
| `nullable`    | bool    | ✅ | Indica si el campo puede ser `null` (`true` o `false`). |
| `default`     | dynamic | ✅ | Valor por defecto que tendrá el campo. |
| `description` | String  | ✅ | Breve descripción del campo. |

---

## 📄 Ejemplo de modelo más avanzado: `resources/sale_model.json`

```json
{
  "className": "Sale",
  "fields": [
    { "type": "String", "name": "id", "nullable": false, "default": "", "description": "ID de la venta" },
    { "type": "User", "name": "user", "nullable": false, "default": null, "relation": true, "description": "Usuario que realizó la venta" },
    { "type": "List<Product>", "name": "products", "nullable": false, "default": [], "relation": true, "description": "Lista de productos vendidos" },
    { "type": "double", "name": "total", "nullable": false, "default": 0.0, "description": "Monto total de la venta" }
  ]
}
```

---

## ⚙️ Características generadas

- Atributos privados (`_id`, `_name`, etc.).
- Getters y Setters (`getId()`, `setId(String id)`).
- Constructores vacío y completo (`User.full`, `Sale.full`).
- Método `toString()` detallado.
- Método `copyWith({...})`.
- Serialización `toJson()` y `fromJson()`.
- Igualdad `==` y `hashCode` robusto (incluyendo listas).
- `builder()` para construcción fluida.

---

## 📢 Notas adicionales

- Si un campo es una `List<...>`, se importa `package:flutter/foundation.dart` para usar `listEquals` y `Object.hashAll`.
- Relaciones (`relation: true`) permiten anidar modelos automáticamente.
- Se genera un `index.dart` ordenado alfabéticamente para un acceso rápido a los modelos.

---

## ✨ Futuras mejoras

- Soporte para anotaciones tipo `@JsonKey`.
- Separación opcional del Builder en otro archivo.

---

## 📜 Licencia

MIT License - Carlos Franklin

