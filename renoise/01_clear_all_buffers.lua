--[[============================================================================
Descripción: Elimina el contenido de todos los patrones pero mantiene la 
             estructura (número de líneas, tracks, etc.) para usar como plantilla
============================================================================]]--

-- Función principal
function limpiar_todos_los_patrones()
  
  local song = renoise.song()
  
  -- Obtener el número total de patrones
  local num_patrones = #song.patterns
  
  -- Mensaje de confirmación
  local respuesta = renoise.app():show_prompt(
    "Confirmar Limpieza",
    string.format("¿Estás seguro de que quieres limpiar TODOS los %d patrones?\n\n" ..
                  "Esta acción eliminará todas las notas, efectos y automatizaciones.\n" ..
                  "La estructura de los patrones se mantendrá.", num_patrones),
    {"Sí, limpiar todo", "Cancelar"}
  )
  
  -- Si el usuario cancela, salir
  if respuesta == "Cancelar" then
    renoise.app():show_status("Operación cancelada")
    return
  end
  
  -- Mostrar mensaje de progreso
  renoise.app():show_status("Limpiando patrones...")
  
  -- Iterar sobre todos los patrones y limpiarlos
  for i = 1, num_patrones do
    song.patterns[i]:clear()
  end
  
  -- Mensaje de confirmación
  renoise.app():show_status(
    string.format("✓ %d patrones limpiados exitosamente", num_patrones)
  )
  
  -- Opcional: Mostrar diálogo de éxito
  renoise.app():show_message(
    string.format("Limpieza completada!\n\n" ..
                  "%d patrones han sido limpiados.\n" ..
                  "El archivo está listo para usar como plantilla.", num_patrones)
  )
  
end

-- Ejecutar la función
limpiar_todos_los_patrones()
