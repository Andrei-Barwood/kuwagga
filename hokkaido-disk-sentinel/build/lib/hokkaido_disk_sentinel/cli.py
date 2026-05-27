import typer
from pathlib import Path
from rich.console import Console
from .scanner import DiskScanner
from .cleaner import SafeCleaner
from .reporter import Reporter
from .utils import format_size

app = typer.Typer(help="Hokkaido Disk Sentinel - Herramienta de monitoreo de disco conservadora.")
console = Console()

@app.command()
def scan():
    """Analiza el disco local y muestra espacio usado y protegido."""
    scanner = DiskScanner()
    usage = scanner.get_disk_usage()
    console.print(f"[bold blue]Espacio Total:[/bold blue] {format_size(usage['total'])}")
    console.print(f"[bold red]Espacio Usado:[/bold red] {format_size(usage['used'])} ({usage['percent']}%)")
    console.print(f"[bold green]Espacio Libre:[/bold green] {format_size(usage['free'])}")

@app.command()
def recoverable():
    """Muestra cachés, temporales, logs y candidatos seguros."""
    scanner = DiskScanner()
    items = scanner.find_recoverable_space()
    total = sum(i.size_bytes for i in items)
    for item in items:
        console.print(f"[{item.risk.name}] {item.path} - {format_size(item.size_bytes)}")
    console.print(f"\n[bold green]Total Recuperable Estimado:[/bold green] {format_size(total)}")

@app.command()
def protected():
    """Muestra rutas críticas y espacio que NO debe eliminarse."""
    scanner = DiskScanner()
    items = scanner.estimate_non_deletable_space()
    for item in items:
        console.print(f"[bold red]PROTEGIDO:[/bold red] {item.path}")

@app.command()
def clean(execute: bool = typer.Option(False, "--execute", help="Ejecutar limpieza real en vez de dry-run")):
    """Simula (por defecto) o ejecuta la limpieza segura."""
    if not execute:
        console.print("[bold yellow]Iniciando limpieza en modo SIMULACIÓN (Dry-Run)[/bold yellow]")
    else:
        console.print("[bold red]ATENCIÓN: Limpieza REAL activada.[/bold red]")
        typer.confirm("¿Estás absolutamente seguro de querer borrar archivos?", abort=True)
        
    scanner = DiskScanner()
    items = scanner.find_recoverable_space()
    # Solo limpiar los SAFE
    safe_items = [i for i in items if i.risk.name == "SAFE"]
    
    cleaner = SafeCleaner(dry_run=not execute)
    res = cleaner.clean_multiple(safe_items)
    console.print(f"Resultados: {res['success']} exitosos, {res['failed']} fallidos.")
    if execute:
        console.print(f"Espacio liberado: {format_size(res['freed_bytes'])}")

@app.command()
def report(format: str = typer.Option("markdown", help="Formato del reporte: json o markdown")):
    """Genera un reporte del análisis en JSON o Markdown."""
    scanner = DiskScanner()
    usage = scanner.get_disk_usage()
    rec = scanner.find_recoverable_space()
    prot = scanner.estimate_non_deletable_space()
    
    reporter = Reporter(usage, rec, prot)
    filename = f"hokkaido_report.{format[:2]}"
    if format.lower() == "json":
        reporter.generate_json(filename)
    else:
        reporter.generate_markdown(filename)
    console.print(f"[bold green]Reporte generado:[/bold green] {filename}")

@app.command()
def menu():
    """Inicia el menú interactivo profesional."""
    from .interactive import main_menu
    main_menu()

if __name__ == "__main__":
    app()
