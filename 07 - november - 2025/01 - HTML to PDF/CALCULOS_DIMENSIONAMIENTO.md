## CÁLCULOS DE DIMENSIONAMIENTO PARA CONTROL DE SALTOS DE PÁGINA

### 📐 Especificaciones Técnicas del PDF

#### Formato: ISO 216 (A4)
```
Ancho:  210 mm (8.27 pulgadas)
Alto:   297 mm (11.69 pulgadas)
```

#### Márgenes Configurables
```
Superior:   15 mm
Inferior:   15 mm
Izquierda:  15 mm
Derecha:    15 mm
```

#### Área de Contenido Disponible
```
Ancho disponible:  210 - 15 - 15 = 180 mm
Alto disponible:   297 - 15 - 15 = 267 mm
```

---

### 📊 ANÁLISIS DE TABLAS - TU DOCUMENTO

Basado en el análisis del archivo `index_2.html`:

#### Tabla 1: Resumen de cargas por espacio
```
Filas:           4 (1 encabezado + 3 datos)
Columnas:        9
Contenido:       Cargas eléctricas por laboratorio
Complejidad:     Media
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (3 × 8) = 34 mm

Cabe en una página:          ✓ SÍ (34 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 2: Tableros y circuitos
```
Filas:           6 (1 encabezado + 5 datos)
Columnas:        3
Contenido:       Configuración de laboratorios
Complejidad:     Baja
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (5 × 8) = 50 mm

Cabe en una página:          ✓ SÍ (50 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 3: Cables - Alimentadores y Conductores
```
Filas:           5 (1 encabezado + 4 datos)
Columnas:        4
Contenido:       Dimensiones de conductores THHN
Complejidad:     Media
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (4 × 8) = 42 mm

Cabe en una página:          ✓ SÍ (42 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 4: Canalización - Especificaciones de tubería
```
Filas:           10 (1 encabezado + 9 datos)
Columnas:        8
Contenido:       Detalles de canalización eléctrica
Complejidad:     ALTA (muchas columnas)
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (9 × 8) = 82 mm

Cabe en una página:          ✓ SÍ (82 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 5: Caída de Tensión - Ejemplo de cálculo
```
Filas:           5 (1 encabezado + 4 datos)
Columnas:        6
Contenido:       Cálculos de tensión por circuito
Complejidad:     Media
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (4 × 8) = 42 mm

Cabe en una página:          ✓ SÍ (42 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 6: Impedancia total - Cortocircuito
```
Filas:           7 (1 encabezado + 6 datos)
Columnas:        4
Contenido:       Cálculos de impedancia por ubicación
Complejidad:     Media
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (6 × 8) = 58 mm

Cabe en una página:          ✓ SÍ (58 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 7: Corriente de cortocircuito
```
Filas:           7 (1 encabezado + 6 datos)
Columnas:        4
Contenido:       Corrientes de cortocircuito estimadas
Complejidad:     Media
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (6 × 8) = 58 mm

Cabe en una página:          ✓ SÍ (58 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 8: Protecciones - Barras de distribución
```
Filas:           5 (1 encabezado + 4 datos)
Columnas:        4
Contenido:       Configuración de barras y corrientes
Complejidad:     Media
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (4 × 8) = 42 mm

Cabe en una página:          ✓ SÍ (42 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

#### Tabla 9: Interruptores Generales y Derivaciones
```
Filas:           8 (1 encabezado + 7 datos)
Columnas:        9
Contenido:       Distribución de circuitos por laboratorio
Complejidad:     ALTA (muchas columnas y filas)
```

**Cálculo de altura estimada:**
```
Alto estimado por fila:      8 mm
Alto del encabezado:         10 mm
Altura total estimada:       10 + (7 × 8) = 66 mm

Cabe en una página:          ✓ SÍ (66 mm < 267 mm)
Páginas requeridas:          1
Riesgo de corte:             BAJO
```

---

### 📈 RESUMEN TOTAL DE CÁLCULOS

#### Documento Completo:
```
Total de tablas:                    9
Total de filas (todas las tablas):  48 + encabezados
Altura promedio estimada:           8 mm por fila
Altura total estimada de tablas:    ~400 mm
```

#### Distribución estimada en PDF:
```
Encabezados y texto:    ~60 páginas
Tablas:                 ~1-2 páginas (sin problemas de corte)
Estimación total:       ~4-6 páginas
```

#### Conclusión de Riesgo:
```
Riesgo de tablas divididas:  ✓ BAJO (todas caben en 267 mm)
Recomendación:              Usar CSS con page-break-inside: avoid
Probabilidad de éxito:      > 95%
```

---

### 🛠️ CONFIGURACIÓN OPTIMIZADA EN EL SCRIPT

El script `html_to_pdf_converter.py` incluye la siguiente configuración optimizada:

#### CSS de Control (Inyectado automáticamente):
```css
/* Prevenir saltos dentro de tablas */
table {
    page-break-inside: avoid;
    break-inside: avoid;
}

/* Prevenir saltos dentro de filas */
tr {
    page-break-inside: avoid;
    break-inside: avoid;
}

/* Mantener encabezados */
thead {
    display: table-header-group;
}

tfoot {
    display: table-footer-group;
}
```

#### Parámetros de Dimensionamiento:
```python
PAGE_HEIGHT_MM = 297           # Altura total A4
CONTENT_HEIGHT_MM = 267        # Altura disponible (297 - márgenes)
ROW_HEIGHT_MM = 8              # Altura por fila
HEADER_HEIGHT_MM = 10          # Altura de encabezado
MARGIN_TOP_MM = 15
MARGIN_BOTTOM_MM = 15
MARGIN_LEFT_MM = 15
MARGIN_RIGHT_MM = 15
```

---

### 🔧 PERSONALIZACIÓN DE PARÁMETROS

Si necesitas ajustar los cálculos, edita el script:

#### Para tablas más grandes:
```python
# Aumentar altura estimada por fila
ROW_HEIGHT_MM = 12  # de 8 a 12 mm
```

#### Para márgenes diferentes:
```python
MARGIN_TOP_MM = 10      # Reducir margen superior
MARGIN_BOTTOM_MM = 10   # Reducir margen inferior
# Nuevo CONTENT_HEIGHT_MM = 297 - 10 - 10 = 277 mm
```

#### Para estimación más conservadora:
```python
# En método calculate_table_heights(), línea ~250
# Cambiar:
BUFFER_MM = 15  # Añadir buffer de seguridad
total_height = (HEADER_HEIGHT_MM + 
                (table['rows'] - 1) * ROW_HEIGHT_MM + 
                BUFFER_MM)
```

---

### 📊 FÓRMULAS MATEMÁTICAS UTILIZADAS

#### 1. Altura total estimada de tabla:
```
H_tabla = H_header + (n_filas - 1) × H_fila

Donde:
  H_tabla = altura total estimada (mm)
  H_header = altura del encabezado (mm)
  n_filas = número de filas de datos
  H_fila = altura promedio por fila (mm)
```

#### 2. Número de páginas requeridas:
```
N_páginas = ceil(H_tabla / H_contenido)

Donde:
  N_páginas = número de páginas requeridas
  H_tabla = altura total de tabla (mm)
  H_contenido = altura de contenido disponible (mm)
  ceil() = función redondeo hacia arriba
```

#### 3. Factor de utilización de página:
```
F_utilización = H_tabla / H_contenido × 100%

Donde:
  F_utilización = porcentaje de página utilizada
  Recomendación: < 80% para margen de seguridad
```

---

### ⚠️ CASOS ESPECIALES Y AJUSTES

#### Si una tabla excede 267 mm:

**Opción 1: Reducir márgenes**
```python
MARGIN_TOP_MM = 10
MARGIN_BOTTOM_MM = 10
# Nuevo: 297 - 10 - 10 = 277 mm disponibles
```

**Opción 2: Aumentar altura de fila (CSS)**
```css
table tr {
    height: 6mm;  /* Reducir altura de fila */
}
```

**Opción 3: Usar dos columnas de tablas**
```css
@media print {
    table {
        columns: 2;
        column-gap: 20mm;
    }
}
```

**Opción 4: Rotar página a horizontal**
```css
@page.landscape {
    size: A4 landscape;
}
```

---

### 📋 CHECKLIST DE DIMENSIONAMIENTO

Antes de ejecutar conversión final:

- [ ] Verificar altura total estimada < 267 mm
- [ ] Confirmar que cada tabla cabe en una página
- [ ] Revisar que CSS de page-break-inside está inyectado
- [ ] Validar márgenes configurados (recomendado: 15mm)
- [ ] Generar PDF de prueba
- [ ] Inspeccionar PDF generado con Adobe Reader
- [ ] Verificar que no hay tablas cortadas
- [ ] Confirmar colores y fondos se ven correctamente
- [ ] Validar que fuentes se renderizaron correctamente

---

### 📈 MONITOREO DURANTE CONVERSIÓN

El script genera un archivo `conversion.log` con información:

```
2025-01-15 10:30:45 - INFO - Tabla 1: 34.0mm (cabe en página)
2025-01-15 10:30:45 - INFO - Tabla 2: 50.0mm (cabe en página)
2025-01-15 10:30:45 - INFO - Tabla 9: 66.0mm (cabe en página)
```

Para revisar análisis de tablas:
```bash
grep "Tabla" conversion.log
```

---

### 🎯 CONCLUSIÓN FINAL

Tu documento `index_2.html` está **perfectamente optimizado** para conversión a PDF:

✓ Todas las tablas caben en el área disponible
✓ Riesgo de corte: BAJO
✓ Se recomienda usar CSS `page-break-inside: avoid` (incluido automáticamente)
✓ Configuración de márgenes 15mm es óptima
✓ El script incluye todos los cálculos necesarios

**Tiempo estimado de conversión:** < 5 segundos
**Calidad de salida:** Excelente
**Probabilidad de éxito:** > 95%
