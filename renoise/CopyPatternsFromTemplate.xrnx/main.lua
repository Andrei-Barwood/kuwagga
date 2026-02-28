-- Copy Patterns from Template Song
-- Renoise Tool (.xrnx)

local STATE = {
  phase = "idle", -- "idle" | "loading_template" | "loading_original"
  original_path = "",
  template_path = "",
  snapshot = nil,
}

local function reset_state()
  STATE.phase = "idle"
  STATE.original_path = ""
  STATE.template_path = ""
  STATE.snapshot = nil
end

local function capture_note_columns(line)
  local cols = {}
  for c = 1, #line.note_columns do
    local nc = line.note_columns[c]
    if not nc.is_empty then
      table.insert(cols, {
        index = c,
        note_string = nc.note_string,
        instrument_string = nc.instrument_string,
        volume_string = nc.volume_string,
        panning_string = nc.panning_string,
        delay_string = nc.delay_string,
        effect_number_string = nc.effect_number_string,
        effect_amount_string = nc.effect_amount_string,
      })
    end
  end
  return cols
end

local function capture_effect_columns(line)
  local cols = {}
  for c = 1, #line.effect_columns do
    local ec = line.effect_columns[c]
    if not ec.is_empty then
      table.insert(cols, {
        index = c,
        number_string = ec.number_string,
        amount_string = ec.amount_string,
      })
    end
  end
  return cols
end

local function capture_template_snapshot()
  local song = renoise.song()
  local snapshot = {
    sequencer_track_count = song.sequencer_track_count,
    patterns = {},
    pattern_lengths = {},
    sequence = {},
    max_note_cols_by_track = {},
    max_fx_cols_by_track = {},
  }

  for seq_idx = 1, #song.sequencer.pattern_sequence do
    snapshot.sequence[seq_idx] = song.sequencer.pattern_sequence[seq_idx]
  end

  for p_idx = 1, #song.patterns do
    local pattern = song.patterns[p_idx]
    snapshot.pattern_lengths[p_idx] = pattern.number_of_lines
    local pattern_data = {
      number_of_lines = pattern.number_of_lines,
      tracks = {},
    }

    for t_idx = 1, song.sequencer_track_count do
      local ptrack = pattern:track(t_idx)
      local track_data = { lines = {} }

      for l_idx = 1, pattern.number_of_lines do
        local line = ptrack:line(l_idx)
        if not line.is_empty then
          local note_cols = capture_note_columns(line)
          local fx_cols = capture_effect_columns(line)

          for _, nc in ipairs(note_cols) do
            local prev = snapshot.max_note_cols_by_track[t_idx] or 0
            if nc.index > prev then
              snapshot.max_note_cols_by_track[t_idx] = nc.index
            end
          end

          for _, ec in ipairs(fx_cols) do
            local prev = snapshot.max_fx_cols_by_track[t_idx] or 0
            if ec.index > prev then
              snapshot.max_fx_cols_by_track[t_idx] = ec.index
            end
          end

          track_data.lines[l_idx] = {
            note_columns = note_cols,
            effect_columns = fx_cols,
          }
        end
      end

      pattern_data.tracks[t_idx] = track_data
    end

    snapshot.patterns[p_idx] = pattern_data
  end

  return snapshot
end

local function ensure_track_count(song, target_tracks)
  local current = song.sequencer_track_count

  while current < target_tracks do
    local ok = pcall(function()
      song:insert_track_at(current + 1)
    end)
    if not ok then
      break
    end
    current = song.sequencer_track_count
  end
end

local function ensure_pattern_count(song, target_patterns)
  local current = #song.patterns

  while current < target_patterns do
    local ok = pcall(function()
      song:insert_pattern_at(current + 1)
    end)
    if not ok then
      break
    end
    current = #song.patterns
  end

  while current > target_patterns do
    local ok = pcall(function()
      song:delete_pattern_at(current)
    end)
    if not ok then
      break
    end
    current = #song.patterns
  end
end

local function ensure_pattern_at(song, pattern_index)
  while #song.patterns < pattern_index do
    local ok = pcall(function()
      song:insert_pattern_at(#song.patterns + 1)
    end)
    if not ok then
      break
    end
  end
  return song.patterns[pattern_index]
end

local function apply_snapshot_to_destination()
  local app = renoise.app()
  local song = renoise.song()
  local snapshot = STATE.snapshot

  if not snapshot then
    app:show_warning("No hay datos de plantilla para importar.")
    reset_state()
    return
  end

  if song.file_name ~= STATE.original_path then
    app:show_warning("Importacion cancelada: la cancion destino cambio durante el proceso.")
    reset_state()
    return
  end

  song:describe_undo("Copy Patterns from Template Song")

  ensure_track_count(song, snapshot.sequencer_track_count)
  ensure_pattern_count(song, #snapshot.patterns)

  for t_idx = 1, snapshot.sequencer_track_count do
    local track = song:track(t_idx)
    local ncols = snapshot.max_note_cols_by_track[t_idx] or 1
    local fxcols = snapshot.max_fx_cols_by_track[t_idx] or 1

    pcall(function()
      if track.visible_note_columns < ncols then
        track.visible_note_columns = ncols
      end
    end)
    pcall(function()
      if track.visible_effect_columns < fxcols then
        track.visible_effect_columns = fxcols
      end
    end)
  end

  for p_idx, pattern_data in ipairs(snapshot.patterns) do
    local pattern = ensure_pattern_at(song, p_idx)
    if pattern then
      pcall(function()
        pattern.number_of_lines = pattern_data.number_of_lines
      end)

      for t_idx = 1, snapshot.sequencer_track_count do
        local ptrack = pattern:track(t_idx)
        if ptrack then
          ptrack:clear()
        end

        local track_data = pattern_data.tracks[t_idx]
        if ptrack and track_data and track_data.lines then
          for l_idx, line_data in pairs(track_data.lines) do
            local line = ptrack:line(l_idx)

            for _, nc in ipairs(line_data.note_columns or {}) do
              local col = line.note_columns[nc.index]
              if col then
                col.note_string = nc.note_string
                col.instrument_string = nc.instrument_string
                col.volume_string = nc.volume_string
                col.panning_string = nc.panning_string
                col.delay_string = nc.delay_string
                col.effect_number_string = nc.effect_number_string
                col.effect_amount_string = nc.effect_amount_string
              end
            end

            for _, ec in ipairs(line_data.effect_columns or {}) do
              local col = line.effect_columns[ec.index]
              if col then
                col.number_string = ec.number_string
                col.amount_string = ec.amount_string
              end
            end
          end
        end
      end
    end
  end

  -- Reemplazar orden del secuenciador con el de la plantilla.
  pcall(function()
    song.sequencer.pattern_sequence = snapshot.sequence
  end)

  -- Forzar duracion de cada patron al final para mantener exactamente
  -- los lengths de la plantilla (ej: mezcla de 192 y 64 lineas).
  for p_idx, length in ipairs(snapshot.pattern_lengths or {}) do
    local pattern = ensure_pattern_at(song, p_idx)
    if pattern and length then
      pcall(function()
        pattern.number_of_lines = length
      end)
    end
  end

  app:show_status(
    string.format(
      "Patrones importados: %d | Duraciones aplicadas: %d | Orden de secuencia: %d pasos",
      #snapshot.patterns,
      #snapshot.pattern_lengths,
      #snapshot.sequence
    )
  )

  reset_state()
end

local function capture_template_and_return()
  local app = renoise.app()
  STATE.snapshot = capture_template_snapshot()

  if not STATE.snapshot or #STATE.snapshot.patterns == 0 then
    app:show_warning("La plantilla no contiene patrones para importar.")
    STATE.phase = "loading_original"
    app:load_song(STATE.original_path)
    return
  end

  STATE.phase = "loading_original"
  app:load_song(STATE.original_path)
end

local function on_new_document()
  local current_path = renoise.song().file_name or ""

  if STATE.phase == "loading_template" then
    if current_path == STATE.template_path then
      capture_template_and_return()
    elseif current_path ~= "" then
      renoise.app():show_warning("Importacion cancelada: no se pudo cargar la plantilla esperada.")
      reset_state()
    end
  elseif STATE.phase == "loading_original" then
    if current_path == STATE.original_path then
      apply_snapshot_to_destination()
    elseif current_path ~= "" then
      renoise.app():show_warning("Importacion cancelada: no se pudo volver a la cancion destino.")
      reset_state()
    end
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
      "Guarda tu cancion destino antes de usar esta herramienta.\n" ..
      "Usa Archivo -> Guardar Como..."
    )
    return
  end

  local template_path = app:prompt_for_filename_to_read(
    { "xrns" },
    "Selecciona la cancion plantilla para importar patrones"
  )

  if not template_path or template_path == "" then
    return
  end

  STATE.original_path = song.file_name
  app:save_song()

  if template_path == STATE.original_path then
    app:show_warning("La plantilla no puede ser la misma cancion que estas editando.")
    reset_state()
    return
  end

  STATE.template_path = template_path
  STATE.phase = "loading_template"
  app:load_song(template_path)
end

if not renoise.tool().app_new_document_observable:has_notifier(on_new_document) then
  renoise.tool().app_new_document_observable:add_notifier(on_new_document)
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Copy Patterns from Template Song...",
  invoke = start_import,
}
