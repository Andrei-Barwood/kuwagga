(defun _mk-layer-if-missing (doc layname color / lays lay)
  (setq lays (vla-get-Layers doc))
  (if (not (tblsearch "LAYER" layname))
    (progn
      (setq lay (vla-Add lays layname))
      (vla-put-Color lay color)
      (if (vlax-property-available-p lay 'Plottable)
        (vla-put-Plottable lay :vlax-true)
      )
      (vla-put-LayerOn lay :vlax-true)
      (vla-put-Freeze lay :vlax-false)
      (vla-put-Lock lay :vlax-false)
    )
  )
)

(defun _safe-put-bylayer (edata / out)
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

  ;; Transparencia sin override
  (if (assoc 440 edata)
    (setq edata (subst (cons 440 0) (assoc 440 edata) edata))
  )

  edata
)

(defun c:RESCATE_PLOTEO ( / olderr acad doc lays lay ss i ent edata layname movedCount totalCount)
  (vl-load-com)

  (setq olderr *error*)
  (defun *error* (msg)
    (if msg (princ (strcat "\nError: " msg)))
    (setq *error* olderr)
    (princ)
  )

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-ActiveDocument acad))
  (setq lays (vla-get-Layers doc))
  (setq movedCount 0)
  (setq totalCount 0)

  (princ "\n=== RESCATE DE PLOTEO ===")
  (princ "\nRecomendacion: ejecutar sobre una COPIA del archivo.")

  ;; Capas limpias de rescate
  (_mk-layer-if-missing doc "Z_RESCATE_PLOTEO" 7)
  (_mk-layer-if-missing doc "Z_RESCATE_DEFPOINTS" 2)

  ;; Normaliza capas
  (princ "\n-- Normalizando capas --")
  (vlax-for lay lays
    (setq layname (strcase (vla-get-Name lay)))
    (vla-put-LayerOn lay :vlax-true)
    (vla-put-Freeze lay :vlax-false)
    (vla-put-Lock lay :vlax-false)

    (if (vlax-property-available-p lay 'Plottable)
      (if (= layname "DEFPOINTS")
        (vla-put-Plottable lay :vlax-false)
        (vla-put-Plottable lay :vlax-true)
      )
    )
  )

  ;; Selecciona todo
  (setq ss (ssget "_X"))

  (if ss
    (progn
      (princ "\n-- Revisando entidades --")
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent   (ssname ss i))
        (setq edata (entget ent))
        (setq totalCount (1+ totalCount))

        ;; Mover entidades dibujadas en DEFPOINTS
        (if (= (strcase (cdr (assoc 8 edata))) "DEFPOINTS")
          (progn
            (setq edata (subst (cons 8 "Z_RESCATE_DEFPOINTS") (assoc 8 edata) edata))
            (setq movedCount (1+ movedCount))
          )
        )

        ;; Forzar ByLayer
        (setq edata (_safe-put-bylayer edata))

        ;; Aplicar cambios
        (entmod edata)
        (entupd ent)

        (setq i (1+ i))
      )
    )
  )

  (princ (strcat "\nEntidades revisadas: " (itoa totalCount)))
  (princ (strcat "\nEntidades movidas desde DEFPOINTS: " (itoa movedCount)))

  ;; Intento de restaurar viewport/layers básicos
  (princ "\n-- Comandos de saneamiento --")
  (command "_.LAYON" "")
  (command "_.LAYTHW" "")
  (command "_.REGENALL")
  (command "_.AUDIT" "_Y")
  (command "_.-PURGE" "_R" "*" "_N")
  (command "_.-PURGE" "_A" "*" "_N")
  (command "_.REGENALL")

  (princ "\nListo. Ahora intenta exportar PDF de nuevo.")
  (setq *error* olderr)
  (princ)
)