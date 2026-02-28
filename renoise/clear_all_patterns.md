# 🧹 Clear All Patterns (Limpieza de patrones)

> Script Lua standalone que limpia el contenido de todos los patrones manteniendo su estructura (número de líneas, tracks, etc.).

## 🎯 ¿Por qué es útil?

- **📄 Plantillas vacías**: Convierte una canción con estructura definida en plantilla sin notas ni FX
- **🔄 Reset rápido**: Borra todo el contenido para empezar de cero sin perder formato
- **📐 Reutilización**: Mantiene longitudes y organización para copiar luego con **Copy Patterns from Template**

Contribuye al flujo **canción con estructura → limpieza → plantilla reutilizable**.

---

## 📥 Instalación y uso

Este script es un archivo Lua **standalone** (no es un tool .xrnx):

- Se ejecuta desde el **Lua Script Runner** de Renoise: `Tools → Lua Script → Run Script...`
- Selecciona el archivo `01_clear_all_buffers.lua`

---

## 📖 Tutorial de uso

### Paso 1: Tener una canción abierta

Abre la canción que quieras convertir en plantilla o limpiar.

### Paso 2: Ejecutar el script

- Menú: `Tools → Scripting Terminal & Editor...`
- Navega hasta `01_clear_all_buffers.lua`
- Ejecuta el script

### Paso 3: Confirmar

- Aparece un diálogo de confirmación:
  - Número de patrones que se limpiarán
  - Recordatorio de que se eliminarán notas, efectos y automatizaciones
- Elige **"Sí, limpiar todo"** o **"Cancelar"**

### Paso 4: Resultado

- Todos los patrones quedan vacíos
- Se mantiene: número de patrones, líneas por patrón, número de tracks, etc.
- Mensaje final: `Limpieza completada! N patrones han sido limpiados.`

---

## ⚠️ Importante

- Esta acción **no es deshacible** de forma automática tras cerrar el script
- Si quieres conservar la versión original, guarda una copia antes
- El script limpia **todos** los patrones de la canción actual

---

## 🎵 En el proceso discográfico

- Crea plantillas: produce una canción con estructura ideal, luego limpia y guarda como plantilla
- Útil para borrar contenido de demo y reutilizar solo la estructura
- Complementa **Copy Patterns from Template** para flujos de plantillas
