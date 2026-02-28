-- Copy Mix + Mixer FX from Template Song
-- Renoise Tool (.xrnx)

local STATE = {
  phase = "idle", -- "idle" | "loading_template" | "loading_original"
  original_path = "",
  template_path = "",
  selected_fx = {},
  template_track_names = {},
  template_mixer_state = nil,
}

local function reset_state()
  STATE.phase = "idle"
  STATE.original_path = ""
  STATE.template_path = ""
  STATE.selected_fx = {}
  STATE.template_track_names = {}
  STATE.template_mixer_state = nil
end

local function basename(path)
  return (path or ""):match("([^/\\]+)$") or (path or "")
end

local function is_effect_device(device)
  if not device then
    return false
  end
  -- En tracks, el primer device es Mixer/Sampler y no se copia como FX.
  return device.name ~= "Mixer" and device.name ~= "Sampler"
end

local function get_master_track(song)
  if not song then
    return nil
  end

  -- En versiones modernas de la API, master suele ser el ultimo track global.
  local ok_tracks, tracks = pcall(function()
    return song.tracks
  end)
  if ok_tracks and tracks and #tracks > 0 then
    return tracks[#tracks]
  end

  -- Fallback por indices para APIs viejas o contextos limitados.
  local send_count = song.send_track_count or 0
  local master_index = song.sequencer_track_count + send_count + 1

  local ok_master, master_track = pcall(function()
    return song:track(master_index)
  end)
  if ok_master and master_track then
    return master_track
  end

  local ok_fallback, fallback_track = pcall(function()
    return song:track(song.sequencer_track_count + 1)
  end)
  if ok_fallback and fallback_track then
    return fallback_track
  end

  return nil
end

local function collect_template_fx()
  local song = renoise.song()
  local items = {}

  for t_idx = 1, song.sequencer_track_count do
    local track = song:track(t_idx)
    for d_idx, device in ipairs(track.devices) do
      if d_idx > 1 and is_effect_device(device) then
        table.insert(items, {
          track_kind = "sequencer",
          track_index = t_idx,
          track_name = track.name,
          device_index = d_idx,
          device_name = device.display_name ~= "" and device.display_name or device.name,
          device_path = device.device_path,
          preset_data = device.active_preset_data,
          is_active = device.is_active,
        })
      end
    end
  end

  -- Incluir cadena de FX del Master.
  local master_track = get_master_track(song)
  if master_track then
    for d_idx, device in ipairs(master_track.devices) do
      if d_idx > 1 and is_effect_device(device) then
        table.insert(items, {
          track_kind = "master",
          track_index = 0,
          track_name = "MASTER",
          device_index = d_idx,
          device_name = device.display_name ~= "" and device.display_name or device.name,
          device_path = device.device_path,
          preset_data = device.active_preset_data,
          is_active = device.is_active,
        })
      end
    end
  end

  return items
end

local function collect_template_track_names()
  local song = renoise.song()
  local names = {}

  for t_idx = 1, song.sequencer_track_count do
    local track = song:track(t_idx)
    names[t_idx] = track.name
  end

  return names
end

local function collect_template_mixer_state()
  local song = renoise.song()
  local state = {
    sequencer = {},
    master = nil,
  }

  for t_idx = 1, song.sequencer_track_count do
    local track = song:track(t_idx)
    local mixer_device = track.devices[1]

    state.sequencer[t_idx] = {
      preset_data = mixer_device and mixer_device.active_preset_data or nil,
      is_active = mixer_device and mixer_device.is_active or true,
    }
  end

  local master_track = get_master_track(song)
  if master_track then
    local master_mixer = master_track.devices[1]
    state.master = {
      preset_data = master_mixer and master_mixer.active_preset_data or nil,
      is_active = master_mixer and master_mixer.is_active or true,
    }
  end

  return state
end

local function clear_track_content(song, track_index)
  local track = song:track(track_index)

  -- Limpiar notas/comandos en todos los patrones del track.
  for p_idx = 1, #song.patterns do
    local ok_pattern, pattern = pcall(function()
      return song.patterns[p_idx]
    end)
    if ok_pattern and pattern and pattern.tracks and pattern.tracks[track_index] then
      pcall(function()
        pattern.tracks[track_index]:clear()
      end)
    end
  end

  -- Eliminar todos los FX existentes, dejando solo el device base (mixer/sampler).
  for d_idx = #track.devices, 2, -1 do
    pcall(function()
      track:delete_device_at(d_idx)
    end)
  end
end

local function prepare_destination_tracks(song)
  local target_count = #STATE.template_track_names
  if target_count < 1 then
    target_count = 1
    STATE.template_track_names[1] = "Track 01"
  end

  local current_count = song.sequencer_track_count

  -- Ajustar cantidad de tracks secuenciables para que coincida con plantilla.
  while current_count < target_count do
    local ok = pcall(function()
      song:insert_track_at(current_count + 1)
    end)
    if not ok then
      break
    end
    current_count = song.sequencer_track_count
  end

  while current_count > target_count do
    local ok = pcall(function()
      song:delete_track_at(current_count)
    end)
    if not ok then
      break
    end
    current_count = song.sequencer_track_count
  end

  -- Reemplazar contenido y nombres de tracks destino.
  local final_count = math.min(song.sequencer_track_count, target_count)
  for t_idx = 1, final_count do
    local track = song:track(t_idx)
    track.name = STATE.template_track_names[t_idx] or track.name
    clear_track_content(song, t_idx)
  end

  -- Limpiar FX del master destino (sin tocar su contenido global).
  local master_track = get_master_track(song)
  if master_track then
    for d_idx = #master_track.devices, 2, -1 do
      pcall(function()
        master_track:delete_device_at(d_idx)
      end)
    end
  end
end

local function show_fx_selection_dialog(items)
  local app = renoise.app()
  local vb = renoise.ViewBuilder()
  local checks = {}
  local root = vb:column { margin = 10, spacing = 3 }

  root:add_child(vb:text {
    text = "Plantilla: " .. basename(STATE.template_path),
    font = "bold",
  })
  root:add_child(vb:text {
    text = string.format("%d efecto(s) encontrado(s) en el mixer:", #items),
  })
  root:add_child(vb:space { height = 6 })

  local toggle_all = vb:checkbox {
    value = true,
    notifier = function(v)
      for _, cb in ipairs(checks) do
        cb.value = v
      end
    end,
  }

  root:add_child(vb:row {
    spacing = 5,
    toggle_all,
    vb:text { text = "Seleccionar / deseleccionar todos", font = "italic" },
  })
  root:add_child(vb:space { height = 4 })

  for i, item in ipairs(items) do
    local cb = vb:checkbox { value = true }
    checks[i] = cb
    local track_label = item.track_kind == "master"
      and "MASTER"
      or string.format("[%02d] %s", item.track_index, item.track_name)
    root:add_child(vb:row {
      spacing = 5,
      cb,
      vb:text {
        text = string.format("%s -> %s", track_label, item.device_name),
      },
    })
  end

  local answer = app:show_custom_prompt(
    "Importar Efectos del Mixer desde Plantilla",
    root,
    { "Importar seleccionados", "Cancelar" }
  )

  if answer == "Cancelar" then
    return nil
  end

  local selected = {}
  for i, cb in ipairs(checks) do
    if cb.value then
      table.insert(selected, items[i])
    end
  end

  return selected
end

local function import_mixer_settings(song)
  local imported = 0
  local skipped = 0
  local state = STATE.template_mixer_state

  if not state then
    return imported, skipped
  end

  local max_tracks = math.min(song.sequencer_track_count, #state.sequencer)
  for t_idx = 1, max_tracks do
    local track = song:track(t_idx)
    local mixer_device = track and track.devices and track.devices[1]
    local src = state.sequencer[t_idx]

    if mixer_device and src and src.preset_data then
      local ok = pcall(function()
        mixer_device.active_preset_data = src.preset_data
      end)
      if ok then
        imported = imported + 1
      else
        skipped = skipped + 1
      end

      pcall(function()
        mixer_device.is_active = src.is_active
      end)
    else
      skipped = skipped + 1
    end
  end

  if state.master then
    local master_track = get_master_track(song)
    local master_mixer = master_track and master_track.devices and master_track.devices[1]

    if master_mixer and state.master.preset_data then
      local ok = pcall(function()
        master_mixer.active_preset_data = state.master.preset_data
      end)
      if ok then
        imported = imported + 1
      else
        skipped = skipped + 1
      end

      pcall(function()
        master_mixer.is_active = state.master.is_active
      end)
    elseif state.master.preset_data then
      skipped = skipped + 1
    end
  end

  return imported, skipped
end

local function import_selected_fx()
  local app = renoise.app()
  local song = renoise.song()
  local imported = 0
  local skipped = 0

  if song.file_name ~= STATE.original_path then
    app:show_warning("Importacion cancelada: la cancion destino cambio durante el proceso.")
    reset_state()
    return
  end

  song:describe_undo("Import Mix and Mixer FX from Template Song")
  prepare_destination_tracks(song)

  local mixer_imported, mixer_skipped = import_mixer_settings(song)

  for _, fx in ipairs(STATE.selected_fx) do
    local track = nil
    if fx.track_kind == "master" then
      track = get_master_track(song)
    elseif fx.track_index <= song.sequencer_track_count then
      track = song:track(fx.track_index)
    end

    if not track then
      skipped = skipped + 1
    else
      local insert_at = #track.devices + 1
      local ok_insert = pcall(function()
        track:insert_device_at(fx.device_path, insert_at)
      end)

      if ok_insert then
        local new_device = track.devices[insert_at]
        if new_device then
          -- active_preset_data clona el estado completo del device/plugin cuando es posible.
          pcall(function()
            new_device.active_preset_data = fx.preset_data
          end)
          pcall(function()
            new_device.is_active = fx.is_active
          end)
          imported = imported + 1
        else
          skipped = skipped + 1
        end
      else
        skipped = skipped + 1
      end
    end
  end

  local msg = string.format(
    "Mezcla importada en %d canal(es) | FX importados: %d",
    mixer_imported,
    imported
  )

  if mixer_skipped > 0 then
    msg = msg .. string.format(" | Omitidos mezcla: %d", mixer_skipped)
  end

  if skipped > 0 then
    msg = msg .. string.format(" | Omitidos FX: %d", skipped)
  end

  app:show_status(msg)

  reset_state()
end

local function select_and_prepare_fx()
  local app = renoise.app()
  local items = collect_template_fx()
  STATE.template_track_names = collect_template_track_names()
  STATE.template_mixer_state = collect_template_mixer_state()

  if #items == 0 then
    app:show_status("La plantilla no tiene FX. Se importara solo la mezcla (faders/mixer).")
    STATE.selected_fx = {}
    STATE.phase = "loading_original"
    renoise.app():load_song(STATE.original_path)
    return
  end

  local selected = show_fx_selection_dialog(items)
  if not selected then
    STATE.phase = "loading_original"
    renoise.app():load_song(STATE.original_path)
    return
  end

  STATE.selected_fx = selected

  if #STATE.selected_fx == 0 then
    app:show_status("No seleccionaste FX. Se importara solo la mezcla (faders/mixer).")
  end

  STATE.phase = "loading_original"
  app:load_song(STATE.original_path)
end

local function on_new_document()
  local current_path = renoise.song().file_name or ""

  if STATE.phase == "loading_template" then
    if current_path == STATE.template_path then
      select_and_prepare_fx()
    elseif current_path ~= "" then
      renoise.app():show_warning("Importacion cancelada: no se pudo cargar la plantilla esperada.")
      reset_state()
    end
  elseif STATE.phase == "loading_original" then
    if current_path == STATE.original_path then
      import_selected_fx()
    elseif current_path ~= "" then
      renoise.app():show_warning("Importacion cancelada: no se pudo volver a la cancion destino.")
      reset_state()
    end
  end
end

local function start_import_with_template_path(template_path, opts)
  local app = renoise.app()
  local song = renoise.song()
  opts = opts or {}

  if STATE.phase ~= "idle" then
    if not opts.silent then
      app:show_warning("Ya hay una importacion en curso. Espera a que termine.")
    end
    return false
  end

  if song.file_name == "" then
    if not opts.silent then
      app:show_warning(
        "Guarda tu cancion destino antes de usar esta herramienta.\n" ..
        "Usa Archivo -> Guardar Como..."
      )
    end
    return false
  end

  if not template_path or template_path == "" then
    return false
  end

  STATE.original_path = song.file_name
  app:save_song()

  if template_path == STATE.original_path then
    if not opts.silent then
      app:show_warning("La plantilla no puede ser la misma cancion que estas editando.")
    end
    reset_state()
    return false
  end

  STATE.template_path = template_path
  STATE.phase = "loading_template"
  app:load_song(template_path)
  return true
end

local function start_import_prompt()
  local app = renoise.app()
  local template_path = app:prompt_for_filename_to_read(
    { "xrns" },
    "Selecciona la cancion plantilla para importar mezcla y mixer FX"
  )
  start_import_with_template_path(template_path)
end

if not renoise.tool().app_new_document_observable:has_notifier(on_new_document) then
  renoise.tool().app_new_document_observable:add_notifier(on_new_document)
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Import Mix + Mixer FX from Template Song...",
  invoke = start_import_prompt,
}
