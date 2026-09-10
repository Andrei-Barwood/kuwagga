# emodolls studio

App nativa macOS (Swift) de mastering true-mono. Producto aparte del CLI Python.

**Fuente de implementación (interrumpir / retomar):**
[`PROMPTS_IMPLEMENTACION.md`](PROMPTS_IMPLEMENTACION.md)

Licencia MIT. UI en español. Cero plugins comerciales.

## Terceros (LGPL)

DittoPRO usa **libmp3lame** (y **libmpg123**, dependencia de esa build) como dylibs de enlace dinámico en `EmodollsStudio/Vendor/`. No se incluye el código fuente de LAME ni de mpg123.

- LAME: LGPL — https://lame.sourceforge.io/
- mpg123: LGPL 2.1 — https://www.mpg123.de/

Puedes sustituir esos dylibs por otras builds compatibles con LGPL. El resto de emodolls studio sigue siendo MIT. Ver `EmodollsStudio/Vendor/NOTICE.txt`.
