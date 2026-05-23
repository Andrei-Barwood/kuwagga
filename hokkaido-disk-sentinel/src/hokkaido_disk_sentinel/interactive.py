import sys
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from .cli import scan, recoverable, protected, clean, report

console = Console()

def clear_screen():
    console.clear()

def print_header():
    console.print(Panel.fit("[bold cyan]Hokkaido Disk Sentinel[/bold cyan]\n[italic]Auditoría y limpieza conservadora de disco[/italic]", border_style="blue"))

def main_menu():
    while True:
        clear_screen()
        print_header()
        console.print("\n[bold]1.[/bold] Analizar disco completo")
        console.print("   [dim]Escanea el disco local y muestra espacio total, usado, libre, recuperable y protegido.[/dim]")
        console.print("[bold]2.[/bold] Ver espacio recuperable")
        console.print("   [dim]Muestra cachés, temporales, logs antiguos, papelera y otros candidatos seguros.[/dim]")
        console.print("[bold]3.[/bold] Ver espacio no borrable / protegido")
        console.print("   [dim]Muestra rutas críticas, archivos bloqueados y espacio que no debe eliminarse.[/dim]")
        console.print("[bold]4.[/bold] Simular limpieza segura (Dry Run)")
        console.print("   [dim]Ejecuta una limpieza en modo dry run. No borra nada. Solo muestra lo que se podría recuperar.[/dim]")
        console.print("[bold]5.[/bold] Ejecutar limpieza segura")
        console.print("   [dim]Borra únicamente los elementos seleccionados después de confirmación explícita.[/dim]")
        console.print("[bold]6.[/bold] Generar reporte")
        console.print("   [dim]Permite exportar el análisis en JSON o Markdown.[/dim]")
        console.print("[bold]7.[/bold] Configuración avanzada")
        console.print("   [dim]Ajustar reglas y exclusiones (WIP).[/dim]")
        console.print("[bold]8.[/bold] Ayuda y política de seguridad")
        console.print("   [dim]Explica qué puede borrar la herramienta y qué no.[/dim]")
        console.print("[bold]9.[/bold] Salir\n")

        choice = Prompt.ask("Selecciona una opción", choices=[str(i) for i in range(1, 10)])
        console.print()

        try:
            if choice == "1":
                scan()
            elif choice == "2":
                recoverable()
            elif choice == "3":
                protected()
            elif choice == "4":
                clean(execute=False)
            elif choice == "5":
                clean(execute=True)
            elif choice == "6":
                fmt = Prompt.ask("Formato", choices=["json", "markdown"], default="markdown")
                report(format=fmt)
            elif choice == "7":
                console.print("[yellow]La configuración avanzada se implementará en la versión 0.2.0.[/yellow]")
            elif choice == "8":
                console.print(Panel("[bold]Política de Seguridad Estricta[/bold]\n\n"
                                    "- [bold green]SAFE:[/bold green] Cachés y temporales del usuario.\n"
                                    "- [bold yellow]REVIEW:[/bold yellow] Descargas, cachés de navegadores, node_modules. Requiere selección manual.\n"
                                    "- [bold red]PROTECTED:[/bold red] Carpetas del sistema operativo (/System, C:\\Windows, etc.). JAMÁS serán eliminadas.\n\n"
                                    "Hokkaido Disk Sentinel opera con Dry-Run por defecto.", title="Ayuda", expand=False))
            elif choice == "9":
                console.print("[bold cyan]Saliendo de Hokkaido Disk Sentinel. ¡Hasta pronto![/bold cyan]")
                sys.exit(0)
        except Exception as e:
            console.print(f"[bold red]Error inesperado:[/bold red] {str(e)}")

        Prompt.ask("\nPresiona Enter para continuar", default="")
