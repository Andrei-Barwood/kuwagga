#!/usr/bin/env python3
"""
Script Verification Tool v2.0 - Modular con Categorías
Verificación de Scripts del Repositorio organizada por categorías
Basado en las categorías del README.md
"""

import os
import sys
import subprocess
import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Colores ANSI
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'  # No Color

# Directorio raíz del repositorio
REPO_ROOT = Path(__file__).parent.resolve()

# ============================================================================
# DEFINICIÓN DE CATEGORÍAS (basadas en README.md)
# ============================================================================

CATEGORIES: Dict[str, Dict[str, List[str]]] = {
    "audio_video": {
        "name": "Conversión de Audio/Video",
        "paths": [
            "01 - 2025/08 - december - 2025/06_m4a_to_mp4.zsh",
            "01 - 2025/06 - October - 2025/wav_to_m4a.zsh",
            "01 - 2025/07 - november - 2025/12_m4a_to_mp3.zsh",
            "01 - 2025/07 - november - 2025/10_flac_to_mp4_converter.zsh",
            "01 - 2025/08 - december - 2025/01_m4a_mp3_flac_tags.zsh",
            "01 - 2025/08 - december - 2025/02_tags_template_generator.zsh",
            "01 - 2025/07 - november - 2025/11_add_img_to_mp3.zsh",
        ]
    },
    "documentos": {
        "name": "Conversión de Documentos",
        "paths": [
            "02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf.py",
            "02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_auto.py",
            "02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_pandoc.py",
            "02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_reportlab.py",
            "02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_simple.py",
            "02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_weasyprint.py",
            "01 - 2025/08 - december - 2025/12_wiki_to_pdf.zsh",
            "01 - 2025/08 - december - 2025/13_translate_pdf/translate_pdf.py",
            "01 - 2025/08 - december - 2025/13_translate_pdf/translate_pdf_cli.py",
            "01 - 2025/07 - november - 2025/01 - HTML to PDF/html_to_pdf_converter.py",
            "01 - 2025/07 - november - 2025/01 - HTML to PDF/setup_project.sh",
            "01 - 2025/07 - november - 2025/01 - HTML to PDF/setup_weasyprint_mac_intel_silicon.zsh",
        ]
    },
    "disco": {
        "name": "Gestión y Monitoreo de Disco",
        "paths": [
            "01 - 2025/08 - december - 2025/07_disk_guard.zsh",
            "01 - 2025/01 - Junio - 2025/19 de junio - 2025/01_disk_guard.zsh",
            "01 - 2025/01 - Junio - 2025/19 de junio - 2025/02_disk_guard_plus.zsh",
            "01 - 2025/01 - Junio - 2025/19 de junio - 2025/03_disk_guard_daemon.zsh",
            "01 - 2025/01 - Junio - 2025/19 de junio - 2025/04_auditor_disco_macos.zsh",
            "01 - 2025/08 - december - 2025/08_disk_scanner.sh",
            "01 - 2025/01 - Junio - 2025/30 de Junio - 2025/01_registro_espacio_libre.zsh",
            "01 - 2025/01 - Junio - 2025/30 de Junio - 2025/02_rastreador_cambios_disco.zsh",
            "01 - 2025/01 - Junio - 2025/30 de Junio - 2025/03_vigia_escritura_fisica.zsh",
            "01 - 2025/01 - Junio - 2025/30 de Junio - 2025/04_informe_volumenes.zsh",
            "01 - 2025/01 - Junio - 2025/30 de Junio - 2025/05_bloqueo_indexado_volumenes.zsh",
            "01 - 2025/08 - december - 2025/09_stop_the_bleeding.sh",
            "01 - 2025/01 - Junio - 2025/20 de Junio - 2025/03_disk_guardian_reforzado_clean.sh",
        ]
    },
    "memoria": {
        "name": "Monitoreo de Memoria",
        "paths": [
            "01 - 2025/05 - September 2025/memory_pressure_monitor.zsh",
            "01 - 2025/05 - September 2025/memory_pressure_monitor_advanced_notification_features.zsh",
            "01 - 2025/05 - September 2025/memory_pressure_monitor_notification_center.zsh",
            "01 - 2025/05 - September 2025/memory_pressure_monitor_with_cron.zsh",
            "01 - 2025/05 - September 2025/memory_pressure_simulator.zsh",
        ]
    },
    "macos": {
        "name": "Herramientas de Sistema macOS",
        "paths": [
            "01 - 2025/04 - August - 2025/01 - put back from trash.zsh",
            "01 - 2025/04 - August - 2025/02 - restore preview.zsh",
            "01 - 2025/04 - August - 2025/03 - undo git commit.zsh",
            "01 - 2025/04 - August - 2025/04 - stop icloud automatic downloads.zsh",
            "01 - 2025/01 - Junio - 2025/19 de junio - 2025/05_limpiar_cryptex.zsh",
            "01 - 2025/01 - Junio - 2025/19 de junio - 2025/06_revisar_purgeable_finder.zsh",
            "01 - 2025/01 - Junio - 2025/19 de junio - 2025/07_bloquear_tethering_riesgoso.zsh",
            "01 - 2025/01 - Junio - 2025/29 de junio - 2025/01_uninstall_cleanmymac.zsh",
            "01 - 2025/01 - Junio - 2025/29 de junio - 2025/02_liberar_snapshot.zsh",
            "01 - 2025/08 - december - 2025/10_remove_macOS_installer_leftovers.sh",
            "01 - 2025/07 - november - 2025/13_install_sequoia.sh",
            "01 - 2025/07 - november - 2025/14_upgrade_legacy_macs.sh",
            "01 - 2025/07 - november - 2025/15_from_lion_to_el_capitan.sh",
            "01 - 2025/07 - november - 2025/16_from_el_capitan_to_high_sierra.sh",
        ]
    },
    "recuperacion": {
        "name": "Recuperación de Datos",
        "paths": [
            "01 - 2025/07 - november - 2025/01_data_recovery.py",
            "01 - 2025/07 - november - 2025/02_data_recovery_installer.py",
        ]
    },
    "matematicas": {
        "name": "Herramientas Matemáticas/Educativas",
        "paths": [
            "01 - 2025/07 - november - 2025/05_teoria_de_conjuntos.py",
            "01 - 2025/07 - november - 2025/06_el_complemento_de_un_conjunto.py",
            "01 - 2025/07 - november - 2025/07_union_de_conjuntos.py",
            "01 - 2025/07 - november - 2025/08_interseccion_de_conjuntos.py",
            "01 - 2025/07 - november - 2025/09_disyuncion_diferencia_y_diferencia_simetrica.py",
            "01 - 2025/07 - november - 2025/04_tabla_pt100.py",
            "aemaeth/01_trig_func.py",
        ]
    },
    "git": {
        "name": "Herramientas de Git",
        "paths": [
            "01 - 2025/07 - november - 2025/18_observar_cambios_en_commits.sh",
            "02 - 2026/01 - enero/01 - reduce git repo size/clean-git-history.sh",
        ]
    },
    "build": {
        "name": "Build Scripts",
        "paths": [
            "01 - 2025/05 - September 2025/01_build_flint_w_dep.zsh",
            "01 - 2025/05 - September 2025/02_build_flint_w_dep_http2_framing.zsh",
            "01 - 2025/05 - September 2025/03_build_flint_w_dep_http2_framing_mac_os_only.zsh",
            "01 - 2025/05 - September 2025/04_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/05_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/06_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/07_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/08_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/09_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/10_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/11_build_flint_w_dep_http2_framing_apple_silicon_only.zsh",
            "01 - 2025/05 - September 2025/12_fix_framework_symlinks.zsh",
        ]
    },
    "limpieza": {
        "name": "Limpieza y Mantenimiento",
        "paths": [
            "01 - 2025/08 - december - 2025/11_hunter.zsh",
            "01 - 2025/08 - december - 2025/05_uninstall_bassmaster_loopmasters.zsh",
            "01 - 2025/07 - november - 2025/03_renombrar_imagenes.zsh",
            "01 - 2025/02 - Julio - 2025/01 - 6 de Julio/01_desinstalador_de_apps.zsh",
            "01 - 2025/02 - Julio - 2025/01 - 6 de Julio/02_eliminar_duplicados.zsh",
            "01 - 2025/02 - Julio - 2025/02 - 11 de Julio/01_eliminar_duplicados.py",
            "01 - 2025/02 - Julio - 2025/03 - 12 de Julio/01_eliminar_duplicados_en_discos_externos.py",
            "01 - 2025/02 - Julio - 2025/05 - 21 de Julio/01 - Directory Finder.zsh",
            "01 - 2025/02 - Julio - 2025/06 - 22 de Julio/01_file_and_dirs_finder.zsh",
        ]
    },
    "temas": {
        "name": "Temas y Personalización",
        "paths": [
            "01 - 2025/08 - december - 2025/install_tank_theme.zsh",
            "01 - 2025/08 - december - 2025/test_tank_colors.zsh",
        ]
    },
    "varias": {
        "name": "Herramientas Varias",
        "paths": [
            "01 - 2025/07 - november - 2025/setup_project.zsh",
            "verify_scripts.py",
        ]
    },
}

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

def log_info(msg: str) -> None:
    print(f"{CYAN}▶{NC} {msg}")

def log_success(msg: str) -> None:
    print(f"{GREEN}✓{NC} {msg}")

def log_warning(msg: str) -> None:
    print(f"{YELLOW}⚠{NC}  {msg}")

def log_error(msg: str) -> None:
    print(f"{RED}✗{NC} {msg}", file=sys.stderr)

# ============================================================================
# FUNCIONES DE VERIFICACIÓN
# ============================================================================

def check_shebang(script_path: Path) -> bool:
    """Verifica si el script tiene un shebang apropiado"""
    try:
        with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
            first_line = f.readline().strip()
        
        ext = script_path.suffix.lower()
        
        if ext == '.zsh':
            return bool(re.match(r'^#!/.*zsh', first_line))
        elif ext in ['.sh', '.bash']:
            return bool(re.match(r'^#!/.*(sh|bash)', first_line))
        elif ext == '.py':
            return bool(re.match(r'^#!/.*python', first_line)) or \
                   bool(re.match(r'^(import|from|#|def|class)', first_line))
        
        return False
    except Exception:
        return False

def check_set_euo_pipefail(script_path: Path) -> bool:
    """Verifica si el script shell tiene 'set -euo pipefail'"""
    ext = script_path.suffix.lower()
    if ext not in ['.zsh', '.sh', '.bash']:
        return True  # No aplica
    
    try:
        with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            return 'set -euo pipefail' in content or 'set -euopipefail' in content
    except Exception:
        return False

def check_syntax(script_path: Path) -> bool:
    """Verifica la sintaxis del script"""
    ext = script_path.suffix.lower()
    
    try:
        if ext in ['.zsh', '.sh', '.bash']:
            # Verificar sintaxis shell
            result = subprocess.run(
                ['zsh', '-n', str(script_path)],
                capture_output=True,
                timeout=5
            )
            if result.returncode != 0:
                result = subprocess.run(
                    ['bash', '-n', str(script_path)],
                    capture_output=True,
                    timeout=5
                )
            return result.returncode == 0
        elif ext == '.py':
            # Verificar sintaxis Python
            result = subprocess.run(
                [sys.executable, '-m', 'py_compile', '-q', str(script_path)],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
    except Exception:
        return False
    
    return True

def check_executable(script_path: Path) -> bool:
    """Verifica si el script es ejecutable"""
    return os.access(script_path, os.X_OK)

def check_file_size(script_path: Path) -> bool:
    """Verifica que el archivo no sea demasiado grande"""
    try:
        size = script_path.stat().st_size
        return size <= 1000000  # <= 1MB
    except Exception:
        return False

def check_dependencies(script_path: Path) -> List[str]:
    """Verifica dependencias faltantes (básico)"""
    missing = []
    ext = script_path.suffix.lower()
    
    try:
        with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        if ext == '.py':
            # Buscar imports de Python
            import_pattern = r'^import\s+([a-zA-Z0-9_]+)'
            from_pattern = r'^from\s+([a-zA-Z0-9_]+)'
            
            stdlib_modules = {
                'sys', 'os', 'json', 'urllib', 'datetime', 'pathlib',
                'subprocess', 'shutil', 'hashlib', 'collections', 'textwrap',
                'tkinter', 'argparse'
            }
            
            for line in content.split('\n'):
                if re.match(import_pattern, line):
                    module = re.match(import_pattern, line).group(1)
                    if module not in stdlib_modules:
                        try:
                            __import__(module)
                        except ImportError:
                            missing.append(module)
                elif re.match(from_pattern, line):
                    module = re.match(from_pattern, line).group(1)
                    if module not in stdlib_modules:
                        try:
                            __import__(module)
                        except ImportError:
                            missing.append(module)
    except Exception:
        pass
    
    return missing

def verify_script(script_path: Path) -> Tuple[int, List[str], List[str]]:
    """
    Verifica un script y retorna (score, issues, warnings)
    score: 0-6 (número de verificaciones pasadas)
    issues: lista de problemas críticos
    warnings: lista de advertencias
    """
    issues = []
    warnings = []
    score = 0
    max_score = 6
    
    if not script_path.exists():
        return (0, ["Archivo no existe"], [])
    
    ext = script_path.suffix.lower()
    
    # Verificar shebang
    if not check_shebang(script_path):
        if ext == '.py':
            # Para Python, verificar si tiene contenido válido
            try:
                with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
                    first_lines = ''.join(f.readlines()[:5])
                    if not re.search(r'^(import|from|def|class)', first_lines, re.MULTILINE):
                        issues.append("Falta shebang o contenido Python válido")
                    else:
                        warnings.append("Falta shebang (pero tiene contenido Python válido)")
                        score += 1
            except Exception:
                issues.append("Falta shebang o contenido Python válido")
        else:
            issues.append("Falta shebang apropiado")
    else:
        score += 1
    
    # Verificar set -euo pipefail (solo shell scripts)
    if ext in ['.zsh', '.sh', '.bash']:
        if not check_set_euo_pipefail(script_path):
            warnings.append("Falta 'set -euo pipefail'")
        else:
            score += 1
    else:
        score += 1  # No aplica
    
    # Verificar sintaxis
    if not check_syntax(script_path):
        issues.append("Error de sintaxis")
    else:
        score += 1
    
    # Verificar ejecutable
    if not check_executable(script_path):
        warnings.append("No es ejecutable (chmod +x)")
    else:
        score += 1
    
    # Verificar tamaño
    if not check_file_size(script_path):
        warnings.append("Archivo muy grande (>1MB)")
    else:
        score += 1
    
    # Verificar dependencias
    missing_deps = check_dependencies(script_path)
    if missing_deps:
        unique_deps = list(set(missing_deps))
        warnings.append(f"Dependencias faltantes: {' '.join(unique_deps)}")
    else:
        score += 1
    
    return (score, issues, warnings)

def fix_script(script_path: Path) -> bool:
    """Intenta corregir problemas básicos del script"""
    fixed = False
    ext = script_path.suffix.lower()
    
    try:
        # Leer contenido actual
        with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        lines = content.split('\n')
        
        # Agregar shebang si falta
        if not check_shebang(script_path):
            if ext == '.zsh':
                shebang = "#!/usr/bin/env zsh"
            elif ext in ['.sh', '.bash']:
                shebang = "#!/bin/bash"
            elif ext == '.py':
                shebang = "#!/usr/bin/env python3"
            else:
                return False
            
            lines.insert(0, shebang)
            fixed = True
        
        # Agregar set -euo pipefail si falta (solo shell scripts)
        if ext in ['.zsh', '.sh', '.bash']:
            if not check_set_euo_pipefail(script_path):
                # Buscar la línea después del shebang
                if lines and lines[0].startswith('#!'):
                    if len(lines) > 1:
                        lines.insert(1, 'set -euo pipefail')
                    else:
                        lines.append('set -euo pipefail')
                    fixed = True
        
        # Escribir contenido corregido
        if fixed:
            with open(script_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(lines))
        
        # Hacer ejecutable
        if not check_executable(script_path):
            os.chmod(script_path, os.stat(script_path).st_mode | 0o111)
            fixed = True
        
        return fixed
    except Exception as e:
        log_error(f"Error al corregir {script_path}: {e}")
        return False

# ============================================================================
# FUNCIONES DE CATEGORÍAS
# ============================================================================

def get_category_scripts(category_key: str) -> List[Path]:
    """Obtiene la lista de scripts válidos para una categoría"""
    if category_key not in CATEGORIES:
        return []
    
    category = CATEGORIES[category_key]
    scripts = []
    
    for rel_path in category["paths"]:
        full_path = REPO_ROOT / rel_path
        if full_path.exists() and full_path.is_file():
            scripts.append(full_path)
    
    return scripts

def list_categories() -> List[str]:
    """Retorna la lista de claves de categorías en orden"""
    return list(CATEGORIES.keys())

# ============================================================================
# MENÚ INTERACTIVO
# ============================================================================

def show_main_menu() -> None:
    """Muestra el menú principal"""
    os.system('clear' if os.name != 'nt' else 'cls')
    print(f"{CYAN}╔═══════════════════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║           Script Verification Tool v2.0                      ║{NC}")
    print(f"{CYAN}║           Verificación por Categorías                        ║{NC}")
    print(f"{CYAN}╚═══════════════════════════════════════════════════════════════╝{NC}")
    print()
    log_info("Selecciona una categoría:")
    print()
    
    category_keys = list_categories()
    for i, key in enumerate(category_keys, 1):
        print(f"{i}) {CATEGORIES[key]['name']}")
    
    print(f"{len(category_keys) + 1}) Todas las categorías")
    print(f"{len(category_keys) + 2}) Salir")
    print()

def show_category_menu(category_key: str) -> None:
    """Muestra el menú de una categoría específica"""
    category = CATEGORIES[category_key]
    scripts = get_category_scripts(category_key)
    count = len(scripts)
    
    os.system('clear' if os.name != 'nt' else 'cls')
    print(f"{CYAN}╔═══════════════════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║           {category['name']}{NC}")
    print(f"{CYAN}╚═══════════════════════════════════════════════════════════════╝{NC}")
    print()
    log_info(f"Scripts encontrados: {count}")
    print()
    print("1) Verificar todos los scripts de esta categoría")
    print("2) Seleccionar script específico")
    print("3) Volver al menú principal")
    print()

def show_script_selection(category_key: str) -> None:
    """Muestra la lista de scripts para selección"""
    scripts = get_category_scripts(category_key)
    
    print()
    log_info("Selecciona un script:")
    print()
    
    for i, script in enumerate(scripts, 1):
        rel_path = script.relative_to(REPO_ROOT)
        print(f"{i}) {rel_path}")
    
    print(f"{len(scripts) + 1}) Volver")
    print()

# ============================================================================
# PROCESAMIENTO
# ============================================================================

def process_category(category_key: str, auto_fix: bool = False) -> None:
    """Procesa todos los scripts de una categoría"""
    category = CATEGORIES[category_key]
    scripts = get_category_scripts(category_key)
    total = len(scripts)
    
    if total == 0:
        log_warning("No se encontraron scripts en esta categoría")
        input("\nPresiona Enter para continuar...")
        return
    
    os.system('clear' if os.name != 'nt' else 'cls')
    print(f"{CYAN}╔═══════════════════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║           {category['name']}{NC}")
    print(f"{CYAN}╚═══════════════════════════════════════════════════════════════╝{NC}")
    print()
    log_info(f"Verificando {total} scripts...")
    print()
    
    passed = 0
    warnings_count = 0
    failed = 0
    
    for script in scripts:
        rel_path = script.relative_to(REPO_ROOT)
        score, issues, warnings = verify_script(script)
        
        if issues:
            log_error(str(rel_path))
            for issue in issues:
                print(f"    → {issue}")
            failed += 1
            
            # Preguntar si hacer fix
            if not auto_fix:
                response = input("¿Aplicar correcciones automáticas? (y/n): ").strip().lower()
                if response == 'y':
                    if fix_script(script):
                        log_success(f"Correcciones aplicadas a: {rel_path}")
                        # Verificar nuevamente
                        score, issues, warnings = verify_script(script)
        elif warnings:
            log_warning(f"{rel_path} (score: {score}/6)")
            for warning in warnings:
                print(f"    → {warning}")
            warnings_count += 1
        else:
            log_success(f"{rel_path} (score: {score}/6)")
            passed += 1
    
    print()
    print(f"{CYAN}────────────────────────────────────────────────────────────{NC}")
    log_info("Resumen de la categoría:")
    print(f"  Passed:    {passed}")
    print(f"  Warnings:   {warnings_count}")
    print(f"  Failed:    {failed}")
    print()
    input("Presiona Enter para continuar...")

def process_single_script(script_path: Path) -> None:
    """Procesa un script individual"""
    os.system('clear' if os.name != 'nt' else 'cls')
    print(f"{CYAN}╔═══════════════════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║           Verificación de Script Individual                  ║{NC}")
    print(f"{CYAN}╚═══════════════════════════════════════════════════════════════╝{NC}")
    print()
    
    rel_path = script_path.relative_to(REPO_ROOT)
    score, issues, warnings = verify_script(script_path)
    
    if issues:
        log_error(str(rel_path))
        for issue in issues:
            print(f"    → {issue}")
    elif warnings:
        log_warning(f"{rel_path} (score: {score}/6)")
        for warning in warnings:
            print(f"    → {warning}")
    else:
        log_success(f"{rel_path} (score: {score}/6)")
    
    print()
    if issues or warnings:
        response = input("¿Aplicar correcciones automáticas? (y/n): ").strip().lower()
        if response == 'y':
            if fix_script(script_path):
                log_success(f"Correcciones aplicadas a: {rel_path}")
                print()
                log_info("Verificación después de las correcciones:")
                score, issues, warnings = verify_script(script_path)
                if issues:
                    log_error(str(rel_path))
                    for issue in issues:
                        print(f"    → {issue}")
                elif warnings:
                    log_warning(f"{rel_path} (score: {score}/6)")
                    for warning in warnings:
                        print(f"    → {warning}")
                else:
                    log_success(f"{rel_path} (score: {score}/6)")
    
    print()
    input("Presiona Enter para continuar...")

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

def main() -> None:
    """Función principal con menú interactivo"""
    category_keys = list_categories()
    
    while True:
        show_main_menu()
        try:
            choice = input("Selecciona una opción: ").strip()
            
            if not choice:
                continue
            
            choice_num = int(choice)
            
            # Verificar si es "Todas las categorías"
            if choice_num == len(category_keys) + 1:
                # Procesar todas las categorías
                for key in category_keys:
                    process_category(key, auto_fix=False)
                continue
            elif choice_num == len(category_keys) + 2:
                log_info("Saliendo...")
                sys.exit(0)
            elif 1 <= choice_num <= len(category_keys):
                category_key = category_keys[choice_num - 1]
                
                # Menú de categoría
                while True:
                    show_category_menu(category_key)
                    cat_choice = input("Selecciona una opción: ").strip()
                    
                    if cat_choice == '1':
                        # Verificar todos los scripts de la categoría
                        process_category(category_key, auto_fix=False)
                    elif cat_choice == '2':
                        # Seleccionar script específico
                        scripts = get_category_scripts(category_key)
                        if not scripts:
                            log_warning("No hay scripts en esta categoría")
                            input("\nPresiona Enter para continuar...")
                            continue
                        
                        show_script_selection(category_key)
                        script_choice = input("Selecciona un script: ").strip()
                        
                        try:
                            script_num = int(script_choice)
                            if 1 <= script_num <= len(scripts):
                                process_single_script(scripts[script_num - 1])
                            else:
                                continue  # Volver
                        except ValueError:
                            continue  # Volver
                    elif cat_choice == '3':
                        # Volver al menú principal
                        break
                    else:
                        log_error("Opción inválida")
                        input("\nPresiona Enter para continuar...")
            else:
                log_error("Opción inválida")
                input("\nPresiona Enter para continuar...")
        except ValueError:
            log_error("Opción inválida")
            input("\nPresiona Enter para continuar...")
        except KeyboardInterrupt:
            print("\n")
            log_info("Saliendo...")
            sys.exit(0)

if __name__ == "__main__":
    # Verificar argumentos de línea de comandos
    if len(sys.argv) > 1:
        if sys.argv[1] in ['--all', '--fix-all']:
            auto_fix = sys.argv[1] == '--fix-all'
            category_keys = list_categories()
            for key in category_keys:
                process_category(key, auto_fix=auto_fix)
        elif sys.argv[1] in ['--help', '-h']:
            print("Uso: python3 verify_scripts.py [opciones]")
            print()
            print("Opciones:")
            print("  (sin opciones)  Modo interactivo con menú")
            print("  --all            Verificar todas las categorías")
            print("  --fix-all        Verificar y corregir todas las categorías")
            print("  --help, -h       Mostrar esta ayuda")
            sys.exit(0)
        else:
            log_error(f"Opción desconocida: {sys.argv[1]}")
            print("Usa --help para ver las opciones disponibles")
            sys.exit(1)
    else:
        # Modo interactivo
        main()

