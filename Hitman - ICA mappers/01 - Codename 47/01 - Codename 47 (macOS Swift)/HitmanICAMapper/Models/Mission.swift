import Foundation

struct Mission: Identifiable, Hashable {
    let id = UUID()
    let key: String              // original key for reference
    let title: String
    let location: String
    let briefing: String
    let playstyle: String
    let difficultyNote: String
}

// All 10 missions - exact port from the Python version (in Spanish)
let missions: [Mission] = [
    Mission(
        key: "Kowloon Triads in Gang War",
        title: "KOWLOON TRIADS IN GANG WAR",
        location: "Hong Kong • Chiu Dai Park",
        briefing: """
Tu primera misión oficial, 47.

Las dos triadas más poderosas de Hong Kong se reúnen en el santuario del parque para negociar una tregua. Tu objetivo: eliminar al negociador principal de los Red Dragon.

Esto encenderá la guerra entre facciones.

RECOMENDACIÓN DE MANDO:
• Stick derecho → Mira precisa para el headshot desde el tejado
• Gatillo derecho (RT) → Disparo limpio (un solo tiro)
• Stick izquierdo + Shift → Escape inmediato después del disparo
• LB / RB → Inclinarse en esquinas o bordes del tejado
• X → Recargar rápido si fallas el primer tiro
• Mantén la calma. La heli llega en segundos.
""",
        playstyle: "Sniper + Escape Rápido",
        difficultyNote: "Prioriza precisión y velocidad de exfiltración. Un solo disparo es suficiente."
    ),

    Mission(
        key: "Ambush at the Wang Fou Restaurant",
        title: "AMBUSH AT THE WANG FOU RESTAURANT",
        location: "Hong Kong • Wang Fou Restaurant",
        briefing: """
La guerra de triadas ya comenzó.

Tu objetivo: emboscar al emisario Blue Lotus que va a disculparse con Lee Hong.

Método clásico: bomba en la limusina.

RECOMENDACIÓN DE MANDO:
• A → Interactuar / Colocar bomba (timing perfecto)
• Stick izquierdo → Movimiento sigiloso por los callejones
• LB / RB → Inclinarse para espiar guardias
• B → Click derecho (menú contextual si aplica)
• X → Recargar si entras en tiroteo
• Timing es todo. Espera al chófer que va al baño.
""",
        playstyle: "Stealth + Timing + Sabotaje",
        difficultyNote: "La paciencia y el posicionamiento son clave. No alertes antes de tiempo."
    ),

    Mission(
        key: "The Massacre at Cheung Chau Fish Restaurant",
        title: "THE MASSACRE AT CHEUNG CHAU FISH RESTAURANT",
        location: "Hong Kong • Cheung Chau",
        briefing: """
Las triadas están al borde de la guerra total.

El jefe de policía quiere que las dos partes negocien una tregua... o que se maten entre ellas.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Movimiento rápido entre zonas
• Gatillo derecho → Disparos controlados
• LB / RB → Inclinarse para disparos desde cobertura
• X → Recargar entre oleadas
• Este es uno de los niveles más caóticos del arco de Hong Kong. Mantén la calma.
""",
        playstyle: "Acción Controlada + Cobertura",
        difficultyNote: "Alta densidad de enemigos. Usa inclinación y cobertura constantemente."
    ),

    Mission(
        key: "The Lee Hong Assassination",
        title: "THE LEE HONG ASSASSINATION",
        location: "Hong Kong • Red Dragon HQ",
        briefing: """
El clímax del arco de Hong Kong.

Lee Hong, el gran jefe de los Red Dragon, debe morir.

Múltiples caminos: sigilo total, tiroteo controlado o combinación.

RECOMENDACIÓN DE MANDO:
• Stick derecho → Mira precisa en interiores
• Gatillo derecho → Disparos
• LB / RB → Inclinarse en pasillos y esquinas (crítico aquí)
• A → Interactuar con objetos / puertas
• X → Recargar
• Este nivel recompensa el conocimiento del mapa y el uso inteligente de la inclinación.
""",
        playstyle: "Multi-objetivo + Sigilo Avanzado",
        difficultyNote: "El más complejo del arco. La inclinación (LB/RB) es tu mejor amiga."
    ),

    // Colombia
    Mission(
        key: "Find the U'wa Tribe",
        title: "FIND THE U'WA TRIBE",
        location: "Colombia • Selva Amazónica",
        briefing: """
La Agencia te envía a la selva colombiana, 47.

Debes localizar a la tribu U'wa y eliminar a Francisco Mendoza, el narcotraficante que amenaza su territorio sagrado.

El mapa es extenso, denso y hostil: soldados, patrullas y fauna. La exploración es tan peligrosa como el objetivo.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Desplazamiento constante entre claros y senderos
• Stick derecho → Mira suave para vigilar copas y rutas de patrulla
• LB / RB → Inclinarse detrás de troncos y rocas antes de avanzar
• Gatillo derecho → Disparos cortos y precisos (evita alertar campamentos)
• A → Interactuar con objetos y rutas del pueblo U'wa
• X → Recargar antes de cruzar zonas abiertas
• No corras sin necesidad. La selva castiga el ruido y la prisa.
""",
        playstyle: "Exploración + Sigilo en Jungla",
        difficultyNote: "Prioriza orientación y paciencia. Avanza en cortos tramos y usa cobertura natural."
    ),

    Mission(
        key: "The Jungle God",
        title: "THE JUNGLE GOD",
        location: "Colombia • Campamento FARC",
        briefing: """
Mendoza ha caído, pero el verdadero objetivo sigue vivo: Pablo Belisario Ochoa.

Para llegar a él debes infiltrarte en un campamento FARC haciéndote pasar por el Dios de la Selva. El disfraz es tu única credencial.

Un error de postura o un movimiento brusco delatará al falso dios.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Caminar (no correr) dentro del campamento con disfraz
• A → Interactuar para mantener la farsa y abrir accesos
• B → Click derecho para acciones contextuales sin romper cobertura
• LB / RB → Inclinarse en tiendas y barricadas para espiar guardias
• Stick derecho → Control fino si necesitas neutralizar aislados
• X → Recargar en zonas seguras antes de entrar al núcleo del campamento
• Mantén la calma. Aquí gana quien actúa como ritual, no como soldado.
""",
        playstyle: "Infiltración + Disfraz + Sigilo Social",
        difficultyNote: "Evita combates abiertos con el disfraz puesto. Planifica cada interacción."
    ),

    Mission(
        key: "Say Hello to My Little Friend",
        title: "SAY HELLO TO MY LITTLE FRIEND",
        location: "Colombia • Villa de Pablo Ochoa",
        briefing: """
El clímax del arco colombiano, 47.

Pablo Ochoa se refugia en su fortaleza personal, rodeado de hombres, ametralladoras y un helicóptero de vigilancia.

Ya no hay disfraces ni negociaciones. Es asalto puro contra uno de los carteles más armados del continente.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo + Shift → Avance agresivo entre coberturas
• Gatillo derecho → Ráfagas cortas y controladas
• LB / RB → Inclinarse en muros y barricadas (imprescindible)
• Stick derecho → Mira rápida para amenazas múltiples
• X → Recargar en cada pausa de cobertura
• A → Interactuar con puertas y objetivos del recinto
• Gestiona munición y salud. Este nivel no perdona el exceso de confianza.
""",
        playstyle: "Asalto + Acción Intensa + Cobertura",
        difficultyNote: "El combate es inevitable. Avanza por secciones y no te quedes expuesto."
    ),

    // Hungary
    Mission(
        key: "Traditions of the Trade",
        title: "TRADITIONS OF THE TRADE",
        location: "Hungría • Hotel de Budapest",
        briefing: """
Nueva operación, nuevo escenario: un hotel de lujo en Budapest durante una subasta de armas.

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
• Piensa como huésped, actúa como fantasma.
""",
        playstyle: "Sigilo Social + Infiltración en Interiores",
        difficultyNote: "El hotel es un laberinto. Memoriza rutas de servicio y evita zonas concurridas."
    ),

    // Rotterdam
    Mission(
        key: "Gunrunner's Paradise",
        title: "GUNRUNNER'S PARADISE",
        location: "Rotterdam • Puerto y astilleros",
        briefing: """
Los muelles de Rotterdam se han convertido en paraíso de traficantes de armas.

Debes localizar y eliminar a Arkadij Javorinsko, un intermediario clave en la cadena de suministro ilegal.

Contenedores, grúas y barcos crean ángulos de visión complicados y patrullas impredecibles.

RECOMENDACIÓN DE MANDO:
• Stick izquierdo → Movimiento táctico entre contenedores y estructuras
• LB / RB → Inclinarse para limpiar esquinas en el puerto
• Stick derecho → Mira estable para francotirador en largas distancias
• Gatillo derecho → Disparos de confirmación antes de avanzar
• A → Interactuar con accesos, palancas y puntos de infiltración
• X → Recargar tras cada enfrentamiento localizado
• Usa la verticalidad del mapa: techos y pasarelas dan ventaja.
""",
        playstyle: "Sigilo Táctico + Francotirador Urbano",
        difficultyNote: "Reconoce primero, elimina después. El puerto castiga avances sin información."
    ),

    Mission(
        key: "Plutonium Runs Loose",
        title: "PLUTONIUM RUNS LOOSE",
        location: "Rotterdam • Zona portuaria restringida",
        briefing: """
Situación crítica, 47.

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
• Prioriza objetivos por orden. El reloj y el plutonio no negocian.
""",
        playstyle: "Multi-objetivo + Acción Urgente + Gestión de Amenazas",
        difficultyNote: "Misión final del juego. Planifica ruta de eliminación y no persigas todos los blancos a la vez."
    )
]
