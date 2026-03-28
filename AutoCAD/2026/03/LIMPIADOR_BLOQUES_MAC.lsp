(defun _lbm-safe-entity-fix (e / ed)
  (if (and e (entget e))
    (progn
      (setq ed (entget e))

      ;; Mover desde DEFPOINTS si aparece
      (if (= (strcase (cdr (assoc 8 ed))) "DEFPOINTS")
        (setq ed (subst (cons 8 "Z_BLOQUES_LIMPIOS") (assoc 8 ed) ed))
      )

      ;; Forzar ByLayer
      ;; Color
      (if (assoc 62 ed)
        (setq ed (subst (cons 62 256) (assoc 62 ed) ed))
        (setq ed (append ed (list (cons 62 256))))
      )

      ;; Linetype
      (if (assoc 6 ed)
        (setq ed (subst (cons 6 "BYLAYER") (assoc 6 ed) ed))
        (setq ed (append ed (list (cons 6 "BYLAYER"))))
      )

      ;; Lineweight
      (if (assoc 370 ed)
        (setq ed (subst (cons 370 -1) (assoc 370 ed) ed))
        (setq ed (append ed (list (cons 370 -1))))
      )

      ;; Transparencia sin override
      (if (assoc 440 ed)
        (setq ed (subst (cons 440 0) (assoc 440 ed) ed))
      )

      (entmod ed)
      (entupd e)
    )
  )
)

(defun c:LIMPIADOR_BLOQUES_MAC ( / ss i e before after last newEnt entName cleaned explodedCount failedCount )
  (princ "\n=== LIMPIADOR DE BLOQUES PARA AUTOCAD MAC ===")
  (princ "\nATENCION: ejecuta esto sobre una COPIA del DWG.")
  (princ "\nEl comando explotara bloques para dejar geometria limpia.")

  ;; Crear capa limpia si no existe
  (if (not (tblsearch "LAYER" "Z_BLOQUES_LIMPIOS"))
    (command "._-LAYER" "_M" "Z_BLOQUES_LIMPIOS" "_C" "7" "Z_BLOQUES_LIMPIOS" "")
  )

  ;; Encender y descongelar todo
  (command "._LAYON")
  (command "._LAYTHW")
  (command "._-LAYER" "_UNLOCK" "*" "")

  ;; Seleccionar solo INSERTs
  (setq ss (ssget "_X" '((0 . "INSERT"))))

  (setq explodedCount 0)
  (setq failedCount 0)
  (setq cleaned 0)

  (if ss
    (progn
      (princ (strcat "\nBloques encontrados: " (itoa (sslength ss))))
      (setq i 0)

      (while (< i (sslength ss))
        (setq e (ssname ss i))

        ;; Guardar ultimo objeto antes de explotar
        (setq before (entlast))

        ;; Intentar explotar
        (command "._EXPLODE" e)

        ;; Verificar si hubo cambio
        (setq after (entlast))

        (if (and after (/= before after))
          (progn
            (setq explodedCount (1+ explodedCount))

            ;; Recorrer objetos creados desde BEFORE hasta AFTER
            (setq newEnt (entnext before))
            (while newEnt
              (_lbm-safe-entity-fix newEnt)
              ;; mover a capa limpia
              (setq entName (entget newEnt))
              (if (assoc 8 entName)
                (progn
                  (setq entName (subst (cons 8 "Z_BLOQUES_LIMPIOS") (assoc 8 entName) entName))
                  (entmod entName)
                  (entupd newEnt)
                )
              )
              (setq cleaned (1+ cleaned))
              (if (= newEnt after)
                (setq newEnt nil)
                (setq newEnt (entnext newEnt))
              )
            )
          )
          (setq failedCount (1+ failedCount))
        )

        (setq i (1+ i))
      )

      (command "._REGENALL")
      (command "._AUDIT" "_Y")
      (command "._-PURGE" "_R" "*" "_N")
      (command "._-PURGE" "_A" "*" "_N")
      (command "._REGENALL")

      (princ (strcat "\nBloques explotados: " (itoa explodedCount)))
      (princ (strcat "\nBloques no explotados: " (itoa failedCount)))
      (princ (strcat "\nEntidades limpiadas: " (itoa cleaned)))
      (princ "\nListo. Intenta exportar el PDF otra vez.")
    )
    (princ "\nNo se encontraron bloques INSERT en el dibujo.")
  )

  (princ)
)