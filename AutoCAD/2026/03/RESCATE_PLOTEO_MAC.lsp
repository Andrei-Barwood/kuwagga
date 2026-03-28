(defun c:RESCATE_PLOTEO_MAC ( / ss i ent edata layname movedCount totalCount )

  (setq movedCount 0)
  (setq totalCount 0)

  (princ "\n=== RESCATE DE PLOTEO PARA AUTOCAD MAC ===")
  (princ "\nRecomendacion: ejecutar sobre una COPIA del DWG.")

  ;; Crear capa de rescate si no existe
  (if (not (tblsearch "LAYER" "Z_RESCATE_DEFPOINTS"))
    (command "._-LAYER" "_M" "Z_RESCATE_DEFPOINTS" "_C" "2" "Z_RESCATE_DEFPOINTS" "")
  )

  ;; Encender/descongelar/desbloquear capas
  (command "._LAYON")
  (command "._LAYTHW")
  (command "._-LAYER" "_UNLOCK" "*" "")

  ;; Seleccionar todo
  (setq ss (ssget "_X"))

  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent   (ssname ss i))
        (setq edata (entget ent))
        (setq totalCount (1+ totalCount))

        ;; Obtener capa actual de la entidad
        (setq layname (cdr (assoc 8 edata)))

        ;; Si está en DEFPOINTS, mover a capa de rescate
        (if (= (strcase layname) "DEFPOINTS")
          (progn
            (setq edata (subst (cons 8 "Z_RESCATE_DEFPOINTS") (assoc 8 edata) edata))
            (setq movedCount (1+ movedCount))
          )
        )

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

        (entmod edata)
        (entupd ent)

        (setq i (1+ i))
      )
    )
  )

  (princ (strcat "\nEntidades revisadas: " (itoa totalCount)))
  (princ (strcat "\nEntidades movidas desde DEFPOINTS: " (itoa movedCount)))

  ;; Auditoría y regeneración
  (command "._REGENALL")
  (command "._AUDIT" "_Y")
  (command "._-PURGE" "_R" "*" "_N")
  (command "._-PURGE" "_A" "*" "_N")
  (command "._REGENALL")

  (princ "\nListo. Intenta exportar PDF nuevamente.")
  (princ)
)