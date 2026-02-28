# 🎺 Copy Instruments from Template Song

> Copia instrumentos seleccionados desde una canción plantilla a tu canción actual.

## 🎯 ¿Por qué es útil?

Las plantillas de instrumentos aceleran la producción:

- **📦 Librería de instrumentos**: Un .xrns con tus samples, mappings y FX favoritos
- **🔄 Consistencia**: Mismos instrumentos en todas las canciones de un álbum
- **⏱️ Tiempo**: Evitas cargar uno por uno desde el disco

Contribuye al flujo **plantilla master → nueva canción → instrumentos listos** en un solo paso.

---

## 📥 Instalación

1. Copia la carpeta `CopyInstrumentsFromTemplate.xrnx` a la carpeta de Tools de Renoise
2. Reinicia Renoise o recarga Tools
3. Opcionalmente puedes arrastrar el tool directamente a tu renoise y eso lo dejará instalado y listo para utilizar

---

## 📖 Tutorial de uso

### Paso 1: Guardar tu canción

⚠️ **Importante**: Tu canción destino debe estar guardada antes de usar la herramienta.

- Usa `Archivo → Guardar Como...` si aún no está guardada

### Paso 2: Iniciar la importación

- **Menú**: `Tools → Copy Instruments from Template Song...`
- Se abrirá un diálogo para seleccionar el archivo plantilla (`.xrns`)

### Paso 3: Elegir plantilla

- Navega hasta tu canción plantilla
- Selecciónala y pulsa Abrir
- Renoise cargará temporalmente la plantilla

### Paso 4: Seleccionar instrumentos

- Aparece una lista con los instrumentos de la plantilla
- Marca ☑️ los que quieras copiar
- Usa **Seleccionar / deseleccionar todos** para marcar o desmarcar todos
- Pulsa **Copiar seleccionados**

### Paso 5: Resultado

- La herramienta vuelve automáticamente a tu canción original
- Los instrumentos se añaden al final de la lista
- Los duplicados por nombre se omiten
- Verás un resumen: `Importados: X instrumento(s) | Omitidos (duplicados): Y`

---

## ⚠️ Notas

- La plantilla **no puede ser** la misma canción que estás editando
- Solo se copian instrumentos con contenido (nombre o samples)
- Los instrumentos se insertan al final; no reemplazan los existentes

---

## 🎵 En el proceso discográfico

- Usa una canción “master” con tus instrumentos base
- Crea nuevas canciones y aplica la plantilla para mantener coherencia de sonido
- Ideal para EPs y álbumes con paleta sonora definida
