# Guia Completa: Liberar Espacio por OneDrive (macOS, Windows y Linux)

## 1) Para quien es esta guia
Esta guia esta pensada para usuarios que no son tecnicos y que notaron que su disco se lleno "de golpe" usando OneDrive.

Objetivo:
- Entender por que pasa.
- Ejecutar el script de forma segura.
- Liberar espacio sin improvisar.
- Tener un plan claro de recuperacion si algo no sale como esperas.

Mensaje importante:
- Este problema es comun y, en la gran mayoria de casos, **es reversible**.
- Que el disco se llene de repente **no significa automaticamente** que el equipo este dañado.

---

## 2) Por que el disco se llena repentinamente con OneDrive
El llenado repentino suele ocurrir por una combinacion de procesos automaticos:

1. **Descargas automáticas de archivos ("hidratacion")**
OneDrive puede traer copias locales completas de archivos que antes estaban solo en la nube.
Resultado: cientos de MB o varios GB en poco tiempo.

2. **Caches y logs que crecen**
OneDrive, el sistema y actualizadores guardan temporales, trazas y registros.
Resultado: espacio ocupado que no siempre se limpia solo.

3. **Actualizaciones fallidas o repetidas**
Si una actualizacion falla, se reintenta y acumula residuos de descarga.
Resultado: crecimiento invisible en carpetas de sistema.

4. **Indexacion de archivos (tipo Spotlight/Search/Tracker)**
El sistema indexa metadatos y contenido para busquedas rapidas.
Resultado: mas escritura en disco y mas espacio usado en bases de indice.

5. **Snapshots locales (Time Machine / VSS / timeshift)**
El sistema guarda puntos de restauracion/snapshots.
Resultado: consumo extra de disco, especialmente en equipos con poco espacio libre.

---

## 3) Que hace el script y que no hace
Archivo:
- `/kuwagga/02 - 2026/03 - marzo/onedrive_space_optimizer.py`

Servicios que puede ejecutar:
1. Desactivar automatismos de actualizacion de OneDrive.
2. Reducir descargas locales automaticas y limpiar cache/logs.
3. Desactivar indexacion tipo Spotlight/Search/Tracker.
4. Desactivar y limpiar snapshots locales.
5. Limpiar residuos de actualizaciones fallidas.

Lo que **no** hace:
- No borra tu cuenta de OneDrive.
- No formatea disco.
- No cambia tus archivos en la nube.
- En modo `DRY-RUN`, no aplica cambios reales.

---

## 4) Seguridad primero: DRY-RUN vs APPLY
`DRY-RUN`:
- Modo simulacion.
- Muestra exactamente que comandos ejecutaria.
- No borra, no desactiva, no modifica configuraciones reales.
- Ideal para revisar con calma antes de aplicar.

`APPLY`:
- Ejecuta cambios reales.
- Puede requerir permisos `sudo/admin`.
- El script pide confirmacion explicita escribiendo `SI`.

Recomendacion:
- Primero siempre `DRY-RUN`.
- Luego `APPLY` solo cuando entiendas el plan mostrado.

---

## 5) Requisitos minimos (flujo automatico con opcion 8)

en el rubro de la programación hay una frase sabia muy popular:
"confía si... pero siempre verifica"

para ello antes de hacer cualquier cambio ingresa a la opción 8 y selecciona el sub-menu 1 (ver guía completa de instalación) y sigue el tutorial paso a paso para realizar la instalación del python 3.13.9 en un entorno virtual de python para evitar conflictos con tu python nativo. La guía luego procede a mostrarte cómo generar el entorno virtual hokkaido (es convención you know)

y en general la idea es realizar 5 pasos con instrucciones detalladas y muy claras, es super intuitivo, después de eso deberías poder continuar sin obstaculos y sin tener que salirte del script a probar suerte en treinta sitios web


El flujo recomendado es usar el propio menu interactivo del producto, opcion `8`.

Requisitos generales:
1. Poder abrir el script desde terminal.
2. Conexion a internet (para instalar gestor si falta).
3. Permisos de administrador cuando se use `APPLY`.
4. Revisar primero en `DRY-RUN` y luego ejecutar en `APPLY`.

### Que hace exactamente la opcion 8
En el menu principal:
- `8. Guia e instalacion de gestor (por plataforma)`

Dentro del sub-menu:
1. `Ver guia completa de instalacion`
Muestra en pantalla los pasos de setup para la plataforma seleccionada.

2. `Instalar gestor de paquetes automaticamente`
Ejecuta instalacion real del gestor correspondiente a la plataforma activa:
- macOS: instala/valida `Homebrew`.
- Windows: instala/valida `Chocolatey`.
- Linux: detecta gestor nativo (`apt`, `dnf`, `pacman`, `zypper`); si no existe, instala `Linuxbrew`.

### Flujo recomendado paso a paso
1. Abre el programa en modo interactivo:

utiliza las comillas para la ruta de acceso porque los directorios y los archivos tienen espacio entre las palabras para mejorar la legibilidad

```bash
PYENV_VERSION=hokkaido pyenv exec python "/kuwagga/02 - 2026/03 - marzo/onedrive_space_optimizer.py" --menu
```
2. Deja el modo en `DRY-RUN`.
3. Entra a opcion `8`.
4. Ejecuta sub-opcion `2` para validar/instalar el gestor automaticamente.
5. Si todo se ve correcto, cambia a `APPLY` (opcion `3` del menu principal).
6. Vuelve a opcion `8` > sub-opcion `2` y confirma con `SI`.
7. Usa opcion `8` > sub-opcion `1` para ver en pantalla la guia de setup restante.

### Por que este flujo reemplaza los scripts manuales por plataforma
- Centraliza la instalacion dentro del producto.
- Evita que el usuario tenga que buscar instaladores en sitios externos.
- Reduce errores de copiado/pegado de comandos largos.
- Mantiene seguridad con confirmacion explicita y modo `DRY-RUN`.

### Comportamientos de seguridad importantes
- En `DRY-RUN` no hace cambios reales.
- En `APPLY` pide confirmacion escribiendo `SI`.
- Bloquea instalaciones en `APPLY` si la plataforma seleccionada no coincide con la plataforma real del equipo.

### Verificacion rapida esperada
- La sub-opcion `8 -> 2` termina con resumen sin fallos obligatorios.
- La opcion `8 -> 1` muestra la guia de instalacion completa de tu plataforma.
- El usuario no necesita salir del producto para resolver instalacion base.

---

## 6) Tutorial paso a paso (modo interactivo recomendado)

### Paso 1: abrir el menu interactivo
```bash
PYENV_VERSION=hokkaido pyenv exec python "/kuwagga/02 - 2026/03 - marzo/onedrive_space_optimizer.py" --menu
```

### Paso 2: confirmar plataforma y modo
Al abrir, verifica:
- plataforma actual,
- modo actual (`DRY-RUN`),
- explicacion detallada del modo.

Mantente en `DRY-RUN` para la primera pasada.

### Paso 3: usar opcion 8 (flujo automatico de instalacion)
Entra a:
- `8. Guia e instalacion de gestor (por plataforma)`

Dentro del sub-menu:
1. `1` para leer la guia completa de tu plataforma.
2. `2` para validar/instalar automaticamente el gestor de paquetes.

Con esto ya no necesitas copiar scripts manuales de macOS/Windows/Linux fuera del producto.

### Paso 4: ejecutar opcion 8 en DRY-RUN
Corre `8 -> 2` en `DRY-RUN` para auditar:
- que intentaria instalar,
- si detecta gestor nativo,
- si necesita Homebrew/Chocolatey/Linuxbrew.

### Paso 5: ejecutar opcion 8 en APPLY
Cuando el plan te parezca correcto:
1. vuelve al menu principal,
2. cambia a `APPLY` con opcion `3`,
3. entra de nuevo a `8 -> 2`,
4. confirma escribiendo `SI`.

### Paso 6: ejecutar limpieza de OneDrive
Luego de preparar la base con opcion 8:
1. elige `2. Elegir servicios de forma independiente` (recomendado),
2. empieza con `1,2,5` (OneDrive + Descargas + Updates fallidas),
3. revisa resultados,
4. despues evalua `3` (indexacion) y `4` (snapshots).

Si prefieres ejecutar todo:
- usa `1. Ejecutar TODOS los servicios en una misma sesion`.

### Paso 7: revisar resumen final
Al terminar cada sesion, revisa:
- cantidad de comandos,
- fallos obligatorios,
- fallos opcionales.

Si hay errores de permisos, repite con privilegios de administrador.

---

## 7) Uso rapido sin menu (opcional)
Si prefieres comandos directos:

Simulacion:
```bash
PYENV_VERSION=hokkaido pyenv exec python "/kuwagga/02 - 2026/03 - marzo/onedrive_space_optimizer.py" --no-menu --platform macos
```

Aplicacion real:
```bash
PYENV_VERSION=hokkaido pyenv exec python "/kuwagga/02 - 2026/03 - marzo/onedrive_space_optimizer.py" --no-menu --platform macos --apply
```

Ejemplo para omitir snapshots:
```bash
PYENV_VERSION=hokkaido pyenv exec python "/kuwagga/02 - 2026/03 - marzo/onedrive_space_optimizer.py" --no-menu --platform macos --skip-snapshots
```

---

## 8) Como interpretar mensajes frecuentes
`[DRY-RUN] comando...`
- Es solo simulacion.

`[INFO] OneDrive folder not found automatically`
- Debes indicar ruta manual con `--onedrive-path`.

`[WARN]` o `ERROR` con permisos
- Falta privilegio admin/sudo o el comando no aplica a tu entorno.

`LaunchAgent not found` / servicio no encontrado
- Normal en muchos equipos. No siempre implica problema.

---

## 9) Que esperar despues de la limpieza
Cambios habituales:
- aumento de espacio libre,
- menos actividad de disco,
- menos re-descargas automáticas,
- menos residuos de updates.

Importante:
- algunos servicios pueden tardar unos minutos en reflejar cambios.
- reiniciar el equipo puede ayudar a consolidar estado.

---

## 10) Plan de recuperacion (si quieres revertir)
Si necesitas restaurar comportamientos:

1. Rehabilitar indexacion (ejemplos):
```bash
# macOS
sudo mdutil -i on /

# Linux (tracker, segun distro)
systemctl --user unmask tracker-miner-fs-3.service tracker-extract-3.service tracker-store.service
```

2. Rehabilitar servicios manualmente:
- vuelve a activar en panel/servicios de tu sistema.
- OneDrive puede reactivarse iniciando sesion de nuevo.

3. Volver a ejecutar el script en `DRY-RUN` para revisar que cambio aplicaras.

---

## 11) FAQ corta

**Perdere mis archivos en la nube?**
- No por usar `DRY-RUN`.
- En `APPLY`, el enfoque es limpiar cache/residuos y desactivar automatismos, no borrar tu nube.

**Por que vuelve a llenarse el disco despues de unos dias?**
- Porque algun automatismo sigue activo o se reactivo tras una actualizacion.

**Debo usar siempre todos los servicios?**
- No. Puedes ejecutar solo los necesarios desde el menu independiente.

---

## 12) Recomendacion final para estar tranqui
1. Ejecuta `DRY-RUN`.
2. Revisa plan y comandos.
3. Aplica en `APPLY` solo lo que entiendes.
4. Verifica espacio libre.
5. Repite por bloques si prefieres control fino.

Este problema suele tener solucion por etapas. Con este flujo, mantienes control y reduces riesgos.
