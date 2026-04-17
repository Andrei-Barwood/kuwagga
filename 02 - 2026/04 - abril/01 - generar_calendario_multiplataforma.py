#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import os
import platform
from dataclasses import dataclass, replace
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from typing import Iterable
from zoneinfo import ZoneInfo


CALENDAR_NAME = "Plan Estudio CFT Paillaco 2026"
TIMEZONE_NAME = "America/Santiago"
TIMEZONE = ZoneInfo(TIMEZONE_NAME)
DEFAULT_END_DATE = date(2026, 7, 13)
HOLIDAY_SOURCE = (
    "DGAC Chile AIC 01/2026 - Dias Festivos y Horarios Verano-Invierno 2026"
)
EXPORT_FOLDER_NAME = "Calendar Exports"
DEFAULT_FILENAME = "plan_estudio_cft_paillaco_2026.ics"

CALENDAR_GROUPS = {
    "trabajo": {
        "name": "Trabajo",
        "color": "#63627C",
        "filename": "plan_estudio_trabajo_2026.ics",
    },
    "clases": {
        "name": "Clases CFT",
        "color": "#A7B7CF",
        "filename": "plan_estudio_clases_cft_2026.ics",
    },
    "estudio": {
        "name": "Estudio",
        "color": "#485199",
        "filename": "plan_estudio_estudio_2026.ics",
    },
    "bienestar": {
        "name": "Bienestar",
        "color": "#FFFFB8",
        "filename": "plan_estudio_bienestar_2026.ics",
    },
    "creativo": {
        "name": "Creativo",
        "color": "#E3CA75",
        "filename": "plan_estudio_creativo_2026.ics",
    },
    "planificacion": {
        "name": "Planificacion",
        "color": "#DEDDFA",
        "filename": "plan_estudio_planificacion_2026.ics",
    },
}

GOOGLE_CALENDAR_NAME = "Paillaco 2026"
GOOGLE_GROUPS = {
    "trabajo": {
        "name": "Trabajo",
        "color": "#63627C",
        "filename": "google_trabajo_2026.ics",
    },
    "clases": {
        "name": "CFT",
        "color": "#A7B7CF",
        "filename": "google_cft_2026.ics",
    },
    "estudio": {
        "name": "Estudio",
        "color": "#485199",
        "filename": "google_estudio_2026.ics",
    },
    "bienestar": {
        "name": "Yoga",
        "color": "#FFFFB8",
        "filename": "google_yoga_2026.ics",
    },
    "creativo": {
        "name": "Crear",
        "color": "#E3CA75",
        "filename": "google_crear_2026.ics",
    },
    "planificacion": {
        "name": "Plan",
        "color": "#DEDDFA",
        "filename": "google_plan_2026.ics",
    },
}

GOOGLE_TITLE_MAP = {
    "Kundalini Yoga": "Yoga",
    "Trabajo": "Trabajo",
    "Clase CFT": "CFT",
    "Maquinas y Protecciones": "Maq. y Prot.",
    "Python I (NetAcad)": "Python I",
    "Taller de Energia": "Taller Energia",
    "Economia para el desarrollo regional": "Economia",
    "Analisis y Resolucion de Problemas": "Analisis",
    "Ciudades Inteligentes - 2026": "Smart Cities",
    "Sesion Breakcore": "Breakcore",
    "Planificacion semanal": "Plan semanal",
    "Podcast: Michael Faraday e influencia en la electricidad": "Podcast Faraday",
    "Podcast: Omnixan": "Podcast Omnixan",
    "Podcast: Fractsoul": "Podcast Fractsoul",
    "Podcast: Redes digitales": "Podcast Redes",
    "Podcast: Alimentacion yogui": "Podcast Yogui",
}

# Official 2026 Chile holiday dates from DGAC AIC 01/2026.
# Source: https://aipchile.dgac.gob.cl/dasa/aip_chile_con_contenido/ais/AIC%20PDF%20VOL%20I/AIC%202026/AIC%20-%2001%202026%20Dias%20Festivos%20y%20Horarios%20Verano-Invierno%202026.pdf
CHILE_HOLIDAYS_2026 = {
    date(2026, 1, 1): "Ano Nuevo",
    date(2026, 4, 3): "Viernes Santo",
    date(2026, 4, 4): "Sabado Santo",
    date(2026, 5, 1): "Dia del Trabajo",
    date(2026, 5, 21): "Dia de las Glorias Navales",
    date(2026, 6, 21): "Dia Nacional de los Pueblos Indigenas",
    date(2026, 6, 29): "San Pedro y San Pablo",
    date(2026, 7, 16): "Dia de la Virgen del Carmen",
    date(2026, 8, 15): "Asuncion de la Virgen",
    date(2026, 9, 18): "Primera Junta Nacional",
    date(2026, 9, 19): "Dia de las Glorias del Ejercito",
    date(2026, 10, 12): "Dia del Encuentro de Dos Mundos",
    date(2026, 10, 31): "Dia de las Iglesias Evangelicas y Protestantes",
    date(2026, 11, 1): "Dia de Todos los Santos",
    date(2026, 12, 8): "Inmaculada Concepcion",
    date(2026, 12, 25): "Navidad",
}


@dataclass(frozen=True)
class Event:
    title: str
    start: datetime
    end: datetime
    description: str
    category: str
    calendar_group: str
    alarm_minutes_before: int | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Genera un calendario .ics multiplataforma para macOS, iOS, Android y Windows."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    default_output = default_output_path()
    parser.add_argument(
        "--start",
        type=parse_date,
        default=next_or_same_monday(today_in_santiago()),
        help="Fecha de inicio del plan. Si no se indica, usa el lunes siguiente o el mismo lunes.",
    )
    parser.add_argument(
        "--end",
        type=parse_date,
        default=DEFAULT_END_DATE,
        help="Fecha de termino del plan. Por defecto: 2026-07-13.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=default_output,
        help="Ruta del archivo .ics de salida.",
    )
    return parser.parse_args()


def parse_date(value: str) -> date:
    return date.fromisoformat(value)


def today_in_santiago() -> date:
    return datetime.now(TIMEZONE).date()


def next_or_same_monday(value: date) -> date:
    days_until_monday = (0 - value.weekday()) % 7
    return value + timedelta(days=days_until_monday)


def default_output_path() -> Path:
    return default_export_dir() / DEFAULT_FILENAME


def default_export_dir() -> Path:
    home = Path.home()
    system = platform.system()

    candidates: list[Path] = []

    if system == "Windows":
        userprofile = os.environ.get("USERPROFILE")
        if userprofile:
            candidates.append(Path(userprofile) / "Documents")
        onedrive = os.environ.get("OneDrive")
        if onedrive:
            candidates.append(Path(onedrive) / "Documents")
    elif system == "Darwin":
        candidates.append(home / "Documents")
    else:
        xdg_documents = os.environ.get("XDG_DOCUMENTS_DIR")
        if xdg_documents:
            candidates.append(Path(xdg_documents.replace("$HOME", str(home))))
        candidates.append(home / "Documents")

    candidates.extend([home / "Desktop", home])

    for base_dir in candidates:
        if base_dir.exists():
            return base_dir / EXPORT_FOLDER_NAME

    return home / EXPORT_FOLDER_NAME


def at_time(day: date, hour: int, minute: int) -> datetime:
    return datetime.combine(day, time(hour=hour, minute=minute), tzinfo=TIMEZONE)


def minutes_after(value: datetime, minutes: int) -> datetime:
    return value + timedelta(minutes=minutes)


def daterange(start: date, end: date) -> Iterable[date]:
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def build_events(start_date: date, end_date: date) -> tuple[list[Event], list[date]]:
    if start_date > end_date:
        raise ValueError("La fecha de inicio no puede ser posterior a la fecha de termino.")

    events: list[Event] = []
    skipped_work_holidays: list[date] = []

    def add_daily_event(
        title: str,
        hour: int,
        minute: int,
        duration_minutes: int,
        description: str,
        category: str,
        calendar_group: str,
        alarm_minutes_before: int | None,
    ) -> None:
        for day in daterange(start_date, end_date):
            start = at_time(day, hour, minute)
            events.append(
                Event(
                    title=title,
                    start=start,
                    end=minutes_after(start, duration_minutes),
                    description=description,
                    category=category,
                    calendar_group=calendar_group,
                    alarm_minutes_before=alarm_minutes_before,
                )
            )

    def add_weekly_event(
        title: str,
        weekday: int,
        hour: int,
        minute: int,
        duration_minutes: int,
        description: str,
        category: str,
        calendar_group: str,
        alarm_minutes_before: int | None,
        skip_holidays: bool = False,
    ) -> None:
        for day in daterange(start_date, end_date):
            if day.weekday() != weekday:
                continue
            if skip_holidays and day in CHILE_HOLIDAYS_2026:
                skipped_work_holidays.append(day)
                continue
            start = at_time(day, hour, minute)
            events.append(
                Event(
                    title=title,
                    start=start,
                    end=minutes_after(start, duration_minutes),
                    description=description,
                    category=category,
                    calendar_group=calendar_group,
                    alarm_minutes_before=alarm_minutes_before,
                )
            )

    add_daily_event(
        title="Kundalini Yoga",
        hour=6,
        minute=45,
        duration_minutes=30,
        description="30 minutos diarios para arrancar enfocado y con energia.",
        category="Bienestar",
        calendar_group="bienestar",
        alarm_minutes_before=10,
    )

    work_note = (
        "Bloque fijo de trabajo. Se excluye automaticamente si cae en un feriado chileno oficial 2026."
    )
    add_weekly_event("Trabajo", 0, 18, 0, 270, work_note, "Trabajo", "trabajo", None, skip_holidays=True)
    add_weekly_event("Trabajo", 1, 18, 0, 270, work_note, "Trabajo", "trabajo", None, skip_holidays=True)
    add_weekly_event("Trabajo", 2, 18, 0, 270, work_note, "Trabajo", "trabajo", None, skip_holidays=True)
    add_weekly_event("Trabajo", 3, 18, 0, 270, work_note, "Trabajo", "trabajo", None, skip_holidays=True)
    add_weekly_event("Trabajo", 4, 18, 0, 270, work_note, "Trabajo", "trabajo", None, skip_holidays=True)
    add_weekly_event("Trabajo", 5, 8, 0, 690, work_note, "Trabajo", "trabajo", None, skip_holidays=True)

    add_weekly_event(
        "Clase CFT",
        1,
        8,
        30,
        290,
        "Bloque fijo de clases del martes.",
        "Clases",
        "clases",
        None,
    )
    add_weekly_event(
        "Clase CFT",
        2,
        8,
        30,
        290,
        "Bloque fijo de clases del miercoles en la manana.",
        "Clases",
        "clases",
        None,
    )
    add_weekly_event(
        "Clase CFT",
        2,
        14,
        20,
        145,
        "Bloque fijo de clases del miercoles en la tarde.",
        "Clases",
        "clases",
        None,
    )
    add_weekly_event(
        "Clase CFT",
        3,
        12,
        40,
        145,
        "Bloque fijo de clases del jueves.",
        "Clases",
        "clases",
        None,
    )

    add_weekly_event(
        "Maquinas y Protecciones",
        0,
        10,
        0,
        120,
        "Bloque principal de la semana. Meta: avanzar firme sin correr.",
        "Estudio",
        "estudio",
        15,
    )
    add_weekly_event(
        "Python I (NetAcad)",
        1,
        14,
        30,
        90,
        "Practica corta y util despues de clases. Solo avance real.",
        "Estudio",
        "estudio",
        15,
    )
    add_weekly_event(
        "Taller de Energia",
        3,
        10,
        30,
        90,
        "Bloque tecnico aplicado antes de clase.",
        "Estudio",
        "estudio",
        15,
    )
    add_weekly_event(
        "Economia para el desarrollo regional",
        4,
        10,
        0,
        60,
        "Lectura, resumen y conceptos clave.",
        "Estudio",
        "estudio",
        15,
    )
    add_weekly_event(
        "Analisis y Resolucion de Problemas",
        4,
        11,
        15,
        60,
        "Trabajo corto de razonamiento y ejercicios.",
        "Estudio",
        "estudio",
        15,
    )
    add_weekly_event(
        "Ciudades Inteligentes - 2026",
        6,
        10,
        30,
        90,
        "Sesion del curso MinTIC y aterrizaje de ideas para proyectos utiles.",
        "Estudio",
        "estudio",
        15,
    )
    add_weekly_event(
        "Sesion Breakcore",
        6,
        16,
        0,
        120,
        "Sesion semanal maxima de 2 horas para grabacion o edicion.",
        "Creativo",
        "creativo",
        20,
    )
    add_weekly_event(
        "Planificacion semanal",
        6,
        18,
        15,
        30,
        "Cierre corto para ordenar la semana y cuidar tu energia.",
        "Planificacion",
        "planificacion",
        15,
    )

    podcast_topics = [
        "Podcast: Michael Faraday e influencia en la electricidad",
        "Podcast: Omnixan",
        "Podcast: Fractsoul",
        "Podcast: Redes digitales",
        "Podcast: Alimentacion yogui",
    ]

    first_sunday = start_date + timedelta(days=(6 - start_date.weekday()) % 7)
    for index, topic in enumerate(podcast_topics):
        session_day = first_sunday + timedelta(days=index * 14)
        if session_day > end_date:
            continue
        start = at_time(session_day, 13, 0)
        events.append(
            Event(
                title=topic,
                start=start,
                end=minutes_after(start, 90),
                description=(
                    "Bloque minimalista de podcast: 20 min investigacion, 30 min guion, "
                    "30 min grabacion y 10 min notas."
                ),
                category="Podcast",
                calendar_group="creativo",
                alarm_minutes_before=30,
            )
        )

    events.sort(key=lambda item: item.start)
    skipped_work_holidays = sorted(set(skipped_work_holidays))
    return events, skipped_work_holidays


def build_ics(events: list[Event], calendar_name: str, color: str | None = None) -> str:
    dtstamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    lines = [
        "BEGIN:VCALENDAR",
        "PRODID:-//OpenAI Codex//Plan Estudio CFT Paillaco 2026 Multi//ES",
        "VERSION:2.0",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        f"X-WR-CALNAME:{escape_text(calendar_name)}",
        f"X-WR-TIMEZONE:{TIMEZONE_NAME}",
    ]
    if color is not None:
        lines.append(f"COLOR:{color}")
        lines.append(f"X-APPLE-CALENDAR-COLOR:{color}")

    for event in events:
        uid = make_uid(event)
        lines.extend(
            [
                "BEGIN:VEVENT",
                f"UID:{uid}",
                f"DTSTAMP:{dtstamp}",
                f"SUMMARY:{escape_text(event.title)}",
                f"DTSTART;TZID={TIMEZONE_NAME}:{event.start.strftime('%Y%m%dT%H%M%S')}",
                f"DTEND;TZID={TIMEZONE_NAME}:{event.end.strftime('%Y%m%dT%H%M%S')}",
                f"DESCRIPTION:{escape_text(event.description)}",
                f"CATEGORIES:{escape_text(event.category)}",
                "STATUS:CONFIRMED",
                "TRANSP:OPAQUE",
            ]
        )
        if event.alarm_minutes_before is not None:
            lines.extend(
                [
                    "BEGIN:VALARM",
                    "ACTION:DISPLAY",
                    f"DESCRIPTION:{escape_text('Recordatorio: ' + event.title)}",
                    f"TRIGGER:-PT{event.alarm_minutes_before}M",
                    "END:VALARM",
                ]
            )
        lines.append("END:VEVENT")

    lines.append("END:VCALENDAR")
    return "\r\n".join(fold_line(line) for line in lines) + "\r\n"


def export_group_calendars(
    output_path: Path,
    events: list[Event],
    groups: dict[str, dict[str, str]],
) -> list[Path]:
    written_files: list[Path] = []
    for group_key, meta in groups.items():
        group_events = [event for event in events if event.calendar_group == group_key]
        if not group_events:
            continue
        group_path = output_path.with_name(meta["filename"])
        group_text = build_ics(group_events, meta["name"], meta["color"])
        group_path.write_text(group_text, encoding="utf-8", newline="")
        written_files.append(group_path)
    return written_files


def write_palette_guide(output_path: Path) -> Path:
    guide_path = output_path.with_name("plan_estudio_colores_2026.md")
    lines = [
        "# Paleta del calendario 2026",
        "",
        "Asignacion de colores por calendario:",
        "",
    ]
    for group_key in ["trabajo", "clases", "estudio", "bienestar", "creativo", "planificacion"]:
        meta = CALENDAR_GROUPS[group_key]
        lines.append(f"- {meta['name']}: `{meta['color']}`")
    lines.extend(
        [
            "",
            "Agrupacion aplicada:",
            "",
            "- Creativo incluye podcasts y breakcore.",
            "- Estudio incluye los bloques academicos y el curso de Ciudades Inteligentes.",
            "- El archivo combinado mantiene todo el plan en un solo calendario.",
        ]
    )
    guide_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return guide_path


def googleize_events(events: list[Event]) -> list[Event]:
    google_events: list[Event] = []
    for event in events:
        google_events.append(
            replace(event, title=GOOGLE_TITLE_MAP.get(event.title, event.title))
        )
    return google_events


def write_google_guide(output_path: Path) -> Path:
    guide_path = output_path.with_name("plan_estudio_google_2026.md")
    lines = [
        "# Google Calendar 2026",
        "",
        "Calendarios cortos sugeridos para Google:",
        "",
        f"- {GOOGLE_CALENDAR_NAME}: calendario combinado",
        "- Trabajo: `#63627C`",
        "- CFT: `#A7B7CF`",
        "- Estudio: `#485199`",
        "- Yoga: `#FFFFB8`",
        "- Crear: `#E3CA75`",
        "- Plan: `#DEDDFA`",
        "",
        "Titulos cortos incluidos en la exportacion Google:",
        "",
        "- Maquinas y Protecciones -> Maq. y Prot.",
        "- Ciudades Inteligentes - 2026 -> Smart Cities",
        "- Analisis y Resolucion de Problemas -> Analisis",
        "- Podcasts largos -> version corta por tema",
        "",
        "Sugerencia de uso:",
        "",
        "- Crea 6 calendarios en Google Calendar con esos nombres.",
        "- Asigna a cada uno su color personalizado.",
        "- Importa cada archivo `google_*.ics` en el calendario correspondiente.",
    ]
    guide_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return guide_path


def make_uid(event: Event) -> str:
    raw = f"{event.title}|{event.start.isoformat()}|{event.end.isoformat()}".encode("utf-8")
    digest = hashlib.sha1(raw).hexdigest()
    return f"{digest}@plan-estudio-paillaco-2026"


def escape_text(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace(";", r"\;")
        .replace(",", r"\,")
        .replace("\n", r"\n")
    )


def fold_line(line: str, limit: int = 75) -> str:
    if len(line) <= limit:
        return line

    chunks: list[str] = []
    current = line
    while len(current) > limit:
        chunks.append(current[:limit])
        current = " " + current[limit:]
    chunks.append(current)
    return "\r\n".join(chunks)


def ensure_supported_years(start_date: date, end_date: date) -> None:
    years = {day.year for day in (start_date, end_date)}
    unsupported = [year for year in years if year != 2026]
    if unsupported:
        raise ValueError(
            "Esta version usa el calendario oficial de feriados chilenos 2026. "
            "Usa fechas dentro de 2026 o amplia la tabla de feriados en el script."
        )


def main() -> None:
    args = parse_args()
    ensure_supported_years(args.start, args.end)

    events, skipped_work_holidays = build_events(args.start, args.end)
    ics_text = build_ics(events, CALENDAR_NAME)
    google_events = googleize_events(events)
    google_output_path = args.output.with_name("plan_estudio_google_2026.ics")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(ics_text, encoding="utf-8", newline="")
    written_group_files = export_group_calendars(args.output, events, CALENDAR_GROUPS)
    guide_path = write_palette_guide(args.output)
    google_output_path.write_text(
        build_ics(google_events, GOOGLE_CALENDAR_NAME),
        encoding="utf-8",
        newline="",
    )
    written_google_group_files = export_group_calendars(
        google_output_path,
        google_events,
        GOOGLE_GROUPS,
    )
    google_guide_path = write_google_guide(args.output)

    print(f"Calendario exportado: {args.output}")
    print("Calendarios por color:")
    for group_path in written_group_files:
        print(f"  - {group_path}")
    print(f"Guia de colores: {guide_path}")
    print(f"Calendario Google: {google_output_path}")
    print("Calendarios Google cortos:")
    for group_path in written_google_group_files:
        print(f"  - {group_path}")
    print(f"Guia Google: {google_guide_path}")
    print(f"Eventos generados: {len(events)}")
    print(f"Rango: {args.start.isoformat()} -> {args.end.isoformat()}")
    print(f"Fuente de feriados: {HOLIDAY_SOURCE}")
    if skipped_work_holidays:
        print("Turnos de trabajo omitidos por feriado:")
        for holiday in skipped_work_holidays:
            print(f"  - {holiday.isoformat()} :: {CHILE_HOLIDAYS_2026[holiday]}")
    else:
        print("No hubo turnos de trabajo omitidos por feriado en el rango elegido.")


if __name__ == "__main__":
    main()
