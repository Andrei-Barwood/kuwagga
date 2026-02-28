# 📋 Copy Patterns from Template Song

> Reemplaza todos los patrones de la canción actual con el contenido, longitudes y orden de secuencia de una canción plantilla.

## 🎯 ¿Por qué es útil?

- **🏗️ Estructura base**: Usa una plantilla con intro, versos, estribillos y outro
- **📐 Longitudes de patrones**: Copia patrones de 96, 192, 384 líneas ya definidos
- **🔄 Secuenciador**: Mantiene el orden exacto de patrones en la secuencia

Contribuye al flujo **plantilla de estructura → nueva canción → base lista para componer**.

---

## 📥 Instalación

1. Copia la carpeta `CopyPatternsFromTemplate.xrnx` a la carpeta de Tools de Renoise
2. Reinicia Renoise o recarga Tools
3. Opcionalmente puedes arrastrar el tool a renoise y quedará instalado y listo para utilizar

---

## 📖 Tutorial de uso

### Paso 1: Guardar tu canción

⚠️ Tu canción destino debe estar guardada.

### Paso 2: Iniciar importación

- **Menú**: `Tools → Copy Patterns from Template Song...`
- Selecciona el archivo plantilla (`.xrns`)

### Paso 3: Carga de plantilla

- Renoise carga la plantilla temporalmente
- La herramienta captura:
  - Número y orden de patrones
  - Líneas de cada patrón
  - Notas, instrumentos, volumen, panning, delays
  - Efectos (Efx) por línea
  - Secuencia del secuenciador

### Paso 4: Resultado automático

- Vuelve automáticamente a tu canción
- Crea o elimina tracks para coincidir con la plantilla
- Crea o elimina patrones según la plantilla
- Reemplaza todo el contenido de patrones
- Aplica longitudes y orden de secuencia
- Resumen: `Patrones importados: X | Duraciones aplicadas: Y | Orden de secuencia: Z pasos`

---

## 📋 Qué se copia

| Elemento | Descripción |
|----------|-------------|
| **Patrones** | Notas, instrumentos, volumen, pan, delay, efectos |
| **Longitudes** | Número de líneas de cada patrón (p. ej. 4, 8, 16, 32, 64, 128) |
| **Secuencia** | Orden de patrones en el secuenciador |
| **Tracks** | Número de tracks y columnas visibles |
| **Columnas** | Note columns y effect columns según la plantilla |

---

## ⚠️ Importante

- Todo el contenido de patrones de la canción actual se reemplaza
- La plantilla no puede ser la misma canción que estás editando
- Si la plantilla está vacía o tiene errores, la herramienta lo indicará

---

## 🎵 En el proceso discográfico

- Usa una plantilla con estructura típica (intro/verso/estribillo/outro)
- Si trabajas con Formatos Instrumentales de Spitfire Audio en renoise puedes utilizar tu plantilla compleja avanzada para forma Sonata 'ABA B CDC' en formato sinfonía (proporciones enormes) con total normalidad no tienes que construir todo desde cero y perder tiempo valioso de redacción o musicalización en añadir linea por linea
- Aporta carácter a tu composición musical asignándole la lógica necesaria a tu creación sin la necesidad de imponer una única técnica o un único estilo, y sin alterar el enfoque vacío cuando el proyecto está en silencio
- Aplica la plantilla a nuevas canciones para mantener formato consistente
- Combina con **Pattern Line Balancer** para patrones uniformes y con **Copy Instruments** y **Copy Mix+Mixer FX** para un setup completo
