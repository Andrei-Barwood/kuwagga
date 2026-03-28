(defun c:SANEA_LAYOUT_MAC ( / )
  (princ "\n=== SANEAMIENTO DE LAYOUT / VIEWPORT PARA MAC ===")

  ;; Estado general de capas
  (command "._LAYON")
  (command "._LAYTHW")
  (command "._-LAYER" "_UNLOCK" "*" "")
  (command "._REGENALL")

  (princ "\nCapas encendidas, descongeladas y desbloqueadas.")
  (princ "\nAhora entra al viewport de la presentacion y revisa manualmente VP Freeze.")
  (princ "\nRevisa tambien que las capas tengan la impresora activada.")
  (princ)
)