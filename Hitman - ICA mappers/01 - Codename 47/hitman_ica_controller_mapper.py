#!/usr/bin/env python3
"""
ICA Controller Mapper - Hitman: Codename 47
GUI app with per-mission profiles for comfortable gamepad mapping.
Built for EasySMX X15 (Xbox-style layout) but works with most controllers.
"""

import os
import sys

# macOS: SDL must not init Cocoa video/keyboard from a worker thread while
# tkinter owns the main thread — that triggers dispatch_assert_queue_fail.
if sys.platform == "darwin":
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import customtkinter as ctk
import pygame
import threading
import time
from pynput.keyboard import Controller as KeyboardController, Key
from pynput.mouse import Controller as MouseController, Button

# ============================================================
# COLOR SCHEME - ICA palette
# ============================================================
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

PRIMARY_BLUE = "#485199"
SECONDARY_BLUE = "#5A64BF"
GOLD = "#CCB244"
LIGHT_GOLD = "#E3CA75"
DARK_BG = "#303030"
MEDIUM_GRAY = "#4F4F4F"
LIGHT_BG = "#D7E0EC"

# ============================================================
# MISSION PROFILES - Narrative + Recommended Controller Use
# ============================================================
MISSIONS = {
    "Kowloon Triads in Gang War": {
        "title": "KOWLOON TRIADS IN GANG WAR",
        "location": "Hong Kong • Chiu Dai Park",
        "briefing": """Tu primera misión oficial, 47.

Las dos triadas más poderosas de Hong Kong se reúnen en el santuario del parque para negociar una tregua. Tu objetivo: eliminar al negociador principal de los Red Dragon.

Esto encenderá la guerra entre facciones.

RECOMENDACIÓN DE MANDO:
• Stick derecho → Mira precisa para el headshot desde el tejado
• Gatillo derecho (RT) → Disparo limpio (un solo tiro)
• Stick izquierdo + Shift → Escape inmediato después del disparo
• LB / RB → Inclinarse en esquinas o bordes del tejado
• X → Recargar rápido si fallas el primer tiro
• Mantén la calma. La heli llega en segundos.""",
        "playstyle": "Sniper + Escape Rápido",
        "difficulty_note": "Prioriza precisión y velocidad de exfiltración. Un solo disparo es suficiente."
    },

    "Ambush at the Wang Fou Restaurant": {
        "title": "AMBUSH AT THE WANG FOU RESTAURANT",
        "location": "Hong Kong • Wang Fou Restaurant",
        "briefing": """La guerra de triadas ya comenzó.

Tu objetivo: emboscar al emisario Blue Lotus que va a disculparse con Lee Hong.

Método clásico: bomba en la limusina.

RECOMENDACIÓN DE MANDO:
• A → Interactuar / Colocar bomba (timing perfecto)
• Stick izquierdo → Movimiento sigiloso por los callejones
• LB / RB → Inclinarse para espiar guardias
• B → Click derecho (menú contextual si aplica)
• X → Recargar si entras en tiroteo
• Timing es todo. Espera al chófer que va al baño.""",
        "playstyle": "Stealth + Timing + Sabotaje",
        "difficulty_note": "La paciencia y el posicionamiento son clave. No alertes antes de tiempo."
    },

    "The Massacre at Cheung Chau Fish Restaurant": {
        "title": "THE MASSACRE AT CHEUNG CHAU FISH RESTAURANT",
        "location": "Hong Kong • Cheung Chau",
        "briefing": """Las triadas están al borde de la guerra total.

El jefe de policía quiere que las dos partes negocien una tregua... o que se maten entre ellas.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Movimiento rápido entre zonas
• Gatillo derecho → Disparos controlados
• LB / RB → Inclinarse para disparos desde cobertura
• X → Recargar entre oleadas
• Este es uno de los niveles más caóticos del arco de Hong Kong. Mantén la calma.""",
        "playstyle": "Acción Controlada + Cobertura",
        "difficulty_note": "Alta densidad de enemigos. Usa inclinación y cobertura constantemente."
    },

    "The Lee Hong Assassination": {
        "title": "THE LEE HONG ASSASSINATION",
        "location": "Hong Kong • Red Dragon HQ",
        "briefing": """El clímax del arco de Hong Kong.

Lee Hong, el gran jefe de los Red Dragon, debe morir.

Múltiples caminos: sigilo total, tiroteo controlado o combinación.

RECOMENDACIÓN DE MANDO:
• Stick derecho → Mira precisa en interiores
• Gatillo derecho → Disparos
• LB / RB → Inclinarse en pasillos y esquinas (crítico aquí)
• A → Interactuar con objetos / puertas
• X → Recargar
• Este nivel recompensa el conocimiento del mapa y el uso inteligente de la inclinación.""",
        "playstyle": "Multi-objetivo + Sigilo Avanzado",
        "difficulty_note": "El más complejo del arco. La inclinación (LB/RB) es tu mejor amiga."
    },

    # --- Arco Colombia ---
    "Find the U'wa Tribe": {
        "title": "FIND THE U'WA TRIBE",
        "location": "Colombia • Selva Amazónica",
        "briefing": """La Agencia te envía a la selva colombiana, 47.

Debes localizar a la tribu U'wa y eliminar a Francisco Mendoza, el narcotraficante que amenaza su territorio sagrado.

El mapa es extenso, denso y hostil: soldados, patrullas y fauna. La exploración es tan peligrosa como el objetivo.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Desplazamiento constante entre claros y senderos
• Stick derecho → Mira suave para vigilar copas y rutas de patrulla
• LB / RB → Inclinarse detrás de troncos y rocas antes de avanzar
• Gatillo derecho → Disparos cortos y precisos (evita alertar campamentos)
• A → Interactuar con objetos y rutas del pueblo U'wa
• X → Recargar antes de cruzar zonas abiertas
• No corras sin necesidad. La selva castiga el ruido y la prisa.""",
        "playstyle": "Exploración + Sigilo en Jungla",
        "difficulty_note": "Prioriza orientación y paciencia. Avanza en cortos tramos y usa cobertura natural."
    },

    "The Jungle God": {
        "title": "THE JUNGLE GOD",
        "location": "Colombia • Campamento FARC",
        "briefing": """Mendoza ha caído, pero el verdadero objetivo sigue vivo: Pablo Belisario Ochoa.

Para llegar a él debes infiltrarte en un campamento FARC haciéndote pasar por el Dios de la Selva. El disfraz es tu única credencial.

Un error de postura o un movimiento brusco delatará al falso dios.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Caminar (no correr) dentro del campamento con disfraz
• A → Interactuar para mantener la farsa y abrir accesos
• B → Click derecho para acciones contextuales sin romper cobertura
• LB / RB → Inclinarse en tiendas y barricadas para espiar guardias
• Stick derecho → Control fino si necesitas neutralizar aislados
• X → Recargar en zonas seguras antes de entrar al núcleo del campamento
• Mantén la calma. Aquí gana quien actúa como ritual, no como soldado.""",
        "playstyle": "Infiltración + Disfraz + Sigilo Social",
        "difficulty_note": "Evita combates abiertos con el disfraz puesto. Planifica cada interacción."
    },

    "Say Hello to My Little Friend": {
        "title": "SAY HELLO TO MY LITTLE FRIEND",
        "location": "Colombia • Villa de Pablo Ochoa",
        "briefing": """El clímax del arco colombiano, 47.

Pablo Ochoa se refugia en su fortaleza personal, rodeado de hombres, ametralladoras y un helicóptero de vigilancia.

Ya no hay disfraces ni negociaciones. Es asalto puro contra uno de los carteles más armados del continente.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo + Shift → Avance agresivo entre coberturas
• Gatillo derecho → Ráfagas cortas y controladas
• LB / RB → Inclinarse en muros y barricadas (imprescindible)
• Stick derecho → Mira rápida para amenazas múltiples
• X → Recargar en cada pausa de cobertura
• A → Interactuar con puertas y objetivos del recinto
• Gestiona munición y salud. Este nivel no perdona el exceso de confianza.""",
        "playstyle": "Asalto + Acción Intensa + Cobertura",
        "difficulty_note": "El combate es inevitable. Avanza por secciones y no te quedes expuesto."
    },

    # --- Arco Hungría ---
    "Traditions of the Trade": {
        "title": "TRADITIONS OF THE TRADE",
        "location": "Hungría • Hotel de Budapest",
        "briefing": """Nueva operación, nuevo escenario: un hotel de lujo en Budapest durante una subasta de armas.

Tu objetivo es Franz Fuchs, terrorista y traficante que se mueve entre invitados, guardias y mercancía ilegal.

El entorno favorece al infiltrado que parece un huésped más, no a quien dispara primero.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Desplazamiento sigiloso por pasillos y habitaciones
• LB / RB → Inclinarse en esquinas antes de cruzar corredores
• A → Interactuar con puertas, objetos y rutas de servicio
• B → Click derecho para acciones discretas
• Stick derecho → Headshots precisos si te descubren
• Gatillo derecho → Disparo único cuando no quede alternativa
• X → Recargar en baños o cuartos de servicio
• Piensa como huésped, actúa como fantasma.""",
        "playstyle": "Sigilo Social + Infiltración en Interiores",
        "difficulty_note": "El hotel es un laberinto. Memoriza rutas de servicio y evita zonas concurridas."
    },

    # --- Arco Rotterdam ---
    "Gunrunner's Paradise": {
        "title": "GUNRUNNER'S PARADISE",
        "location": "Rotterdam • Puerto y astilleros",
        "briefing": """Los muelles de Rotterdam se han convertido en paraíso de traficantes de armas.

Debes localizar y eliminar a Arkadij Javorinsko, un intermediario clave en la cadena de suministro ilegal.

Contenedores, grúas y barcos crean ángulos de visión complicados y patrullas impredecibles.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Movimiento táctico entre contenedores y estructuras
• LB / RB → Inclinarse para limpiar esquinas en el puerto
• Stick derecho → Mira estable para francotirador en largas distancias
• Gatillo derecho → Disparos de confirmación antes de avanzar
• A → Interactuar con accesos, palancas y puntos de infiltración
• X → Recargar tras cada enfrentamiento localizado
• Usa la verticalidad del mapa: techos y pasarelas dan ventaja.""",
        "playstyle": "Sigilo Táctico + Francotirador Urbano",
        "difficulty_note": "Reconoce primero, elimina después. El puerto castiga avances sin información."
    },

    "Plutonium Runs Loose": {
        "title": "PLUTONIUM RUNS LOOSE",
        "location": "Rotterdam • Zona portuaria restringida",
        "briefing": """Situación crítica, 47.

Un lote de plutonio ha sido robado en Rotterdam y varios objetivos deben caer antes de que el material desaparezca para siempre.

Múltiples blancos, presión temporal y entorno industrial hostil. Esta es una misión de contención y eliminación simultánea.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Rotación rápida entre objetivos y contenedores
• Gatillo derecho → Control de fuego: ráfagas cortas, sin desperdicio
• LB / RB → Inclinarse en cobertura metálica y barricadas
• Stick derecho → Cambio de blanco ágil entre amenazas
• A → Interactuar con objetivos secundarios y accesos del área
• X → Recargar en cada transición entre zonas
• Back (Esc) → Pausa táctica para replantear si el caos escala
• Prioriza objetivos por orden. El reloj y el plutonio no negocian.""",
        "playstyle": "Multi-objetivo + Acción Urgente + Gestión de Amenazas",
        "difficulty_note": "Misión final del juego. Planifica ruta de eliminación y no persigas todos los blancos a la vez."
    }
}

# ============================================================
# BASE MAPPINGS (EasySMX X15 / Xbox layout)
# ============================================================
_pygame_initialized = False


def _ensure_pygame_initialized():
    """Initialize pygame once on the main thread (required on macOS)."""
    global _pygame_initialized
    if _pygame_initialized:
        return
    pygame.init()
    pygame.joystick.init()
    _pygame_initialized = True


def _shutdown_pygame():
    global _pygame_initialized
    if _pygame_initialized:
        pygame.quit()
        _pygame_initialized = False


BASE_MAPPINGS = {
    # Button index : action description + key/mouse
    0: {"name": "A", "action": "Click Izquierdo (Disparar / Interactuar)", "key": Button.left, "type": "mouse"},
    1: {"name": "B", "action": "Click Derecho (Menú de acciones)", "key": Button.right, "type": "mouse"},
    2: {"name": "X", "action": "Recargar (r)", "key": 'r', "type": "key"},
    3: {"name": "Y", "action": "Tirar arma (g)", "key": 'g', "type": "key"},
    4: {"name": "LB", "action": "Inclinarse Izquierda (q)", "key": 'q', "type": "key"},
    5: {"name": "RB", "action": "Inclinarse Derecha (e)", "key": 'e', "type": "key"},
    6: {"name": "Back", "action": "Menú / Pausa (Esc)", "key": Key.esc, "type": "key"},
    7: {"name": "Start", "action": "Aceptar / Continuar (Enter)", "key": Key.enter, "type": "key"},
}

class HitmanMapper:
    """Core mapper logic running in background thread"""
    def __init__(self):
        self.keyboard = KeyboardController()
        self.mouse = MouseController()
        self.running = False
        self.thread = None
        self.current_mappings = BASE_MAPPINGS.copy()
        self.sensitivity = 25
        self.deadzone = 0.2
        self.run_threshold = 0.85
        self.joystick = None

    def set_profile(self, profile_name):
        """Load mission-specific tweaks if needed (for now base + notes)"""
        self.current_mappings = BASE_MAPPINGS.copy()
        # Future: different base mappings per mission could be added here

    def update_settings(self, sensitivity=None, deadzone=None, run_threshold=None):
        if sensitivity is not None:
            self.sensitivity = sensitivity
        if deadzone is not None:
            self.deadzone = deadzone
        if run_threshold is not None:
            self.run_threshold = run_threshold

    def _set_key(self, key, state, key_states):
        if key_states.get(key, None) != state:
            if state:
                self.keyboard.press(key)
            else:
                self.keyboard.release(key)
            key_states[key] = state

    def run(self):
        if pygame.joystick.get_count() == 0:
            print("[ICA Mapper] No se detectó ningún control.")
            return

        self.joystick = pygame.joystick.Joystick(0)
        self.joystick.init()
        print(f"[ICA Mapper] Control conectado: {self.joystick.get_name()}")

        key_states = {'w': False, 'a': False, 's': False, 'd': False, Key.shift: False}
        trigger_state = False
        self.running = True

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.JOYBUTTONDOWN:
                    if event.button in self.current_mappings:
                        mapping = self.current_mappings[event.button]
                        if mapping["type"] == "key":
                            self.keyboard.press(mapping["key"])
                        else:
                            self.mouse.press(mapping["key"])

                if event.type == pygame.JOYBUTTONUP:
                    if event.button in self.current_mappings:
                        mapping = self.current_mappings[event.button]
                        if mapping["type"] == "key":
                            self.keyboard.release(mapping["key"])
                        else:
                            self.mouse.release(mapping["key"])

            # Hats (D-pad)
            if self.joystick.get_numhats() > 0:
                hat_x, hat_y = self.joystick.get_hat(0)
                self._set_key(Key.up, hat_y == 1, key_states)
                self._set_key(Key.down, hat_y == -1, key_states)
                self._set_key(Key.right, hat_x == 1, key_states)
                self._set_key(Key.left, hat_x == -1, key_states)

            # Left stick - Movement
            axis_x = self.joystick.get_axis(0)
            axis_y = self.joystick.get_axis(1)

            self._set_key('w', axis_y < -self.deadzone, key_states)
            self._set_key('s', axis_y > self.deadzone, key_states)
            self._set_key('a', axis_x < -self.deadzone, key_states)
            self._set_key('d', axis_x > self.deadzone, key_states)

            # Run (full forward push)
            self._set_key(Key.shift, axis_y < -self.run_threshold, key_states)

            # Right stick - Mouse look
            axis_rx = self.joystick.get_axis(2)
            axis_ry = self.joystick.get_axis(3)

            dx = int(axis_rx * self.sensitivity) if abs(axis_rx) > 0.15 else 0
            dy = int(axis_ry * self.sensitivity) if abs(axis_ry) > 0.15 else 0

            if dx != 0 or dy != 0:
                self.mouse.move(dx, dy)

            # Right Trigger (axis 5) - Shoot
            if self.joystick.get_numaxes() > 5:
                trigger_rt = self.joystick.get_axis(5)
                is_pressed = trigger_rt > 0.6
                if is_pressed and not trigger_state:
                    self.mouse.press(Button.left)
                    trigger_state = True
                elif not is_pressed and trigger_state:
                    self.mouse.release(Button.left)
                    trigger_state = False

            time.sleep(0.008)

        print("[ICA Mapper] Mapper detenido.")

    def start(self):
        if not self.running:
            _ensure_pygame_initialized()
            self.thread = threading.Thread(target=self.run, daemon=True)
            self.thread.start()

    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join(timeout=1.0)


class HitmanApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("ICA // Codename 47 Controller Mapper")
        self.geometry("980x720")
        self.minsize(900, 650)
        self.configure(fg_color=DARK_BG)

        self.mapper = HitmanMapper()
        self.current_mission = list(MISSIONS.keys())[0]

        self._build_ui()
        self._load_mission(self.current_mission)

    def _build_ui(self):
        # Header
        header = ctk.CTkFrame(self, height=70, fg_color=DARK_BG)
        header.pack(fill="x", padx=10, pady=(10, 5))

        title = ctk.CTkLabel(
            header,
            text="AGENT 47  •  ICA CONTROLLER BRIEFING",
            font=ctk.CTkFont(size=22, weight="bold"),
            text_color=GOLD
        )
        title.pack(pady=15)

        subtitle = ctk.CTkLabel(
            header,
            text="Hitman: Codename 47  •  Perfiles de mapeo optimizados por misión",
            font=ctk.CTkFont(size=12),
            text_color=LIGHT_GOLD
        )
        subtitle.pack()

        # Main content
        main_frame = ctk.CTkFrame(self, fg_color="transparent")
        main_frame.pack(fill="both", expand=True, padx=10, pady=5)

        # Left column - Mission selector + Briefing
        left_col = ctk.CTkFrame(main_frame, fg_color=MEDIUM_GRAY, corner_radius=10)
        left_col.pack(side="left", fill="both", expand=True, padx=(0, 5))

        ctk.CTkLabel(left_col, text="SELECCIONA MISIÓN", font=ctk.CTkFont(size=13, weight="bold"),
                     text_color=LIGHT_BG).pack(pady=(12, 5), padx=15, anchor="w")

        self.mission_menu = ctk.CTkOptionMenu(
            left_col,
            values=list(MISSIONS.keys()),
            command=self._on_mission_change,
            width=320,
            fg_color=PRIMARY_BLUE,
            button_color=SECONDARY_BLUE,
            button_hover_color=PRIMARY_BLUE,
            text_color=LIGHT_BG
        )
        self.mission_menu.pack(pady=5, padx=15)

        ctk.CTkLabel(left_col, text="BRIEFING DE LA AGENCIA", font=ctk.CTkFont(size=12, weight="bold"),
                     text_color=LIGHT_GOLD).pack(pady=(12, 3), padx=15, anchor="w")

        self.briefing_box = ctk.CTkTextbox(
            left_col,
            height=280,
            wrap="word",
            fg_color=DARK_BG,
            text_color=LIGHT_BG,
            font=ctk.CTkFont(size=11)
        )
        self.briefing_box.pack(fill="both", expand=True, padx=15, pady=(0, 10))

        self.playstyle_label = ctk.CTkLabel(
            left_col,
            text="",
            font=ctk.CTkFont(size=11, slant="italic"),
            text_color=GOLD
        )
        self.playstyle_label.pack(pady=(0, 12), padx=15)

        # Right column - Mappings + Controls
        right_col = ctk.CTkFrame(main_frame, fg_color=MEDIUM_GRAY, corner_radius=10)
        right_col.pack(side="right", fill="both", expand=True, padx=(5, 0))

        ctk.CTkLabel(right_col, text="MAPEO ACTUAL (EasySMX X15)", font=ctk.CTkFont(size=13, weight="bold"),
                     text_color=LIGHT_BG).pack(pady=(12, 8), padx=15, anchor="w")

        # Mappings display
        self.mappings_frame = ctk.CTkScrollableFrame(right_col, fg_color=DARK_BG, height=220)
        self.mappings_frame.pack(fill="both", expand=True, padx=15, pady=(0, 10))

        # Settings
        settings_frame = ctk.CTkFrame(right_col, fg_color="transparent")
        settings_frame.pack(fill="x", padx=15, pady=5)

        ctk.CTkLabel(settings_frame, text="SENSIBILIDAD RATÓN", font=ctk.CTkFont(size=10),
                     text_color=LIGHT_BG).pack(anchor="w")
        self.sens_slider = ctk.CTkSlider(
            settings_frame, from_=10, to=50, number_of_steps=40,
            command=self._on_settings_change,
            progress_color=PRIMARY_BLUE,
            button_color=SECONDARY_BLUE,
            button_hover_color=GOLD
        )
        self.sens_slider.set(25)
        self.sens_slider.pack(fill="x", pady=(0, 8))

        ctk.CTkLabel(settings_frame, text="DEADZONE STICK", font=ctk.CTkFont(size=10),
                     text_color=LIGHT_BG).pack(anchor="w")
        self.deadzone_slider = ctk.CTkSlider(
            settings_frame, from_=0.05, to=0.4, number_of_steps=35,
            command=self._on_settings_change,
            progress_color=PRIMARY_BLUE,
            button_color=SECONDARY_BLUE,
            button_hover_color=GOLD
        )
        self.deadzone_slider.set(0.2)
        self.deadzone_slider.pack(fill="x", pady=(0, 8))

        ctk.CTkLabel(settings_frame, text="UMBRAL CORRER (Shift)", font=ctk.CTkFont(size=10),
                     text_color=LIGHT_BG).pack(anchor="w")
        self.run_slider = ctk.CTkSlider(
            settings_frame, from_=0.6, to=0.95, number_of_steps=35,
            command=self._on_settings_change,
            progress_color=PRIMARY_BLUE,
            button_color=SECONDARY_BLUE,
            button_hover_color=GOLD
        )
        self.run_slider.set(0.85)
        self.run_slider.pack(fill="x", pady=(0, 12))

        # Control buttons
        btn_frame = ctk.CTkFrame(right_col, fg_color="transparent")
        btn_frame.pack(fill="x", padx=15, pady=(5, 12))

        self.start_btn = ctk.CTkButton(
            btn_frame,
            text="▶ INICIAR MAPPER",
            fg_color=PRIMARY_BLUE,
            hover_color=SECONDARY_BLUE,
            text_color=LIGHT_BG,
            height=45,
            font=ctk.CTkFont(size=14, weight="bold"),
            command=self._start_mapper
        )
        self.start_btn.pack(fill="x", pady=3)

        self.stop_btn = ctk.CTkButton(
            btn_frame,
            text="■ DETENER MAPPER",
            fg_color=MEDIUM_GRAY,
            hover_color=DARK_BG,
            text_color=LIGHT_BG,
            height=38,
            command=self._stop_mapper
        )
        self.stop_btn.pack(fill="x", pady=3)

        # Status
        self.status_label = ctk.CTkLabel(
            right_col,
            text="Estado: Mapper detenido • Control no conectado",
            font=ctk.CTkFont(size=10),
            text_color=LIGHT_GOLD
        )
        self.status_label.pack(pady=(8, 5))

        # Footer tip
        footer = ctk.CTkLabel(
            self,
            text="Consejo de la Agencia: Selecciona la misión → Lee el briefing → Ajusta sensibilidad → Inicia el mapper antes de lanzar el juego.",
            font=ctk.CTkFont(size=9),
            text_color=GOLD
        )
        footer.pack(pady=(0, 8))

    def _load_mission(self, mission_name):
        self.current_mission = mission_name
        data = MISSIONS[mission_name]

        self.briefing_box.delete("1.0", "end")
        self.briefing_box.insert("1.0", data["briefing"])

        self.playstyle_label.configure(text=f"Estilo recomendado: {data['playstyle']}")

        # Update mappings display
        for widget in self.mappings_frame.winfo_children():
            widget.destroy()

        for btn_id, mapping in BASE_MAPPINGS.items():
            row = ctk.CTkFrame(self.mappings_frame, fg_color="transparent", height=26)
            row.pack(fill="x", pady=1)

            btn_label = ctk.CTkLabel(
                row,
                text=f"  {mapping['name']} (Btn {btn_id})",
                width=120,
                anchor="w",
                font=ctk.CTkFont(size=10, weight="bold"),
                text_color=GOLD
            )
            btn_label.pack(side="left")

            action_label = ctk.CTkLabel(
                row,
                text=mapping['action'],
                anchor="w",
                font=ctk.CTkFont(size=10),
                text_color=LIGHT_BG
            )
            action_label.pack(side="left", fill="x", expand=True)

        self.mapper.set_profile(mission_name)

    def _on_mission_change(self, choice):
        self._load_mission(choice)

    def _on_settings_change(self, value=None):
        sens = self.sens_slider.get()
        dead = self.deadzone_slider.get()
        run_t = self.run_slider.get()
        self.mapper.update_settings(sensitivity=sens, deadzone=dead, run_threshold=run_t)

    def _start_mapper(self):
        self.mapper.start()
        self.status_label.configure(
            text="Estado: Mapper ACTIVO • Control conectado • Perfil cargado",
            text_color=LIGHT_GOLD
        )
        self.start_btn.configure(state="disabled", fg_color=MEDIUM_GRAY)

    def _stop_mapper(self):
        self.mapper.stop()
        self.status_label.configure(
            text="Estado: Mapper detenido",
            text_color=LIGHT_GOLD
        )
        self.start_btn.configure(state="normal", fg_color=PRIMARY_BLUE)

    def on_closing(self):
        self.mapper.stop()
        _shutdown_pygame()
        self.destroy()


if __name__ == "__main__":
    print("Iniciando ICA Controller Mapper para Hitman: Codename 47...")
    print("Instala dependencias con:")
    print("pip install -r requirements.txt")

    app = HitmanApp()
    app.protocol("WM_DELETE_WINDOW", app.on_closing)
    app.mainloop()