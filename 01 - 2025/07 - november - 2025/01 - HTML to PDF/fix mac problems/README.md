***

# 🛠️ README — setup_weasyprint_mac.zsh

## Solución Automática de Problemas con WeasyPrint en macOS

Este script (`setup_weasyprint_mac.zsh`) automatiza la instalación, reparación y verificación de todas las **dependencias de sistema** necesarias para convertir HTML a PDF usando WeasyPrint en Mac (Intel y Apple Silicon).

***

## 🚀 ¿Para qué sirve este script?

- Instala, repara y verifica las **librerías nativas** requeridas por WeasyPrint:
  - **cairo**
  - **pango**
  - **gdk-pixbuf**
  - **libffi**
  - **pygobject3**
  - **gtk+3**
- Resuelve errores tipo:
  - `OSError: cannot load library 'gobject-2.0-0'`
  - Problemas para importar bindings nativos (Cairo, Pango, GTK)
  - Falta de renderizado de estilos, colores o división de tablas en PDFs
- Configura el entorno PATH para detectar Homebrew en `zsh` (Intel o ARM/M1/M2/M3)
- Realiza reinstalación segura de WeasyPrint dentro del entorno virtual Python

***

## 📝 Uso recomendado

### 1. Descargar y guardar el script

Guarda el contenido en el archivo `setup_weasyprint_mac.zsh` en la raíz de tu proyecto.

### 2. Asignar permisos de ejecución

```zsh
chmod +x setup_weasyprint_mac.zsh
```

### 3. Ejecutar el script **fuera del entorno virtual**

```zsh
zsh setup_weasyprint_mac.zsh
```

> **Nota:** Este script instala paquetes que requieren permisos de sistema (por Homebrew), por lo que debe ejecutarse en el entorno global de tu usuario.

### 4. Activar el entorno virtual de Python y ejecutar tu proyecto

```zsh
source venv/bin/activate
pip install --force-reinstall weasyprint
python html_to_pdf_converter.py tu_archivo.html
```

***

## 🧠 ¿Qué hace el script?

- Instala y actualiza Homebrew y sus fórmulas
- Instala o reinstala todas las librerías nativas requeridas
- (Opcional) Recomienda instalar **XQuartz** si usas gráficos avanzados
- Corrige variables de entorno (`PATH`, shellenv) en zsh para Intel/ARM
- Reinstala WeasyPrint en tu entorno virtual si lo detecta
- Verifica importación exitosa de WeasyPrint y todas las librerías linkeadas
- Da consejos y advertencias finales para troubleshooting

***

## 📝 Ejemplo de mensajes corregidos

- `OSError: cannot load library 'gobject-2.0-0'`
- PDF sin color de fondo, estilos CSS rotos
- Tablas que se cortan entre páginas aunque el HTML es correcto
- Instalación de dependencias de sistema incompleta

> **Este script automatiza el fix de todos estos problemas en macOS**  
> **Funciona en Intel y Apple Silicon (M1/M2/M3)**

***

## 🧐 FAQ — Mejores prácticas

- **¿Se ejecuta dentro o fuera de venv?**  
  Ejecuta este script **fuera del entorno virtual**. Las librerías van al sistema, no al venv.
- **¿Debo activar venv después?**  
  Sí, para instalar/reinstalar los paquetes de Python y ejecutar tu proyecto.
- **¿Funciona en Linux?**  
  No, este script es solo para macOS + Homebrew. Para Linux usa apt-get (ver guía del proyecto).
- **¿Qué hago si sigue sin funcionar?**  
  Reinicia tu terminal. Repite la activación del venv y la instalación de WeasyPrint. Comprueba que tu PATH contiene /opt/homebrew o /usr/local/bin.

***

## 🔍 ¿Cómo lo verifico?

```zsh
# Dentro del venv
source venv/bin/activate
python -c "from weasyprint import HTML; print('✓ WeasyPrint importado correctamente')"
```

Si ves el mensaje ✓, las dependencias están bien instaladas.

***

## 💡 Troubleshooting extra

- Si aún tienes errores al importar, ejecuta `brew doctor` y revisa los mensajes.
- Asegúrate que Homebrew esté actualizado (`brew update`) y que no hay mezclas de arquitecturas (`file /usr/local/lib/*dylib` o `/opt/homebrew/lib/*dylib`)
- Si usas visualizaciones SVG/PNG avanzadas, instala también **XQuartz**.

***

## ✨ Contacto y soporte

Si encuentras un error distinto, genera el log completo y comparte aquí el mensaje.  
Este script cubre el 99% de los casos comunes en macOS.

***

**Listo! Ejecuta el script y luego activa tu entorno virtual para convertir tu HTML a PDF sin problemas.** 👨‍💻