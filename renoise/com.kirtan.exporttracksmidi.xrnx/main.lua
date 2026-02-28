--[[
MIT License

Copyright (c) 2026 ਕਿਰਤਨ ਤੇਗ ਸਿੰਘ

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

-- Mantra: raiz estable; modulos claros.
local tool_path = renoise.tool().bundle_path
if tool_path:sub(-1) ~= "/" and tool_path:sub(-1) ~= "\\" then
  tool_path = tool_path .. "/"
end

local export_logic = dofile(tool_path .. "export_logic.lua")
local ui_dialog = dofile(tool_path .. "ui_dialog.lua")
local tool = renoise.tool()
local idle_observable = tool.app_idle_observable

local MIDI_PPQ = 960
local PROGRESS_BAR_WIDTH = 30
local SPINNER_FRAMES = { "|", "/", "-", "\\" }

local progress_dialog = nil
local progress_vb = nil
local on_export_idle = nil

local export_state = {
  active = false,
  cancel_requested = false,
  song = nil,
  tracks = nil,
  output_dir = "",
  total = 0,
  current = 0,
  display_percent = 0,
  target_percent = 0,
  spinner_index = 1,
  status_text = "",
  result = nil
}

-- Mantra: resumen corto, accion inmediata.
local function show_export_result(result)
  local app = renoise.app()
  local ok_count = #result.exported_files
  local err_count = #result.errors

  local lines = {
    string.format("Exportacion MIDI completada: %d track(s).", ok_count),
    "Carpeta destino: " .. result.output_dir,
    "Resolucion MIDI (PPQ): " .. tostring(result.ppq)
  }

  if ok_count > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Archivos:"
    for i = 1, ok_count do
      lines[#lines + 1] = " - " .. result.exported_files[i]
    end
  end

  if err_count > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Errores:"
    for i = 1, err_count do
      lines[#lines + 1] = " - " .. result.errors[i]
    end
    app:show_error(table.concat(lines, "\n"))
    return
  end

  app:show_message(table.concat(lines, "\n"))
end

local function build_progress_bar(percent, width)
  local safe_percent = math.max(0, math.min(100, math.floor(percent + 0.5)))
  local filled = math.floor((safe_percent / 100) * width + 0.5)
  if filled > width then
    filled = width
  end
  return "[" .. string.rep("=", filled) .. string.rep(".", width - filled) .. "]"
end

local function stop_export_loop()
  if on_export_idle and idle_observable:has_notifier(on_export_idle) then
    idle_observable:remove_notifier(on_export_idle)
  end
end

local function close_progress_dialog()
  if progress_dialog and progress_dialog.visible then
    progress_dialog:close()
  end
  progress_dialog = nil
  progress_vb = nil
end

local function reset_export_state()
  export_state.active = false
  export_state.cancel_requested = false
  export_state.song = nil
  export_state.tracks = nil
  export_state.output_dir = ""
  export_state.total = 0
  export_state.current = 0
  export_state.display_percent = 0
  export_state.target_percent = 0
  export_state.spinner_index = 1
  export_state.status_text = ""
  export_state.result = nil
end

local function update_progress_ui()
  if not progress_vb or not progress_vb.views then
    return
  end

  local spinner = SPINNER_FRAMES[export_state.spinner_index]
  export_state.spinner_index = (export_state.spinner_index % #SPINNER_FRAMES) + 1

  local percent = math.max(0, math.min(100, math.floor(export_state.display_percent + 0.5)))
  local bar = build_progress_bar(percent, PROGRESS_BAR_WIDTH)

  if progress_vb.views.title_text then
    progress_vb.views.title_text.text = "Exportando MIDI " .. spinner
  end
  if progress_vb.views.bar_text then
    progress_vb.views.bar_text.text = string.format("%s %3d%%", bar, percent)
  end
  if progress_vb.views.status_text then
    progress_vb.views.status_text.text = export_state.status_text
  end
end

local function ensure_directory_writable(dir)
  local probe_path = dir
  if probe_path:sub(-1) ~= "/" and probe_path:sub(-1) ~= "\\" then
    probe_path = probe_path .. "/"
  end
  probe_path = probe_path .. string.format(".midi_export_probe_%d.tmp", os.time())

  local handle, err = io.open(probe_path, "wb")
  if not handle then
    return false, err or ("No se pudo escribir en: " .. tostring(dir))
  end
  handle:write("ok")
  handle:close()
  os.remove(probe_path)
  return true, nil
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]+$") or ""
end

local function default_output_dir(song)
  if song and song.file_name and song.file_name ~= "" then
    return dirname(song.file_name)
  end
  return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end

-- Mantra: primero elegir destino, luego elegir tracks.
local function prompt_output_dir(song)
  local app = renoise.app()
  local initial = default_output_dir(song)
  local chosen = nil

  if app.prompt_for_path then
    chosen = app:prompt_for_path("Selecciona carpeta destino para los MIDI")
  end

  if (not chosen or chosen == "") and app.prompt_for_filename_to_write then
    local file_path = app:prompt_for_filename_to_write(
      "mid",
      "SSD Externo: selecciona carpeta y un nombre temporal"
    )
    if file_path and file_path ~= "" then
      chosen = dirname(file_path)
    end
  end

  if not chosen or chosen == "" then
    return nil
  end

  chosen = tostring(chosen):gsub("^%s+", ""):gsub("%s+$", "")
  if chosen == "" then
    return initial
  end
  return chosen
end

local function is_external_volume_path(path)
  return type(path) == "string" and path:match("^/Volumes/") ~= nil
end

local function finalize_export(cancelled, fatal_err)
  local app = renoise.app()
  local result = export_state.result

  stop_export_loop()
  close_progress_dialog()
  reset_export_state()

  if fatal_err then
    app:show_error("Error interno durante la exportacion MIDI: " .. tostring(fatal_err))
    return
  end

  if cancelled then
    if result and #result.exported_files > 0 then
      app:show_message(
        "Exportacion cancelada por el usuario.\n" ..
        "Se exportaron " .. tostring(#result.exported_files) .. " track(s) antes de cancelar."
      )
    else
      app:show_status("Exportacion cancelada.")
    end
    return
  end

  if result then
    show_export_result(result)
  end
end

local function request_cancel_export()
  if not export_state.active then
    close_progress_dialog()
    return
  end
  export_state.cancel_requested = true
  export_state.status_text = "Cancelando exportacion..."
  update_progress_ui()
end

local function show_progress_dialog()
  close_progress_dialog()

  progress_vb = renoise.ViewBuilder()
  local content = progress_vb:column {
    margin = 10,
    spacing = 8,

    progress_vb:text {
      id = "title_text",
      text = "Exportando MIDI |",
      font = "bold"
    },
    progress_vb:text {
      id = "bar_text",
      text = build_progress_bar(0, PROGRESS_BAR_WIDTH) .. "   0%"
    },
    progress_vb:text {
      id = "status_text",
      text = "Preparando..."
    },
    progress_vb:row {
      spacing = 6,
      progress_vb:button {
        text = "Cancelar",
        width = 100,
        notifier = request_cancel_export
      }
    }
  }

  progress_dialog = renoise.app():show_custom_dialog(
    "Export Tracks to MIDI",
    content
  )
end

on_export_idle = function()
  local ok, run_err = pcall(function()
    if not export_state.active then
      stop_export_loop()
      return
    end

    if progress_dialog and not progress_dialog.visible then
      export_state.cancel_requested = true
    end

    if export_state.cancel_requested then
      finalize_export(true, nil)
      return
    end

    if export_state.display_percent < export_state.target_percent then
      export_state.display_percent = math.min(export_state.target_percent, export_state.display_percent + 2)
      update_progress_ui()
      return
    end

    if export_state.current >= export_state.total then
      export_state.target_percent = 100
      if export_state.display_percent < 100 then
        update_progress_ui()
        return
      end
      finalize_export(false, nil)
      return
    end

    local next_order = export_state.current + 1
    local track_index = export_state.tracks[next_order]
    local track = export_state.song.tracks[track_index]
    local track_name = (track and track.name) or ("Track " .. tostring(track_index))
    export_state.status_text = string.format("Procesando %d/%d: %s", next_order, export_state.total, track_name)
    update_progress_ui()

    local export_ok, output_path_or_err, err = pcall(
      export_logic.export_single_track,
      export_state.song,
      track_index,
      next_order,
      export_state.output_dir
    )

    if not export_ok then
      finalize_export(false, output_path_or_err)
      return
    end

    if output_path_or_err then
      export_state.result.exported_files[#export_state.result.exported_files + 1] = output_path_or_err
    else
      export_state.result.errors[#export_state.result.errors + 1] = err or "Error desconocido al exportar track."
    end

    export_state.current = next_order
    export_state.target_percent = math.floor((export_state.current / export_state.total) * 100 + 0.5)
    if export_state.target_percent > 100 then
      export_state.target_percent = 100
    end
    update_progress_ui()
  end)

  if not ok then
    finalize_export(false, run_err)
  end
end

local function start_export_job(song, selection, output_dir)
  local writable, writable_err = ensure_directory_writable(output_dir)
  if not writable then
    local msg =
      "Sin permisos de escritura en la carpeta destino:\n" ..
      tostring(output_dir) .. "\n\n" ..
      tostring(writable_err)

    if is_external_volume_path(output_dir) then
      msg = msg .. "\n\n" ..
        "Para SSD USB en macOS Sequoia:\n" ..
        "1) System Settings > Privacy & Security > Files and Folders > Renoise > Removable Volumes = ON\n" ..
        "2) Si sigue bloqueado: Privacy & Security > Full Disk Access > Renoise = ON\n" ..
        "3) En Finder valida que el volumen permita escritura (algunos NTFS son solo lectura)\n" ..
        "4) En la tool pulsa 'Autorizar SSD...' y vuelve a elegir carpeta."
    end

    renoise.app():show_error(msg)
    return
  end

  export_state.active = true
  export_state.cancel_requested = false
  export_state.song = song
  export_state.tracks = selection.track_indexes
  export_state.output_dir = output_dir
  export_state.total = #selection.track_indexes
  export_state.current = 0
  export_state.display_percent = 0
  export_state.target_percent = 0
  export_state.spinner_index = 1
  export_state.status_text = "Inicializando exportacion..."
  export_state.result = {
    output_dir = output_dir,
    ppq = MIDI_PPQ,
    exported_files = {},
    errors = {}
  }

  show_progress_dialog()
  update_progress_ui()
  if not idle_observable:has_notifier(on_export_idle) then
    idle_observable:add_notifier(on_export_idle)
  end
end

-- Mantra: valida primero; exporta despues.
local function run_export_tracks_to_midi()
  local app = renoise.app()
  local song = renoise.song()

  if export_state.active then
    app:show_status("Ya hay una exportacion MIDI en curso.")
    return
  end

  if not song then
    app:show_error("No hay una cancion abierta en Renoise.")
    return
  end

  local output_dir = prompt_output_dir(song)
  if not output_dir then
    app:show_status("Exportacion cancelada (sin carpeta destino).")
    return
  end

  local selection, select_err, cancelled = ui_dialog.prompt_track_selection(song)
  if cancelled then
    app:show_status("Exportacion cancelada.")
    return
  end
  if not selection then
    app:show_error(select_err or "No se pudo leer la seleccion de tracks.")
    return
  end

  app:show_status("Exportando tracks a MIDI...")
  start_export_job(song, selection, output_dir)
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Export Tracks to MIDI",
  invoke = run_export_tracks_to_midi
}

renoise.tool():add_keybinding {
  name = "Global:Tools:Export Tracks to MIDI",
  invoke = run_export_tracks_to_midi
}
