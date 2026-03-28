(defun c:RECUPERA_CAPAS ( / doc lays lay ss i ent edata olderr )
  (vl-load-com)

  (setq olderr *error*)
  (defun *error* (msg)
    (if msg (princ (strcat "\nError: " msg)))
    (setq *error* olderr)
    (princ)
  )

  (setq doc  (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq lays (vla-get-Layers doc))

  (princ "\n--- Recuperando estado de capas ---")

  ;; Recorre todas las capas
  (vlax-for lay lays
    (if (/= (strcase (vla-get-Name lay)) "DEFPOINTS")
      (progn
        ;; Encender
        (vla-put-LayerOn lay :vlax-true)
        ;; Descongelar
        (vla-put-Freeze lay :vlax-false)
        ;; Desbloquear
        (vla-put-Lock lay :vlax-false)
        ;; Permitir ploteo
        (if (vlax-property-available-p lay 'Plottable)
          (vla-put-Plottable lay :vlax-true)
        )
      )
      ;; DEFPOINTS: mantener no ploteable
      (if (vlax-property-available-p lay 'Plottable)
        (vla-put-Plottable lay :vlax-false)
      )
    )
  )

  (princ "\nCapas encendidas, descongeladas y desbloqueadas.")

  ;; Opcional: pasar entidades del dibujo a propiedades ByLayer
  ;; Selecciona todo lo visible
  (setq ss (ssget "_X"))
  (if ss
    (progn
      (princ "\n--- Ajustando propiedades de objetos a ByLayer ---")
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent   (ssname ss i))
        (setq edata (entget ent))

        ;; Color ByLayer
        (if (assoc 62 edata)
          (setq edata (subst (cons 62 256) (assoc 62 edata) edata))
          (setq edata (append edata (list (cons 62 256))))
        )

        ;; Linetype ByLayer
        (if (assoc 6 edata)
          (setq edata (subst (cons 6 "BYLAYER") (assoc 6 edata) edata))
          (setq edata (append edata (list (cons 6 "BYLAYER"))))
        )

        ;; Lineweight ByLayer
        (if (assoc 370 edata)
          (setq edata (subst (cons 370 -1) (assoc 370 edata) edata))
          (setq edata (append edata (list (cons 370 -1))))
        )

        ;; Transparencia por capa / sin override
        (if (assoc 440 edata)
          (setq edata (subst (cons 440 0) (assoc 440 edata) edata))
        )

        (entmod edata)
        (entupd ent)
        (setq i (1+ i))
      )
    )
  )

  ;; Auditoría básica
  (princ "\n--- Ejecutando AUDIT y REGEN ---")
  (command "_.AUDIT" "_Y")
  (command "_.-PURGE" "_R" "*" "_N")
  (command "_.REGENALL")

  (princ "\nListo. Revisa capas, bloques y vuelve a exportar PDF.")
  (setq *error* olderr)
  (princ)
)