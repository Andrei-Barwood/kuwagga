# ⚖️ Pattern Line Balancer (Configurar Longitud de Buffer)

> Automatiza la cantidad de líneas de cada patrón para equilibrar tu flujo de trabajo en Renoise.

## 🎯 ¿Por qué es útil?

La longitud de los patrones influye en:

- **📐 Estructura de canción**: Bloques de 96, 192 o 384 líneas para secciones claras
- **🔄 Consistencia**: Evitar patrones con longitudes dispares (ej. 67 vs 13 líneas)
- **📋 Plantillas**: Preparar proyectos con patrones uniformes para copiar a nuevas canciones

Contribuye al flujo **diseño de estructura → plantilla → producción** manteniendo patrones ordenados.

---

## 📥 Instalación

1. Copia la carpeta `com.kirtantegsingh.configurar_buffers.xrnx` a la carpeta de Tools de Renoise
2. Reinicia Renoise o recarga Tools
3. Opcionalmente puedes arrastrar el tool directamente en tu sesión de renoise y eso lo instalará sin tener que bucear todo tu finder

---

## 📖 Tutorial de uso

### Paso 1: Abrir el diálogo

- **Menú**: `Tools → Pattern Line Balancer...`

### Paso 2: Elegir modo

Hay dos modos:

#### Modo A (Uniforme)

- Todos los patrones adoptan el mismo número de líneas
- Ajusta **Líneas Globales** (1–512)
- Pulsa **Aplicar** para aplicar el valor a todos los patrones

#### Modo B (Individual)

- Ajusta cada patrón por separado
- Usa la lista con scroll para ver patrones
- Marca ☑️ los patrones que quieras modificar
- Cambia el valor de líneas en cada fila
- Pulsa **Aplicar** para aplicar solo los patrones seleccionados

### Paso 3: Aplicar

- Pulsa **Aplicar** para ejecutar los cambios
- La operación es deshacible (tiene Undo)

---

## 📊 Información útil

- **Promedio**: Muestra el promedio de líneas de todos los patrones
- **Desplazar**: Scrollbar cuando hay más de 5 patrones para navegar
- Valores válidos: entre 1 y 512 líneas

---

## 🎵 En el proceso de producción

- Normaliza longitudes antes de usar **Copy Patterns from Template**
- Útil para preparar plantillas de proyecto con bloques de 96 u 192 líneas
- Evita patrones “raros” que dificultan la edición y el análisis de la estructura
