local TARGET_SAMPLE_RATE = 44100
local TARGET_BIT_DEPTH = 24
local MP3_BITRATE = "320k"
local FFMPEG_BIN_OVERRIDE = "/opt/homebrew/bin/ffmpeg"

local FORMAT_CONFIG = {
  wav = {
    ext = "wav",
    tag = "wav",
    label = "WAV 44.1kHz / 24-bit"
  },
  flac = {
    ext = "flac",
    tag = "flac",
    label = "FLAC 44.1kHz / 24-bit"
  },
  mp3 = {
    ext = "mp3",
    tag = "mp3",
    label = "MP3 44.1kHz / 320kbps"
  }
}

local render_dialog = nil
local render_vb = nil
local dialog_format = "wav"

local render_state = {
  active = false,
  phase = "idle",
  cancel_requested = false,
  callback_called = false,
  callback_wait_ticks = 0,
  ffmpeg_bin = nil,
  tmp_wav = nil,
  final_path = nil,
  format_name = nil
}

local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

local function sanitize_filename(name)
  local cleaned = tostring(name or "")
  cleaned = cleaned:gsub("[\\/:*?\"<>|]", "_")
  cleaned = cleaned:gsub("%s+$", "")
  cleaned = cleaned:gsub("^%s+", "")
  if cleaned == "" then
    cleaned = "Untitled"
  end
  return cleaned
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]+$") or ""
end

local function basename_without_ext(path)
  local name = path:match("([^/\\]+)$") or path
  return name:gsub("%.[^.]+$", "")
end

local function join_path(dir, file)
  local sep = is_windows() and "\\" or "/"
  if dir == "" then
    return file
  end
  if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then
    return dir .. file
  end
  return dir .. sep .. file
end

local function next_available_path(path)
  if not file_exists(path) then
    return path
  end

  local base = path:gsub("%.[^.]+$", "")
  local ext = path:match("(%.[^.]+)$") or ""
  local i = 1
  while true do
    local candidate = string.format("%s_%d%s", base, i, ext)
    if not file_exists(candidate) then
      return candidate
    end
    i = i + 1
  end
end

local function ensure_extension(path, ext)
  local expected = "." .. ext:lower()
  if path:lower():sub(-#expected) == expected then
    return path
  end
  return path .. expected
end

local function run_shell(command)
  local ok, how, code = os.execute(command)

  if type(ok) == "number" then
    return ok == 0
  end

  if type(ok) == "boolean" then
    if ok then
      return true
    end
    if how == "exit" and code == 0 then
      return true
    end
    return false
  end

  return false
end

local function can_execute_ffmpeg(bin_path)
  if not bin_path or bin_path == "" then
    return false
  end

  local cmd
  if is_windows() then
    cmd = string.format("%s -version >nul 2>nul", shell_quote(bin_path))
  else
    cmd = string.format("%s -version >/dev/null 2>&1", shell_quote(bin_path))
  end

  return run_shell(cmd)
end

local function resolve_ffmpeg_bin()
  if FFMPEG_BIN_OVERRIDE ~= "" and can_execute_ffmpeg(FFMPEG_BIN_OVERRIDE) then
    return FFMPEG_BIN_OVERRIDE
  end

  local candidates
  if is_windows() then
    candidates = {
      os.getenv("FFMPEG_BIN"),
      "C:\\ffmpeg\\bin\\ffmpeg.exe",
      "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe"
    }
  else
    candidates = {
      os.getenv("FFMPEG_BIN"),
      "/opt/homebrew/bin/ffmpeg",
      "/usr/local/bin/ffmpeg",
      "/opt/local/bin/ffmpeg",
      "/usr/bin/ffmpeg"
    }
  end

  for _, path in ipairs(candidates) do
    if path and path ~= "" and can_execute_ffmpeg(path) then
      return path
    end
  end

  local cmd = is_windows() and "where ffmpeg 2>nul" or "command -v ffmpeg 2>/dev/null"
  local p = io.popen(cmd)
  if not p then
    return nil
  end

  local out = p:read("*a") or ""
  p:close()
  local found = out:match("([^\r\n]+)")
  if found and found ~= "" and can_execute_ffmpeg(found) then
    return found
  end

  return nil
end

local function get_format_config(format_name)
  return FORMAT_CONFIG[format_name] or FORMAT_CONFIG.wav
end

local function default_output_path_for_format(format_name)
  local cfg = get_format_config(format_name)
  local song = renoise.song()
  local song_file = song.file_name
  local output_dir
  local base_name

  if song_file ~= "" then
    output_dir = dirname(song_file)
    base_name = basename_without_ext(song_file)
  else
    output_dir = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
    base_name = sanitize_filename(song.name)
  end

  local final_name = string.format(
    "%s__432Hz_44k1_24b_%s.%s",
    sanitize_filename(base_name),
    cfg.tag,
    cfg.ext
  )

  local full_path = join_path(output_dir, final_name)
  return next_available_path(full_path)
end

local function build_tmp_render_path()
  local tmp_path = os.tmpname() .. "_renoise_render_440.wav"
  if is_windows() then
    tmp_path = tmp_path:gsub("/", "\\")
  end
  return tmp_path
end

local function cleanup_tmp_file(path)
  if path and path ~= "" and file_exists(path) then
    os.remove(path)
  end
end

local function build_ffmpeg_command(ffmpeg_bin, tmp_wav, final_path, format_name)
  local af = string.format(
    "asetrate=%d*432/440,aresample=%d,atempo=440/432",
    TARGET_SAMPLE_RATE,
    TARGET_SAMPLE_RATE
  )

  if format_name == "wav" then
    return string.format(
      "%s -hide_banner -loglevel error -y -i %s -af %s -ar %d -c:a pcm_s24le %s",
      shell_quote(ffmpeg_bin),
      shell_quote(tmp_wav),
      shell_quote(af),
      TARGET_SAMPLE_RATE,
      shell_quote(final_path)
    )
  end

  if format_name == "flac" then
    return string.format(
      "%s -hide_banner -loglevel error -y -i %s -af %s -ar %d -c:a flac -sample_fmt s32 -compression_level 8 %s",
      shell_quote(ffmpeg_bin),
      shell_quote(tmp_wav),
      shell_quote(af),
      TARGET_SAMPLE_RATE,
      shell_quote(final_path)
    )
  end

  if format_name == "mp3" then
    return string.format(
      "%s -hide_banner -loglevel error -y -i %s -af %s -ar %d -c:a libmp3lame -b:a %s -id3v2_version 3 -write_id3v1 1 -f mp3 %s",
      shell_quote(ffmpeg_bin),
      shell_quote(tmp_wav),
      shell_quote(af),
      TARGET_SAMPLE_RATE,
      MP3_BITRATE,
      shell_quote(final_path)
    )
  end

  return nil
end

local function convert_rendered_file(ffmpeg_bin, tmp_wav, final_path, format_name)
  local ffmpeg_cmd = build_ffmpeg_command(ffmpeg_bin, tmp_wav, final_path, format_name)
  if not ffmpeg_cmd then
    cleanup_tmp_file(tmp_wav)
    return false, "Formato no soportado: " .. tostring(format_name)
  end

  local wrapped_cmd
  if is_windows() then
    wrapped_cmd = ffmpeg_cmd .. " >nul 2>nul"
  else
    wrapped_cmd = ffmpeg_cmd .. " >/dev/null 2>&1"
  end

  local ok = run_shell(wrapped_cmd)
  cleanup_tmp_file(tmp_wav)

  if ok and file_exists(final_path) then
    return true, nil
  end

  return false, "ffmpeg falló usando ruta: " .. tostring(ffmpeg_bin)
end

local function set_dialog_status(text)
  if render_vb and render_vb.views and render_vb.views.status_text then
    render_vb.views.status_text.text = text
  end
end

local function update_dialog_controls()
  if not (render_vb and render_vb.views) then
    return
  end

  local is_rendering = render_state.active and render_state.phase == "rendering"
  local is_busy = render_state.active

  if render_vb.views.path_field then
    render_vb.views.path_field.active = not is_busy
  end
  if render_vb.views.browse_button then
    render_vb.views.browse_button.active = not is_busy
  end
  if render_vb.views.start_button then
    render_vb.views.start_button.active = not is_busy
  end
  if render_vb.views.cancel_button then
    render_vb.views.cancel_button.active = is_rendering
  end
end

local function reset_render_state()
  render_state.active = false
  render_state.phase = "idle"
  render_state.cancel_requested = false
  render_state.callback_called = false
  render_state.callback_wait_ticks = 0
  render_state.ffmpeg_bin = nil
  render_state.tmp_wav = nil
  render_state.final_path = nil
  render_state.format_name = nil
  update_dialog_controls()
end

local function format_label(format_name)
  return get_format_config(format_name).label
end

local function finish_success()
  local path = render_state.final_path
  local label = format_label(render_state.format_name)
  reset_render_state()
  set_dialog_status("Completado: " .. path)

  renoise.app():show_message(
    "Render 432Hz completado\n\n" ..
    "Archivo: " .. path .. "\n" ..
    "Formato: " .. label .. "\n" ..
    "Afinación: 440Hz -> 432Hz"
  )
end

local function finish_error(err_text)
  local tmp = render_state.tmp_wav
  reset_render_state()
  cleanup_tmp_file(tmp)
  set_dialog_status("Error durante el proceso.")
  renoise.app():show_error(err_text)
end

local function handle_render_stopped_without_callback()
  local was_cancel = render_state.cancel_requested
  local tmp = render_state.tmp_wav
  reset_render_state()
  cleanup_tmp_file(tmp)

  if was_cancel then
    set_dialog_status("Render cancelado por el usuario.")
    renoise.app():show_status("Render cancelado.")
  else
    set_dialog_status("Render detenido antes de completar.")
    renoise.app():show_error("El render se detuvo antes de completar.")
  end
end

local function on_app_idle()
  if not render_state.active then
    return
  end

  local song = renoise.song()
  if render_state.phase == "rendering" then
    if song.rendering then
      local percent = math.floor((song.rendering_progress or 0) * 100 + 0.5)
      set_dialog_status(string.format("Renderizando... %d%%", percent))
      return
    end

    if render_state.callback_called then
      return
    end

    render_state.callback_wait_ticks = render_state.callback_wait_ticks + 1
    if render_state.callback_wait_ticks < 10 then
      return
    end

    handle_render_stopped_without_callback()
  end
end

local function ensure_idle_notifier()
  local observable = renoise.tool().app_idle_observable
  if not observable:has_notifier(on_app_idle) then
    observable:add_notifier(on_app_idle)
  end
end

local function cancel_current_render()
  if render_state.active and render_state.phase == "rendering" and renoise.song().rendering then
    render_state.cancel_requested = true
    set_dialog_status("Cancelando render...")
    renoise.song():cancel_rendering()
    update_dialog_controls()
    return
  end

  if render_dialog and render_dialog.visible then
    render_dialog:close()
  end
end

local function start_render_from_dialog()
  if render_state.active or renoise.song().rendering then
    renoise.app():show_status("Ya hay un render en curso.")
    return
  end

  local cfg = get_format_config(dialog_format)
  local path = ""
  if render_vb and render_vb.views and render_vb.views.path_field then
    path = tostring(render_vb.views.path_field.text or "")
  end

  if path == "" then
    renoise.app():show_error("Selecciona una ruta de destino para el archivo exportado.")
    return
  end

  path = ensure_extension(path, cfg.ext)
  if render_vb and render_vb.views and render_vb.views.path_field then
    render_vb.views.path_field.text = path
  end

  local ffmpeg_bin = resolve_ffmpeg_bin()
  if not ffmpeg_bin then
    renoise.app():show_error(
      "No se encontró ffmpeg.\n\n" ..
      "Instala ffmpeg (macOS: brew install ffmpeg) o define FFMPEG_BIN.\n" ..
      "Rutas buscadas: /opt/homebrew/bin/ffmpeg, /usr/local/bin/ffmpeg, /opt/local/bin/ffmpeg, /usr/bin/ffmpeg."
    )
    return
  end

  local tmp_wav = build_tmp_render_path()
  local options = {
    sample_rate = TARGET_SAMPLE_RATE,
    bit_depth = TARGET_BIT_DEPTH,
    interpolation = "precise",
    priority = "high"
  }

  render_state.active = true
  render_state.phase = "rendering"
  render_state.cancel_requested = false
  render_state.callback_called = false
  render_state.callback_wait_ticks = 0
  render_state.ffmpeg_bin = ffmpeg_bin
  render_state.tmp_wav = tmp_wav
  render_state.final_path = path
  render_state.format_name = dialog_format

  update_dialog_controls()
  set_dialog_status("Iniciando render...")

  local ok, render_err = renoise.song():render(options, tmp_wav, function()
    render_state.callback_called = true
    render_state.phase = "converting"
    update_dialog_controls()
    set_dialog_status("Convirtiendo a 432Hz...")

    local conv_ok, conv_err = convert_rendered_file(
      render_state.ffmpeg_bin,
      render_state.tmp_wav,
      render_state.final_path,
      render_state.format_name
    )

    if conv_ok then
      finish_success()
    else
      finish_error("La conversión a 432Hz falló.\n" .. tostring(conv_err))
    end
  end)

  if not ok then
    reset_render_state()
    cleanup_tmp_file(tmp_wav)
    renoise.app():show_error("No se pudo iniciar el render: " .. tostring(render_err or "Error desconocido"))
    return
  end

  set_dialog_status("Render en curso...")
end

local function browse_output_destination()
  if render_state.active then
    return
  end

  local cfg = get_format_config(dialog_format)
  local suggested = ""
  if render_vb and render_vb.views and render_vb.views.path_field then
    suggested = tostring(render_vb.views.path_field.text or "")
  end

  local chosen = renoise.app():prompt_for_filename_to_write(cfg.ext, "Selecciona el archivo de destino")
  if chosen and chosen ~= "" then
    chosen = ensure_extension(chosen, cfg.ext)
    if render_vb and render_vb.views and render_vb.views.path_field then
      render_vb.views.path_field.text = chosen
    end
    set_dialog_status("Destino seleccionado.")
  elseif suggested ~= "" then
    set_dialog_status("Se mantiene el destino actual.")
  end
end

local function show_render_dialog(format_name)
  ensure_idle_notifier()

  if render_state.active then
    renoise.app():show_status("Ya hay un render en curso.")
    return
  end

  dialog_format = format_name
  local cfg = get_format_config(dialog_format)

  if render_dialog and render_dialog.visible then
    render_dialog:close()
  end

  render_vb = renoise.ViewBuilder()
  local initial_path = default_output_path_for_format(dialog_format)

  local content = render_vb:column {
    margin = 10,
    spacing = 8,

    render_vb:text {
      text = "Exportar 432Hz - " .. cfg.label
    },

    render_vb:row {
      spacing = 6,
      render_vb:textfield {
        id = "path_field",
        text = initial_path,
        width = 500
      },
      render_vb:button {
        id = "browse_button",
        text = "Destino...",
        width = 100,
        notifier = browse_output_destination
      }
    },

    render_vb:text {
      id = "status_text",
      text = "Listo para renderizar."
    },

    render_vb:row {
      spacing = 6,
      render_vb:button {
        id = "start_button",
        text = "Iniciar Render",
        width = 130,
        notifier = start_render_from_dialog
      },
      render_vb:button {
        id = "cancel_button",
        text = "Cancelar",
        width = 100,
        notifier = cancel_current_render
      }
    }
  }

  render_dialog = renoise.app():show_custom_dialog(
    "432Hz Renderer",
    content
  )

  update_dialog_controls()
  set_dialog_status("Selecciona destino y presiona Iniciar Render.")
end

local function open_dialog_for(format_name)
  return function()
    show_render_dialog(format_name)
  end
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:432Hz Renderer:Render Song to 432Hz (44.1k/24-bit)",
  invoke = open_dialog_for("wav")
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:432Hz Renderer:Render Song to 432Hz FLAC (44.1k/24-bit)",
  invoke = open_dialog_for("flac")
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:432Hz Renderer:Render Song to 432Hz MP3 (44.1k/320k)",
  invoke = open_dialog_for("mp3")
}

renoise.tool():add_keybinding {
  name = "Global:Tools:Render Song to 432Hz (44.1k/24-bit)",
  invoke = open_dialog_for("wav")
}

renoise.tool():add_keybinding {
  name = "Global:Tools:Render Song to 432Hz FLAC (44.1k/24-bit)",
  invoke = open_dialog_for("flac")
}

renoise.tool():add_keybinding {
  name = "Global:Tools:Render Song to 432Hz MP3 (44.1k/320k)",
  invoke = open_dialog_for("mp3")
}
