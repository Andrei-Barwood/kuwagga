;==========================================
; SCRIPT: Diagrama Unilineal RIC-18
; Proyecto: Laboratorios Eléctricos
; Contenido: 5 Laboratorios + Pasillo
; Normativa: Pliego Técnico RIC N°18 SEC Chile
; Versión: 1.0
;==========================================

;==========================================
; COMANDO PRINCIPAL
;==========================================
(defun c:DIBUJAR_UNILINEAL_RIC18 ( / )
  (princ "\n========================================")
  (princ "\n  DIAGRAMA UNILINEAL RIC-18")
  (princ "\n  Proyecto Laboratorios Electricos")
  (princ "\n========================================")
  
  ; Crear capas
  (crear_capas_ric18)
  
  ; Dibujar estructura completa
  (dibujar_empalme)
  (dibujar_tablero_general)
  (dibujar_tablero_lab1)
  (dibujar_tablero_lab2)
  (dibujar_tablero_lab3)
  (dibujar_tablero_lab4)
  (dibujar_tablero_lab5)
  (dibujar_tablero_pasillo)
  (dibujar_puesta_tierra)
  
  (princ "\n\n*** DIAGRAMA UNILINEAL COMPLETADO ***")
  (princ "\nUse ZOOM EXTENTS para ver el diagrama completo")
  (command "ZOOM" "E")
  (princ)
)

;==========================================
; CREAR CAPAS SEGÚN RIC-18
;==========================================
(defun crear_capas_ric18 ( / )
  (princ "\nCreando capas...")
  
  ; Capa para líneas de alimentación
  (if (not (tblsearch "LAYER" "UNI-LINEAS"))
    (command "-LAYER" "N" "UNI-LINEAS" "C" "1" "UNI-LINEAS" "LW" "0.35" "UNI-LINEAS" "")
  )
  
  ; Capa para contornos de tableros (línea discontinua)
  (if (not (tblsearch "LAYER" "UNI-TABLERO"))
    (command "-LAYER" "N" "UNI-TABLERO" "C" "5" "UNI-TABLERO" "LW" "0.50" "UNI-TABLERO" "LT" "DASHED" "UNI-TABLERO" "")
  )
  
  ; Capa para protecciones
  (if (not (tblsearch "LAYER" "UNI-PROTEC"))
    (command "-LAYER" "N" "UNI-PROTEC" "C" "3" "UNI-PROTEC" "LW" "0.35" "UNI-PROTEC" "")
  )
  
  ; Capa para textos
  (if (not (tblsearch "LAYER" "UNI-TEXTO"))
    (command "-LAYER" "N" "UNI-TEXTO" "C" "7" "UNI-TEXTO" "LW" "0.18" "UNI-TEXTO" "")
  )
  
  ; Capa para puesta a tierra
  (if (not (tblsearch "LAYER" "UNI-TIERRA"))
    (command "-LAYER" "N" "UNI-TIERRA" "C" "2" "UNI-TIERRA" "LW" "0.35" "UNI-TIERRA" "")
  )
  
  (princ " OK")
)

;==========================================
; DIBUJAR EMPALME TRIFÁSICO
;==========================================
(defun dibujar_empalme ( / x_emp y_emp)
  (princ "\nDibujando empalme...")
  
  ; Posición inicial del empalme
  (setq x_emp 0 y_emp 300)
  
  ; Cambiar a capa de protecciones
  (command "-LAYER" "S" "UNI-PROTEC" "")
  
  ; Símbolo de empalme (cuadrado con E)
  (command "RECTANGLE" 
    (strcat (rtos (- x_emp 6) 2 2) "," (rtos y_emp 2 2))
    (strcat (rtos (+ x_emp 6) 2 2) "," (rtos (+ y_emp 12) 2 2))
  )
  (command "CIRCLE" 
    (strcat (rtos x_emp 2 2) "," (rtos (+ y_emp 6) 2 2))
    "4"
  )
  
  ; Texto "E"
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" 
    (strcat (rtos x_emp 2 2) "," (rtos (+ y_emp 6) 2 2))
    "3" "0" "E"
  )
  
  ; Etiqueta del empalme
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x_emp 10) 2 2) "," (rtos (+ y_emp 10) 2 2))
    "2.5" "0" "Empalme Trifasico"
  )
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x_emp 10) 2 2) "," (rtos (+ y_emp 6) 2 2))
    "2" "0" "3x380/220V - 4 hilos"
  )
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x_emp 10) 2 2) "," (rtos (+ y_emp 2) 2 2))
    "2" "0" "Medidor directo"
  )
  
  ; Línea de bajada desde empalme
  (command "-LAYER" "S" "UNI-LINEAS" "")
  (command "LINE" 
    (strcat (rtos x_emp 2 2) "," (rtos y_emp 2 2))
    (strcat (rtos x_emp 2 2) "," (rtos (- y_emp 20) 2 2))
    ""
  )
  
  ; Etiqueta de alimentador
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x_emp 3) 2 2) "," (rtos (- y_emp 10) 2 2))
    "1.8" "0" "4x10mm2 THHN"
  )
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x_emp 3) 2 2) "," (rtos (- y_emp 14) 2 2))
    "1.8" "0" "T.met. 20mm"
  )
  
  (princ " OK")
)

;==========================================
; DIBUJAR TABLERO GENERAL
;==========================================
(defun dibujar_tablero_general ( / x_tg y_tg)
  (princ "\nDibujando Tablero General...")
  
  (setq x_tg 0 y_tg 200)
  
  ; Contorno del tablero (línea discontinua)
  (command "-LAYER" "S" "UNI-TABLERO" "")
  (command "RECTANGLE" 
    (strcat (rtos (- x_tg 50) 2 2) "," (rtos y_tg 2 2))
    (strcat (rtos (+ x_tg 50) 2 2) "," (rtos (+ y_tg 70) 2 2))
  )
  
  ; Nombre del tablero
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" 
    (strcat (rtos x_tg 2 2) "," (rtos (+ y_tg 65) 2 2))
    "3" "0" "TG"
  )
  (command "TEXT" "J" "MC" 
    (strcat (rtos x_tg 2 2) "," (rtos (+ y_tg 60) 2 2))
    "2" "0" "Tablero General"
  )
  
  ; Interruptor general 4P
  (command "-LAYER" "S" "UNI-PROTEC" "")
  (dibujar_disyuntor x_tg (+ y_tg 45) "4x63A")
  
  ; Diferencial general 4P
  (dibujar_diferencial x_tg (+ y_tg 30) "4x63A" "30mA")
  
  ; Barras de distribución
  (command "-LAYER" "S" "UNI-LINEAS" "")
  (command "LINE" 
    (strcat (rtos (- x_tg 40) 2 2) "," (rtos (+ y_tg 20) 2 2))
    (strcat (rtos (+ x_tg 40) 2 2) "," (rtos (+ y_tg 20) 2 2))
    ""
  )
  
  ; Derivaciones a tableros secundarios
  ; Lab 1
  (command "LINE" 
    (strcat (rtos (- x_tg 35) 2 2) "," (rtos (+ y_tg 20) 2 2))
    (strcat (rtos (- x_tg 35) 2 2) "," (rtos (+ y_tg 5) 2 2))
    ""
  )
  ; Lab 2
  (command "LINE" 
    (strcat (rtos (- x_tg 20) 2 2) "," (rtos (+ y_tg 20) 2 2))
    (strcat (rtos (- x_tg 20) 2 2) "," (rtos (+ y_tg 5) 2 2))
    ""
  )
  ; Lab 3
  (command "LINE" 
    (strcat (rtos (- x_tg 5) 2 2) "," (rtos (+ y_tg 20) 2 2))
    (strcat (rtos (- x_tg 5) 2 2) "," (rtos (+ y_tg 5) 2 2))
    ""
  )
  ; Lab 4
  (command "LINE" 
    (strcat (rtos (+ x_tg 10) 2 2) "," (rtos (+ y_tg 20) 2 2))
    (strcat (rtos (+ x_tg 10) 2 2) "," (rtos (+ y_tg 5) 2 2))
    ""
  )
  ; Lab 5
  (command "LINE" 
    (strcat (rtos (+ x_tg 25) 2 2) "," (rtos (+ y_tg 20) 2 2))
    (strcat (rtos (+ x_tg 25) 2 2) "," (rtos (+ y_tg 5) 2 2))
    ""
  )
  ; Pasillo
  (command "LINE" 
    (strcat (rtos (+ x_tg 40) 2 2) "," (rtos (+ y_tg 20) 2 2))
    (strcat (rtos (+ x_tg 40) 2 2) "," (rtos (+ y_tg 5) 2 2))
    ""
  )
  
  ; Círculos de derivación
  (command "-LAYER" "S" "UNI-PROTEC" "")
  (command "CIRCLE" (strcat (rtos (- x_tg 35) 2 2) "," (rtos (+ y_tg 5) 2 2)) "3")
  (command "CIRCLE" (strcat (rtos (- x_tg 20) 2 2) "," (rtos (+ y_tg 5) 2 2)) "3")
  (command "CIRCLE" (strcat (rtos (- x_tg 5) 2 2) "," (rtos (+ y_tg 5) 2 2)) "3")
  (command "CIRCLE" (strcat (rtos (+ x_tg 10) 2 2) "," (rtos (+ y_tg 5) 2 2)) "3")
  (command "CIRCLE" (strcat (rtos (+ x_tg 25) 2 2) "," (rtos (+ y_tg 5) 2 2)) "3")
  (command "CIRCLE" (strcat (rtos (+ x_tg 40) 2 2) "," (rtos (+ y_tg 5) 2 2)) "3")
  
  ; Números de circuitos
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" (strcat (rtos (- x_tg 35) 2 2) "," (rtos (+ y_tg 5) 2 2)) "2" "0" "1")
  (command "TEXT" "J" "MC" (strcat (rtos (- x_tg 20) 2 2) "," (rtos (+ y_tg 5) 2 2)) "2" "0" "2")
  (command "TEXT" "J" "MC" (strcat (rtos (- x_tg 5) 2 2) "," (rtos (+ y_tg 5) 2 2)) "2" "0" "3")
  (command "TEXT" "J" "MC" (strcat (rtos (+ x_tg 10) 2 2) "," (rtos (+ y_tg 5) 2 2)) "2" "0" "4")
  (command "TEXT" "J" "MC" (strcat (rtos (+ x_tg 25) 2 2) "," (rtos (+ y_tg 5) 2 2)) "2" "0" "5")
  (command "TEXT" "J" "MC" (strcat (rtos (+ x_tg 40) 2 2) "," (rtos (+ y_tg 5) 2 2)) "2" "0" "6")
  
  (princ " OK")
)

;==========================================
; FUNCIÓN: Dibujar disyuntor/termomagnético
;==========================================
(defun dibujar_disyuntor (x y etiqueta / )
  ; Símbolo de disyuntor
  (command "-LAYER" "S" "UNI-PROTEC" "")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos (+ y 8) 2 2))
    (strcat (rtos x 2 2) "," (rtos (+ y 5) 2 2))
    ""
  )
  (command "CIRCLE" (strcat (rtos x 2 2) "," (rtos (+ y 3) 2 2)) "2")
  (command "CIRCLE" (strcat (rtos x 2 2) "," (rtos y 2 2)) "0.8")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos y 2 2))
    (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2))
    ""
  )
  
  ; Etiqueta
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 4) 2 2) "," (rtos (+ y 3) 2 2))
    "1.8" "0" etiqueta
  )
)

;==========================================
; FUNCIÓN: Dibujar diferencial
;==========================================
(defun dibujar_diferencial (x y corriente sensib / )
  ; Símbolo de diferencial (cuadrado con diagonal)
  (command "-LAYER" "S" "UNI-PROTEC" "")
  (command "RECTANGLE" 
    (strcat (rtos (- x 4) 2 2) "," (rtos y 2 2))
    (strcat (rtos (+ x 4) 2 2) "," (rtos (+ y 8) 2 2))
  )
  (command "LINE" 
    (strcat (rtos (- x 4) 2 2) "," (rtos y 2 2))
    (strcat (rtos (+ x 4) 2 2) "," (rtos (+ y 8) 2 2))
    ""
  )
  
  ; Líneas de conexión
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos (+ y 8) 2 2))
    (strcat (rtos x 2 2) "," (rtos (+ y 12) 2 2))
    ""
  )
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos y 2 2))
    (strcat (rtos x 2 2) "," (rtos (- y 4) 2 2))
    ""
  )
  
  ; Etiquetas
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 6) 2 2) "," (rtos (+ y 6) 2 2))
    "1.8" "0" corriente
  )
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 6) 2 2) "," (rtos (+ y 2) 2 2))
    "1.8" "0" sensib
  )
)

;==========================================
; DIBUJAR TABLERO LAB 1 (Monofásico)
;==========================================
(defun dibujar_tablero_lab1 ( / )
  (princ "\nDibujando TD-LAB1...")
  (dibujar_tablero_mono -100 80 "TD-LAB1" "Laboratorio 1")
  (princ " OK")
)

;==========================================
; DIBUJAR TABLERO LAB 2 (Monofásico)
;==========================================
(defun dibujar_tablero_lab2 ( / )
  (princ "\nDibujando TD-LAB2...")
  (dibujar_tablero_mono -50 80 "TD-LAB2" "Laboratorio 2")
  (princ " OK")
)

;==========================================
; DIBUJAR TABLERO LAB 3 (Monofásico)
;==========================================
(defun dibujar_tablero_lab3 ( / )
  (princ "\nDibujando TD-LAB3...")
  (dibujar_tablero_mono 0 80 "TD-LAB3" "Laboratorio 3")
  (princ " OK")
)

;==========================================
; DIBUJAR TABLERO LAB 4 (Monofásico)
;==========================================
(defun dibujar_tablero_lab4 ( / )
  (princ "\nDibujando TD-LAB4...")
  (dibujar_tablero_mono 50 80 "TD-LAB4" "Laboratorio 4")
  (princ " OK")
)

;==========================================
; FUNCIÓN: Dibujar tablero monofásico genérico
;==========================================
(defun dibujar_tablero_mono (x y nombre desc / )
  ; Contorno del tablero
  (command "-LAYER" "S" "UNI-TABLERO" "")
  (command "RECTANGLE" 
    (strcat (rtos (- x 20) 2 2) "," (rtos (- y 60) 2 2))
    (strcat (rtos (+ x 20) 2 2) "," (rtos y 2 2))
  )
  
  ; Nombre del tablero
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2))
    "2.5" "0" nombre
  )
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 9) 2 2))
    "1.8" "0" desc
  )
  
  ; Línea de alimentación
  (command "-LAYER" "S" "UNI-LINEAS" "")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos y 2 2))
    (strcat (rtos x 2 2) "," (rtos (+ y 15) 2 2))
    ""
  )
  
  ; Etiqueta alimentador
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 3) 2 2) "," (rtos (+ y 10) 2 2))
    "1.5" "0" "2x4mm2 THHN"
  )
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 3) 2 2) "," (rtos (+ y 6) 2 2))
    "1.5" "0" "T.p.r.e. 20mm"
  )
  
  ; Diferencial 2P
  (dibujar_diferencial x (- y 20) "2x40A" "30mA")
  
  ; Circuitos derivados
  ; C1 - Alumbrado
  (dibujar_circuito_derivado (- x 10) (- y 38) "1" "1x6A" "2x1.5mm2" "CTO.ALUMBRADO")
  
  ; C2 - Enchufes 10A
  (dibujar_circuito_derivado x (- y 38) "2" "1x10A" "3x2.5mm2" "CTO.ENCH.10A")
  
  ; C3 - Enchufes 16A
  (dibujar_circuito_derivado (+ x 10) (- y 38) "3" "1x16A" "3x4mm2" "CTO.ENCH.16A")
)

;==========================================
; FUNCIÓN: Dibujar circuito derivado
;==========================================
(defun dibujar_circuito_derivado (x y num protec conductor desc / )
  ; Disyuntor
  (command "-LAYER" "S" "UNI-PROTEC" "")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos (+ y 15) 2 2))
    (strcat (rtos x 2 2) "," (rtos (+ y 10) 2 2))
    ""
  )
  (command "CIRCLE" (strcat (rtos x 2 2) "," (rtos (+ y 8) 2 2)) "1.5")
  (command "CIRCLE" (strcat (rtos x 2 2) "," (rtos (+ y 5) 2 2)) "0.6")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos (+ y 5) 2 2))
    (strcat (rtos x 2 2) "," (rtos y 2 2))
    ""
  )
  
  ; Círculo del circuito
  (command "CIRCLE" (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2)) "4")
  
  ; Número del circuito
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2))
    "2.5" "0" num
  )
  
  ; Etiqueta protección
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (+ y 12) 2 2))
    "1.5" "0" protec
  )
  
  ; Etiqueta conductor (debajo del círculo)
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 12) 2 2))
    "1.2" "0" conductor
  )
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 15) 2 2))
    "1.2" "0" "T.p.r.e.20mm"
  )
  
  ; Descripción del circuito
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 19) 2 2))
    "1.5" "0" desc
  )
)

;==========================================
; DIBUJAR TABLERO LAB 5 (Trifásico)
;==========================================
(defun dibujar_tablero_lab5 ( / x y)
  (princ "\nDibujando TD-LAB5 (Trifasico)...")
  
  (setq x 100 y 80)
  
  ; Contorno del tablero (más grande)
  (command "-LAYER" "S" "UNI-TABLERO" "")
  (command "RECTANGLE" 
    (strcat (rtos (- x 30) 2 2) "," (rtos (- y 80) 2 2))
    (strcat (rtos (+ x 30) 2 2) "," (rtos y 2 2))
  )
  
  ; Nombre del tablero
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2))
    "2.5" "0" "TD-LAB5"
  )
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 9) 2 2))
    "1.8" "0" "Laboratorio 5 - TRIFASICO"
  )
  
  ; Línea de alimentación trifásica
  (command "-LAYER" "S" "UNI-LINEAS" "")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos y 2 2))
    (strcat (rtos x 2 2) "," (rtos (+ y 15) 2 2))
    ""
  )
  
  ; Etiqueta alimentador trifásico
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 3) 2 2) "," (rtos (+ y 10) 2 2))
    "1.5" "0" "4x6mm2 THHN"
  )
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 3) 2 2) "," (rtos (+ y 6) 2 2))
    "1.5" "0" "T.p.r.e. 20mm"
  )
  
  ; Diferencial 4P
  (dibujar_diferencial x (- y 20) "4x63A" "30mA")
  
  ; Circuitos derivados monofásicos
  ; C1 - Alumbrado
  (dibujar_circuito_derivado (- x 20) (- y 45) "1" "1x6A" "2x1.5mm2" "CTO.ALUMBRADO")
  
  ; C2 - Enchufes 10A
  (dibujar_circuito_derivado (- x 8) (- y 45) "2" "1x10A" "3x2.5mm2" "CTO.ENCH.10A")
  
  ; C3 - Enchufes 16A
  (dibujar_circuito_derivado (+ x 4) (- y 45) "3" "1x16A" "3x4mm2" "CTO.ENCH.16A")
  
  ; C4 - Circuito trifásico 12kW
  (dibujar_circuito_trifasico (+ x 18) (- y 45) "4" "3x20A" "5x6mm2" "CTO.TRIF.12kW")
  
  (princ " OK")
)

;==========================================
; FUNCIÓN: Dibujar circuito trifásico
;==========================================
(defun dibujar_circuito_trifasico (x y num protec conductor desc / )
  ; Disyuntor tripolar (3 símbolos unidos)
  (command "-LAYER" "S" "UNI-PROTEC" "")
  
  ; Tres líneas verticales
  (command "LINE" (strcat (rtos (- x 2) 2 2) "," (rtos (+ y 15) 2 2))
                  (strcat (rtos (- x 2) 2 2) "," (rtos (+ y 10) 2 2)) "")
  (command "LINE" (strcat (rtos x 2 2) "," (rtos (+ y 15) 2 2))
                  (strcat (rtos x 2 2) "," (rtos (+ y 10) 2 2)) "")
  (command "LINE" (strcat (rtos (+ x 2) 2 2) "," (rtos (+ y 15) 2 2))
                  (strcat (rtos (+ x 2) 2 2) "," (rtos (+ y 10) 2 2)) "")
  
  ; Tres círculos (mecanismos)
  (command "CIRCLE" (strcat (rtos (- x 2) 2 2) "," (rtos (+ y 8) 2 2)) "1")
  (command "CIRCLE" (strcat (rtos x 2 2) "," (rtos (+ y 8) 2 2)) "1")
  (command "CIRCLE" (strcat (rtos (+ x 2) 2 2) "," (rtos (+ y 8) 2 2)) "1")
  
  ; Barra de acoplamiento
  (command "LINE" (strcat (rtos (- x 2) 2 2) "," (rtos (+ y 15.5) 2 2))
                  (strcat (rtos (+ x 2) 2 2) "," (rtos (+ y 15.5) 2 2)) "")
  
  ; Líneas de salida
  (command "LINE" (strcat (rtos (- x 2) 2 2) "," (rtos (+ y 7) 2 2))
                  (strcat (rtos (- x 2) 2 2) "," (rtos y 2 2)) "")
  (command "LINE" (strcat (rtos x 2 2) "," (rtos (+ y 7) 2 2))
                  (strcat (rtos x 2 2) "," (rtos y 2 2)) "")
  (command "LINE" (strcat (rtos (+ x 2) 2 2) "," (rtos (+ y 7) 2 2))
                  (strcat (rtos (+ x 2) 2 2) "," (rtos y 2 2)) "")
  
  ; Círculo del circuito
  (command "CIRCLE" (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2)) "4")
  
  ; Número del circuito
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2))
    "2.5" "0" num
  )
  
  ; Etiqueta protección
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (+ y 18) 2 2))
    "1.5" "0" protec
  )
  
  ; Etiqueta conductor
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 12) 2 2))
    "1.2" "0" conductor
  )
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 15) 2 2))
    "1.2" "0" "T.p.r.e.20mm"
  )
  
  ; Descripción
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 19) 2 2))
    "1.5" "0" desc
  )
)

;==========================================
; DIBUJAR TABLERO PASILLO
;==========================================
(defun dibujar_tablero_pasillo ( / x y)
  (princ "\nDibujando TD-PASILLO...")
  
  (setq x 160 y 80)
  
  ; Contorno del tablero
  (command "-LAYER" "S" "UNI-TABLERO" "")
  (command "RECTANGLE" 
    (strcat (rtos (- x 18) 2 2) "," (rtos (- y 50) 2 2))
    (strcat (rtos (+ x 18) 2 2) "," (rtos y 2 2))
  )
  
  ; Nombre del tablero
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 5) 2 2))
    "2.5" "0" "TD-PASILLO"
  )
  (command "TEXT" "J" "MC" 
    (strcat (rtos x 2 2) "," (rtos (- y 9) 2 2))
    "1.8" "0" "Pasillo"
  )
  
  ; Línea de alimentación
  (command "-LAYER" "S" "UNI-LINEAS" "")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos y 2 2))
    (strcat (rtos x 2 2) "," (rtos (+ y 15) 2 2))
    ""
  )
  
  ; Etiqueta alimentador
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 3) 2 2) "," (rtos (+ y 10) 2 2))
    "1.5" "0" "2x2.5mm2 THHN"
  )
  (command "TEXT" "J" "ML" 
    (strcat (rtos (+ x 3) 2 2) "," (rtos (+ y 6) 2 2))
    "1.5" "0" "T.p.r.e. 20mm"
  )
  
  ; Diferencial 2P
  (dibujar_diferencial x (- y 20) "2x25A" "30mA")
  
  ; Circuitos derivados
  ; C1 - Alumbrado pasillo (luminarias 30W)
  (dibujar_circuito_derivado (- x 8) (- y 35) "1" "1x6A" "2x1.5mm2" "CTO.ALUMB.30W")
  
  ; C2 - Enchufes pasillo
  (dibujar_circuito_derivado (+ x 8) (- y 35) "2" "1x10A" "3x2.5mm2" "CTO.ENCH.10A")
  
  (princ " OK")
)

;==========================================
; DIBUJAR PUESTA A TIERRA
;==========================================
(defun dibujar_puesta_tierra ( / x y y_ts x_tp y_tp)
  (princ "\nDibujando sistema de puesta a tierra...")
  
  (setq x -80 y 150)
  
  ; Línea desde tablero general
  (command "-LAYER" "S" "UNI-TIERRA" "")
  (command "LINE" 
    (strcat (rtos x 2 2) "," (rtos y 2 2))
    (strcat (rtos x 2 2) "," (rtos (- y 40) 2 2))
    ""
  )
  
  ; Símbolo T.S. (Tierra de Servicio)
  (setq y_ts (- y 50))
  (command "LINE" (strcat (rtos (- x 5) 2 2) "," (rtos y_ts 2 2))
                  (strcat (rtos (+ x 5) 2 2) "," (rtos y_ts 2 2)) "")
  (command "LINE" (strcat (rtos (- x 3.5) 2 2) "," (rtos (- y_ts 3) 2 2))
                  (strcat (rtos (+ x 3.5) 2 2) "," (rtos (- y_ts 3) 2 2)) "")
  (command "LINE" (strcat (rtos (- x 2) 2 2) "," (rtos (- y_ts 6) 2 2))
                  (strcat (rtos (+ x 2) 2 2) "," (rtos (- y_ts 6) 2 2)) "")
  
  ; Etiquetas T.S.
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" (strcat (rtos x 2 2) "," (rtos (- y_ts 10) 2 2)) "2" "0" "T.S.")
  (command "TEXT" "J" "ML" (strcat (rtos (+ x 8) 2 2) "," (rtos y_ts 2 2)) "1.5" "0" "1x25mm2 NYA")
  (command "TEXT" "J" "ML" (strcat (rtos (+ x 8) 2 2) "," (rtos (- y_ts 4) 2 2)) "1.5" "0" "ELECTRODO")
  (command "TEXT" "J" "ML" (strcat (rtos (+ x 8) 2 2) "," (rtos (- y_ts 8) 2 2)) "1.5" "0" "BARRA C.W. 5/8x2.40m")
  (command "TEXT" "J" "ML" (strcat (rtos (+ x 8) 2 2) "," (rtos (- y_ts 12) 2 2)) "1.5" "0" "Camara 40x40x40cm")
  
  ; Símbolo T.P. (Tierra de Protección)
  (setq x_tp (+ x 50) y_tp y_ts)
  (command "-LAYER" "S" "UNI-TIERRA" "")
  (command "LINE" (strcat (rtos (- x_tp 5) 2 2) "," (rtos y_tp 2 2))
                  (strcat (rtos (+ x_tp 5) 2 2) "," (rtos y_tp 2 2)) "")
  ; Líneas verticales tipo peine
  (command "LINE" (strcat (rtos (- x_tp 4) 2 2) "," (rtos y_tp 2 2))
                  (strcat (rtos (- x_tp 4) 2 2) "," (rtos (- y_tp 4) 2 2)) "")
  (command "LINE" (strcat (rtos (- x_tp 2) 2 2) "," (rtos y_tp 2 2))
                  (strcat (rtos (- x_tp 2) 2 2) "," (rtos (- y_tp 4) 2 2)) "")
  (command "LINE" (strcat (rtos x_tp 2 2) "," (rtos y_tp 2 2))
                  (strcat (rtos x_tp 2 2) "," (rtos (- y_tp 4) 2 2)) "")
  (command "LINE" (strcat (rtos (+ x_tp 2) 2 2) "," (rtos y_tp 2 2))
                  (strcat (rtos (+ x_tp 2) 2 2) "," (rtos (- y_tp 4) 2 2)) "")
  (command "LINE" (strcat (rtos (+ x_tp 4) 2 2) "," (rtos y_tp 2 2))
                  (strcat (rtos (+ x_tp 4) 2 2) "," (rtos (- y_tp 4) 2 2)) "")
  
  ; Etiqueta T.P.
  (command "-LAYER" "S" "UNI-TEXTO" "")
  (command "TEXT" "J" "MC" (strcat (rtos x_tp 2 2) "," (rtos (- y_tp 8) 2 2)) "2" "0" "T.P.")
  (command "TEXT" "J" "ML" (strcat (rtos (+ x_tp 8) 2 2) "," (rtos y_tp 2 2)) "1.5" "0" "1x4mm2 NYA")
  (command "TEXT" "J" "ML" (strcat (rtos (+ x_tp 8) 2 2) "," (rtos (- y_tp 4) 2 2)) "1.5" "0" "T.p.r.e. 3/4in")
  
  ; Conexión entre T.S. y T.P.
  (command "-LAYER" "S" "UNI-TIERRA" "")
  (command "LINE" (strcat (rtos (+ x 5) 2 2) "," (rtos y_ts 2 2))
                  (strcat (rtos (- x_tp 5) 2 2) "," (rtos y_tp 2 2)) "")
  
  (princ " OK")
)

;==========================================
; MENSAJE DE CARGA
;==========================================
(princ "\n==========================================")
(princ "\n  Script Diagrama Unilineal RIC-18")
(princ "\n  Proyecto Laboratorios Electricos")
(princ "\n==========================================")
(princ "\nEscribe: DIBUJAR_UNILINEAL_RIC18 para ejecutar")
(princ)
