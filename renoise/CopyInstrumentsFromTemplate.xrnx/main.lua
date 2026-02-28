-- Copy Instruments from Template Song
-- Renoise Tool (.xrnx)

local STATE = {
  phase = "idle",        -- "idle" | "loading_template" | "loading_original"
  original_path = "",    -- ruta de la cancion destino
  template_path = "",    -- ruta de la cancion plantilla
  exported_files = {},   -- lista de rutas a XRNI temporales
}

local function cleanup_temp_files()
  for _, filepath in ipairs(STATE.exported_files) do
    os.remove(filepath)
  end
  STATE.exported_files = {}
end

local function reset_state()
  cleanup_temp_files()
  STATE.phase = "idle"
  STATE.original_path = ""
  STATE.template_path = ""
end

local function make_temp_xrni_path(index, name)
  local safe = (name or ""):gsub("[^%w%-_]", "_")
  if safe == "" or safe:match("^_+$") then safe = "instr" end
  local base = os.tmpname()
  os.remove(base)
  return string.format("%s_%02d_%s.xrni", base, index, safe)
end

local function import_exported_instruments()
  local app = renoise.app()
  local song = renoise.song()

  local saved_sel = song.selected_instrument_index
  local added = 0
  local skipped = 0

  song:describe_undo("Copy Instruments from Template Song")

  for _, filepath in ipairs(STATE.exported_files) do
    local before_count = #song.instruments
    local slot_idx = before_count + 1
    song:insert_instrument_at(slot_idx)
    song.selected_instrument_index = slot_idx

    local ok = app:load_instrument(filepath)

    if ok then
      local loaded_idx = slot_idx
      local after_count = #song.instruments

      -- En algunas versiones/configs, load_instrument inserta un slot nuevo
      -- adicional en vez de reutilizar el seleccionado.
      if after_count == (before_count + 2) then
        -- Eliminamos el placeholder para evitar huecos entre instrumentos.
        song:delete_instrument_at(slot_idx)
        loaded_idx = slot_idx
      end

      local new_name = song.instruments[loaded_idx].name
      local duplicate = false

      if new_name ~= "" then
        for i = 1, #song.instruments do
          if i ~= loaded_idx and song.instruments[i].name == new_name then
            duplicate = true
            break
          end
        end
      end

      if duplicate then
        song:delete_instrument_at(loaded_idx)
        skipped = skipped + 1
      else
        added = added + 1
      end
    else
      if slot_idx <= #song.instruments then
        song:delete_instrument_at(slot_idx)
      end
    end
  end

  if saved_sel <= #song.instruments then
    song.selected_instrument_index = saved_sel
  end

  cleanup_temp_files()

  local msg = string.format("Importados: %d instrumento(s)", added)
  if skipped > 0 then
    msg = msg .. string.format(" | Omitidos (duplicados): %d", skipped)
  end
  app:show_status(msg)

  reset_state()
end

local function select_and_export_instruments()
  local app = renoise.app()
  local song = renoise.song()

  local items = {}
  for i, instr in ipairs(song.instruments) do
    if instr.name ~= "" or #instr.samples > 0 then
      table.insert(items, {
        index = i,
        name = instr.name ~= "" and instr.name or string.format("(sin nombre #%d)", i),
      })
    end
  end

  if #items == 0 then
    app:show_warning("La plantilla no contiene instrumentos con contenido.")
    STATE.phase = "loading_original"
    app:load_song(STATE.original_path)
    return
  end

  local vb = renoise.ViewBuilder()
  local cbs = {}
  local col = vb:column { margin = 10, spacing = 2 }

  col:add_child(vb:text {
    text = "Plantilla: " .. (STATE.template_path:match("([^/\\]+)$") or STATE.template_path),
    font = "bold",
  })
  col:add_child(vb:text { text = string.format("%d instrumento(s) encontrado(s):", #items) })
  col:add_child(vb:space { height = 6 })

  local toggle_all = vb:checkbox {
    value = true,
    notifier = function(v)
      for _, cb in pairs(cbs) do cb.value = v end
    end,
  }

  col:add_child(vb:row {
    spacing = 5,
    toggle_all,
    vb:text { text = "Seleccionar / deseleccionar todos", font = "italic" },
  })
  col:add_child(vb:space { height = 4 })

  for _, item in ipairs(items) do
    local cb = vb:checkbox { value = true }
    cbs[item.index] = cb
    col:add_child(vb:row {
      spacing = 5,
      cb,
      vb:text { text = string.format("%02X: %s", item.index - 1, item.name) },
    })
  end

  local answer = app:show_custom_prompt(
    "Copiar Instrumentos de Plantilla",
    col,
    { "Copiar seleccionados", "Cancelar" }
  )

  if answer == "Cancelar" then
    STATE.phase = "loading_original"
    app:load_song(STATE.original_path)
    return
  end

  local selected = {}
  for idx, cb in pairs(cbs) do
    if cb.value then table.insert(selected, idx) end
  end
  table.sort(selected)

  if #selected == 0 then
    app:show_warning("No seleccionaste ningun instrumento.")
    STATE.phase = "loading_original"
    app:load_song(STATE.original_path)
    return
  end

  local saved_sel = song.selected_instrument_index
  STATE.exported_files = {}

  for _, idx in ipairs(selected) do
    song.selected_instrument_index = idx
    local tmp = make_temp_xrni_path(idx, song.instruments[idx].name)
    if app:save_instrument(tmp) then
      table.insert(STATE.exported_files, tmp)
    end
  end

  song.selected_instrument_index = saved_sel

  if #STATE.exported_files == 0 then
    app:show_warning("No se pudo exportar ningun instrumento.")
    STATE.phase = "loading_original"
    app:load_song(STATE.original_path)
    return
  end

  STATE.phase = "loading_original"
  app:load_song(STATE.original_path)
end

local function on_new_document()
  if STATE.phase == "loading_template" then
    select_and_export_instruments()
  elseif STATE.phase == "loading_original" then
    import_exported_instruments()
  end
end

local function start_import()
  local app = renoise.app()
  local song = renoise.song()

  if STATE.phase ~= "idle" then
    app:show_warning("Ya hay una importacion en curso. Espera a que termine.")
    return
  end

  if song.file_name == "" then
    app:show_warning(
      "Guarda tu cancion antes de usar esta herramienta.\n" ..
      "Usa Archivo -> Guardar Como..."
    )
    return
  end

  STATE.original_path = song.file_name
  app:save_song()

  local tpl = app:prompt_for_filename_to_read(
    { "xrns" },
    "Selecciona la cancion de plantilla"
  )

  if not tpl or tpl == "" then return end

  if tpl == STATE.original_path then
    app:show_warning("La plantilla no puede ser la misma cancion que estas editando.")
    return
  end

  STATE.template_path = tpl
  STATE.phase = "loading_template"
  app:load_song(tpl)
end

if not renoise.tool().app_new_document_observable:has_notifier(on_new_document) then
  renoise.tool().app_new_document_observable:add_notifier(on_new_document)
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Copy Instruments from Template Song...",
  invoke = start_import,
}
