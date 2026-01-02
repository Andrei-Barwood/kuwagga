;==========================================
; SCRIPT: Guardar Diagrama como Plantilla DWT
; Proyecto: Plantilla RIC-18 para Diagramas Unilineales
; Licencia: Código Abierto - Libre Distribución
;==========================================

(defun c:CREAR_PLANTILLA_RIC18 ( / ruta_plantilla)
  (princ "\n==========================================")
  (princ "\n  CREAR PLANTILLA RIC-18")
  (princ "\n==========================================")
  
  ; Verificar que existan las capas
  (if (not (tblsearch "LAYER" "UNI-LINEAS"))
    (progn
      (princ "\n[!] Las capas RIC-18 no existen.")
      (princ "\n    Ejecuta primero: DIBUJAR_UNILINEAL_RIC18")
      (princ "\n    O ejecuta: CREAR_CAPAS_SOLO")
      (exit)
    )
  )
  
  ; Limpiar el dibujo de objetos (dejar solo capas, estilos, etc.)
  (initget "Si No")
  (setq resp (getkword "\n¿Eliminar geometría y dejar solo capas/estilos? [Si/No] <No>: "))
  
  (if (= resp "Si")
    (progn
      (princ "\nLimpiando geometría...")
      (command "ERASE" "ALL" "")
      (command "PURGE" "ALL" "" "N")
    )
  )
  
  ; Solicitar ruta para guardar
  (setq ruta_plantilla (getfiled "Guardar Plantilla RIC-18" "" "dwt" 1))
  
  (if ruta_plantilla
    (progn
      ; Guardar como plantilla
      (command "SAVEAS" "DWT" ruta_plantilla)
      (princ (strcat "\n✓ Plantilla guardada en: " ruta_plantilla))
      (princ "\n\n==========================================")
      (princ "\n  PLANTILLA CREADA EXITOSAMENTE")
      (princ "\n==========================================")
      (princ "\nAhora puedes:")
      (princ "\n- Compartir el archivo .dwt")
      (princ "\n- Usarlo como base para nuevos proyectos")
      (princ "\n- Subirlo a GitHub o BiblioCAD")
    )
    (princ "\n[X] Operación cancelada")
  )
  (princ)
)

;==========================================
; CREAR SOLO CAPAS (sin dibujar)
;==========================================
(defun c:CREAR_CAPAS_SOLO ( / )
  (princ "\nCreando capas RIC-18...")
  
  ; Capa para líneas de alimentación - ROJO
  (if (not (tblsearch "LAYER" "UNI-LINEAS"))
    (command "-LAYER" "N" "UNI-LINEAS" "C" "1" "UNI-LINEAS" "LW" "0.35" "UNI-LINEAS" "")
  )
  
  ; Capa para contornos de tableros - AZUL DISCONTINUO
  (if (not (tblsearch "LAYER" "UNI-TABLERO"))
    (command "-LAYER" "N" "UNI-TABLERO" "C" "5" "UNI-TABLERO" "LW" "0.50" "UNI-TABLERO" "LT" "DASHED" "UNI-TABLERO" "")
  )
  
  ; Capa para protecciones - VERDE
  (if (not (tblsearch "LAYER" "UNI-PROTEC"))
    (command "-LAYER" "N" "UNI-PROTEC" "C" "3" "UNI-PROTEC" "LW" "0.35" "UNI-PROTEC" "")
  )
  
  ; Capa para textos - BLANCO
  (if (not (tblsearch "LAYER" "UNI-TEXTO"))
    (command "-LAYER" "N" "UNI-TEXTO" "C" "7" "UNI-TEXTO" "LW" "0.18" "UNI-TEXTO" "")
  )
  
  ; Capa para puesta a tierra - AMARILLO
  (if (not (tblsearch "LAYER" "UNI-TIERRA"))
    (command "-LAYER" "N" "UNI-TIERRA" "C" "2" "UNI-TIERRA" "LW" "0.35" "UNI-TIERRA" "")
  )
  
  ; Capa para cuadro de cargas - CIAN
  (if (not (tblsearch "LAYER" "UNI-CUADRO"))
    (command "-LAYER" "N" "UNI-CUADRO" "C" "4" "UNI-CUADRO" "LW" "0.25" "UNI-CUADRO" "")
  )
  
  ; Capa para viñeta/cajetín - MAGENTA
  (if (not (tblsearch "LAYER" "UNI-VINETA"))
    (command "-LAYER" "N" "UNI-VINETA" "C" "6" "UNI-VINETA" "LW" "0.50" "UNI-VINETA" "")
  )
  
  (princ "\n✓ Capas RIC-18 creadas:")
  (princ "\n  - UNI-LINEAS (Rojo)")
  (princ "\n  - UNI-TABLERO (Azul, discontinua)")
  (princ "\n  - UNI-PROTEC (Verde)")
  (princ "\n  - UNI-TEXTO (Blanco)")
  (princ "\n  - UNI-TIERRA (Amarillo)")
  (princ "\n  - UNI-CUADRO (Cian)")
  (princ "\n  - UNI-VINETA (Magenta)")
  (princ)
)

;==========================================
; MENSAJE DE CARGA
;==========================================
(princ "\n==========================================")
(princ "\n  Herramientas de Plantilla RIC-18")
(princ "\n==========================================")
(princ "\nComandos disponibles:")
(princ "\n  CREAR_PLANTILLA_RIC18 - Guarda como .dwt")
(princ "\n  CREAR_CAPAS_SOLO - Crea capas sin dibujar")
(princ "\n==========================================")
(princ)
