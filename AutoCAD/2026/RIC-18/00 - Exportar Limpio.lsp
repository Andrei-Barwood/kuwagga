;;; ============================================================================
;;; EXPORTAR BLOQUES LIMPIOS (autónomo)
;;; Genera un archivo LSP con las definiciones de bloques del dibujo actual,
;;; eliminando códigos DXF problemáticos para su uso con entmake.
;;; Comando: EXPORTAR-LIMPIO
;;; ============================================================================

;;; Función para limpiar una entidad (elimina códigos no válidos para entmake)
(defun limpia-entidad (ent / new)
  (setq new '())
  (foreach par ent
    (cond
      ((member (car par) '(-1 -2 -3)) nil) ; eliminar códigos negativos
      ((= (car par) 5) nil)                 ; handle
      ((= (car par) 102) nil)                ; grupos de reactores
      ((and (>= (car par) 330) (<= (car par) 369)) nil) ; punteros a otros objetos
      (t (setq new (cons par new)))
    )
  )
  (reverse new)
)

;;; Comando principal
(defun c:EXPORTAR-LIMPIO ( / bloques archivo nombre ent entidades lista f blk )
  (princ "\n=== Exportando bloques limpios ===")
  (setq bloques '())
  (setq blk (tblnext "BLOCK" T))
  (while blk
    (setq nombre (cdr (assoc 2 blk)))
    (if (and (not (wcmatch nombre "`**"))
             (not (wcmatch nombre "*Model_Space*"))
             (not (wcmatch nombre "*Paper_Space*")))
      (progn
        (setq ent (entnext (cdr (assoc -2 blk))))
        (setq entidades '())
        (while ent
          (setq entidades (cons (entget ent) entidades))
          (setq ent (entnext ent))
        )
        (setq entidades (reverse entidades))
        ;; Limpiar cada entidad
        (setq entidades (mapcar 'limpia-entidad entidades))
        (setq bloques (cons (cons nombre entidades) bloques))
      )
    )
    (setq blk (tblnext "BLOCK"))
  )
  (setq bloques (reverse bloques))

  (setq archivo (getfiled "Guardar definiciones limpias"
                          (strcat (getvar "dwgprefix") "bloques_limpios.lsp")
                          "lsp" 1))
  (if archivo
    (progn
      (setq f (open archivo "w"))
      (princ ";; Definiciones de bloques limpias (generadas el " f)
      (princ (menucmd "M=$(edtime,0,YYYY-MO-DD HH:MM:SS)") f)
      (princ ")\n" f)
      (princ "(setq *bloques* '(\n" f)
      (foreach bloque bloques
        (princ (strcat "  (\"" (car bloque) "\"\n    (\n") f)
        (foreach ent (cdr bloque)
          (princ "      " f)
          (prin1 ent f)   ; prin1 escribe la lista correctamente
          (princ "\n" f)
        )
        (princ "    ))\n" f)
      )
      (princ "))\n" f)
      (close f)
      (princ (strcat "\nArchivo guardado en: " archivo))
    )
  )
  (princ)
)

;;; Mensaje de carga
(princ "\nComando EXPORTAR-LIMPIO cargado. Ejecútalo en el dibujo con tus bloques originales.")
(princ)