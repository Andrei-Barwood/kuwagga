# 🎚️ Copy Mix + Mixer FX from Template Song

> Importa la configuración del mixer (faders, pan, etc.), efectos seleccionados y nombres de tracks desde una canción plantilla.

## 🎯 ¿Por qué es útil?

- **🔊 Cadena de mezcla**: Comparte EQ, compresores, reverb y demás FX entre canciones
- **📐 Consistencia de mix**: Misma configuración de volumen, pan y sends en todo el proyecto
- **⏱️ Ahorro de tiempo**: Evitas reconstruir cadenas de FX manualmente en cada canción

Contribuye al flujo **plantilla de mezcla → nueva canción → mix base listo** para grabar o producir.

---

## 📥 Instalación

1. Copia la carpeta `CopyMixerFxFromTemplate.xrnx` a la carpeta de Tools de Renoise
2. Reinicia Renoise o recarga Tools
3. Opcionalmente puedes arrastrar el tool directamente a tu app renoise y eso lo dejará instalado y listo para utilizar

---

## 📖 Tutorial de uso

### Paso 1: Guardar tu canción

⚠️ Tu canción destino debe estar guardada.

### Paso 2: Iniciar importación

- **Menú**: `Tools → Import Mix + Mixer FX from Template Song...`
- Selecciona el archivo plantilla (`.xrns`)

### Paso 3: Esperar carga de plantilla

- Renoise carga la plantilla temporalmente
- La herramienta detecta:
  - Efectos en tracks secuenciadores
  - Efectos en el Master
  - Estado del mixer (volumen, pan, etc.)
  - Nombres de tracks

### Paso 4: Seleccionar FX

- Se muestra una lista: `[Track] -> [Nombre FX]`
- Marca ☑️ los efectos que quieras importar
- Usa **Seleccionar / deseleccionar todos** si lo prefieres
- Pulsa **Importar seleccionados**

### Paso 5: Resultado

- La herramienta vuelve a tu canción
- Se crean o ajustan tracks para coincidir con la plantilla
- Se aplica la configuración del mixer
- Se insertan los FX seleccionados con sus presets
- Resumen: `Mezcla importada en X canal(es) | FX importados: Y`

---

## 📋 Qué se importa

| Elemento | Descripción |
|----------|-------------|
| **Mixer** | Volumen, pan, width y estado de cada canal |
| **FX de tracks** | Plugins insertados en cada track (excepto Mixer/Sampler base) |
| **FX de Master** | Cadena de efectos del bus Master |
| **Nombres de tracks** | Nombres de cada track secuenciador |
| **Estructura** | Número de tracks ajustado al de la plantilla |

---

## ⚠️ Comportamiento

- Si no seleccionas ningún FX, solo se importa la configuración del mixer
- Los tracks destino se limpian de contenido y FX antes de importar
- La plantilla no puede ser la misma canción que estás editando

---

## 🎵 En el proceso discográfico

- Crea una plantilla con tu cadena de mezcla estándar
- Usa la misma “base” en todas las canciones del álbum
- Acelera el setup inicial antes de grabar o producir
