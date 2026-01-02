# 🚀 GUÍA RÁPIDA - HTML to PDF Converter

## ⏱️ Instalación Expresada (5 minutos)

### 1. Copiar archivos necesarios
```bash
# Descargar o copiar a tu carpeta:
# - html_to_pdf_converter.py
# - requirements.txt
# - setup_project.sh
# - tu_archivo.html
```

### 2. Ejecutar setup automático
```bash
bash setup_project.sh
```

**Eso es todo.** El script configura:
- ✓ Entorno virtual
- ✓ Dependencias de Python
- ✓ Dependencias del sistema
- ✓ Archivos de configuración
- ✓ Estructura de directorios

---

## 🔄 Ejecución Rápida

### Método 1: Automático (Recomendado)
```bash
# El script configura todo automáticamente
bash setup_project.sh

# Luego simplemente:
./run_conversion.sh tu_archivo.html
```

### Método 2: Manual paso a paso
```bash
# 1. Activar entorno
source venv/bin/activate

# 2. Convertir
python html_to_pdf_converter.py tu_archivo.html

# 3. Resultado
# Tu PDF está en: tu_archivo_converted.pdf
```

### Método 3: Con opciones personalizadas
```bash
source venv/bin/activate

# Especificar salida
python html_to_pdf_converter.py entrada.html -o salida.pdf

# Con log personalizado
python html_to_pdf_converter.py entrada.html -o salida.pdf --log-file mi_log.log

# Sin inyección de CSS (si hay problemas)
python html_to_pdf_converter.py entrada.html --no-css-injection
```

---

## 📊 Resultado Esperado

```
✓ PDF generado exitosamente
Tamaño del archivo: 450.2 KB
Tiempo de conversión: 2.3 segundos
Páginas: 5
```

---

## 🔧 Solución Rápida de Problemas

### "ModuleNotFoundError: No module named 'weasyprint'"
```bash
# Solución:
source venv/bin/activate
pip install --force-reinstall weasyprint
```

### "No CSS/estilos en el PDF"
```bash
# Verificar que HTML tiene <style>
grep "<style" tu_archivo.html

# O ejecutar sin inyección CSS
python html_to_pdf_converter.py tu_archivo.html --no-css-injection
```

### "Tablas divididas entre páginas"
```bash
# Aumentar altura estimada en script (línea ~280):
# ROW_HEIGHT_MM = 10  # en lugar de 8

# O reducir márgenes (líneas ~48-51):
# MARGIN_TOP_MM = 10
# MARGIN_BOTTOM_MM = 10
```

### "Librerías del sistema no encontradas"

**Linux:**
```bash
sudo apt-get install -y libcairo2-dev libpango-1.0-0 libgdk-pixbuf2.0-0
pip install --force-reinstall weasyprint
```

**macOS:**
```bash
brew install cairo pango gdk-pixbuf
pip install --force-reinstall weasyprint
```

---

## 📁 Estructura de Archivos

```
tu_proyecto/
├── venv/                          # Entorno virtual (creado automáticamente)
├── scripts/
│   └── html_to_pdf_converter.py   # Script principal
├── data/
│   └── tu_archivo.html            # Archivos de entrada
├── output/
│   └── tu_archivo.pdf             # Archivos generados
├── logs/
│   └── conversion.log             # Registro de conversiones
├── requirements.txt               # Dependencias Python
├── setup_project.sh               # Script de setup
├── .env                           # Configuración (opcional)
└── run_conversion.sh              # Lanzador rápido
```

---

## ⚙️ Configuración (Opcional)

Editar `.env` para personalizar:

```bash
# Márgenes (mm)
MARGIN_TOP=15
MARGIN_BOTTOM=15

# Comportamiento
INJECT_PAGE_BREAK_CSS=true
PRESENTATIONAL_HINTS=true

# Altura de tablas (mm)
ROW_HEIGHT_MM=8
HEADER_HEIGHT_MM=10
```

---

## 📈 Características Incluidas

✓ Preservación completa de estilos CSS y colores
✓ Control inteligente de saltos de página en tablas
✓ Compatibilidad con fuentes personalizadas
✓ Logging detallado de conversión
✓ Análisis automático de tablas
✓ Cálculos de dimensionamiento
✓ Soporte para A4, Letter y otros formatos
✓ Márgenes configurables
✓ Reutilizable como plantilla

---

## 🎯 Casos de Uso

### Memorias de Cálculo Técnicas
```bash
python html_to_pdf_converter.py memoria_calculo.html
```
**Configurar:** `MARGIN_TOP=15, ROW_HEIGHT_MM=8`

### Reportes Empresariales
```bash
python html_to_pdf_converter.py reporte_2025.html -o reports/reporte_final.pdf
```
**Configurar:** `MARGIN_TOP=20, APPLY_PRINT_STYLES=true`

### Documentos Legales
```bash
python html_to_pdf_converter.py contrato.html --no-css-injection
```
**Configurar:** `COMPRESS=false, INCLUDE_METADATA=true`

### Generación en Lote
```bash
for archivo in *.html; do
    python html_to_pdf_converter.py "$archivo" -o "output/${archivo%.html}.pdf"
done
```

---

## 📊 Comandos Útiles

```bash
# Ver todas las conversiones
cat conversion.log

# Ver solo errores
grep ERROR conversion.log

# Ver análisis de tablas
grep "Tabla" conversion.log

# Ver estadísticas del documento
grep "Estadísticas" conversion.log

# Buscar una conversión específica
grep "tu_archivo" conversion.log

# Limpiar logs antiguos
> conversion.log
```

---

## 🔍 Debugging

### Ver HTML temporal generado
```bash
# El script guarda index_2_temp.html
cat index_2_temp.html

# Buscar CSS inyectado
grep "page-break-inside" index_2_temp.html
```

### Medir tiempo de conversión
```bash
time python html_to_pdf_converter.py tu_archivo.html
```

### Verificar dependencias instaladas
```bash
pip list | grep -E "weasyprint|requests|lxml"
```

---

## 📚 Documentación Completa

- **Tutorial Paso a Paso:** `TUTORIAL_COMPLETO.md`
- **Cálculos de Dimensionamiento:** `CALCULOS_DIMENSIONAMIENTO.md`
- **Referencia de API:** Véase comentarios en `html_to_pdf_converter.py`

---

## ✅ Checklist Pre-Conversión

- [ ] Archivo HTML en carpeta correcta
- [ ] Entorno virtual activado
- [ ] Dependencias instaladas (`pip list | grep weasyprint`)
- [ ] HTML tiene estilos CSS definidos
- [ ] Tablas no son excesivamente grandes
- [ ] Fuentes están disponibles en el sistema

---

## 🎓 Próximos Pasos

1. **Entender los parámetros:**
   Editar líneas 45-55 en `html_to_pdf_converter.py`

2. **Personalizar estilos:**
   Modificar `PAGE_BREAK_CSS` (línea 88)

3. **Automatizar más:**
   Ver sección "Generación en Lote"

4. **Integrar en aplicaciones:**
   Importar `HTMLtoPDFConverter` en tus scripts

---

## 💡 Consejos Profesionales

### Para Memorias de Cálculo
```python
# En script, aumentar altura de tabla:
ROW_HEIGHT_MM = 10
# Previene que tablas largas se corten
```

### Para Documentos Públicos
```python
# En script, añadir metadatos:
# Véase línea ~400 para implement
ación
```

### Para Archivos Reutilizables
```bash
# Guardar configuración en .env
cp .env.example .env
# Personalizar valores
# Reutilizar con diferentes archivos HTML
```

---

## 🆘 Soporte Rápido

**¿El PDF no tiene colores?**
→ Verificar que HTML tiene `<style>` tags con definiciones de color

**¿Faltan imágenes?**
→ Usar rutas absolutas en HTML o `file://` protocol

**¿Se ve borroso?**
→ Aumentar `PDF_ZOOM=1.2` o `1.5` en `.env`

**¿Muy lento?**
→ Reducir complejidad del HTML o usar `--no-css-injection`

---

## 📞 Referencia Rápida de Comandos

```bash
# Setup inicial
bash setup_project.sh

# Conversión simple
./run_conversion.sh archivo.html

# Conversión con opciones
python scripts/html_to_pdf_converter.py data/archivo.html -o output/resultado.pdf

# Ver logs
tail -f conversion.log

# Múltiples archivos
for f in data/*.html; do python scripts/html_to_pdf_converter.py "$f"; done

# Limpiar
rm -rf venv output/* logs/*
```

---

**¡Ahora tienes todo listo para convertir tus HTML a PDF! 🎉**

**Próximo paso:** Ejecuta `bash setup_project.sh`
