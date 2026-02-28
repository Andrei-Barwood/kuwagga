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

local M = {}

local MIDI_PPQ = 960
local MIDI_CHANNEL = 0
local DEFAULT_VELOCITY = 100
local NOTE_ON_STATUS = 0x90 + MIDI_CHANNEL
local NOTE_OFF_STATUS = 0x80 + MIDI_CHANNEL
local CC_STATUS = 0xB0 + MIDI_CHANNEL

-- Mantra: limites firmes, datos limpios.
local function clamp_int(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end

-- Mantra: rutas estables en cualquier plataforma.
local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function join_path(dir, file_name)
  if dir == "" then
    return file_name
  end
  local sep = is_windows() and "\\" or "/"
  if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then
    return dir .. file_name
  end
  return dir .. sep .. file_name
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]+$") or ""
end

-- Mantra: nombre seguro, exportacion tranquila.
local function sanitize_filename(name)
  local clean = tostring(name or "")
  clean = clean:gsub("[\\/:*?\"<>|]", "_")
  clean = clean:gsub("[%c]", "_")
  clean = clean:gsub("^%s+", "")
  clean = clean:gsub("%s+$", "")
  clean = clean:gsub("%s+", "_")
  clean = clean:gsub("_+", "_")
  if clean == "" then
    clean = "Track"
  end
  return clean
end

local function file_exists(path)
  local handle = io.open(path, "rb")
  if handle then
    handle:close()
    return true
  end
  return false
end

local function next_available_path(path)
  if not file_exists(path) then
    return path
  end

  local base = path:gsub("%.mid$", "")
  local ext = ".mid"
  local suffix = 1
  while true do
    local candidate = string.format("%s_%02d%s", base, suffix, ext)
    if not file_exists(candidate) then
      return candidate
    end
    suffix = suffix + 1
  end
end

-- Mantra: primero guardar cerca del .xrns, luego fallback al HOME.
local function resolve_output_dir(song)
  if song.file_name and song.file_name ~= "" then
    return dirname(song.file_name)
  end

  return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end

-- Mantra: sin permiso no hay exportacion segura.
local function ensure_directory_writable(dir)
  local probe_name = string.format(".midi_export_probe_%d.tmp", os.time())
  local probe_path = join_path(dir, probe_name)
  local handle, err = io.open(probe_path, "wb")
  if not handle then
    return false, err or ("No se pudo escribir en: " .. tostring(dir))
  end
  handle:write("ok")
  handle:close()
  os.remove(probe_path)
  return true, nil
end

-- Mantra: bytes exactos, archivo valido.
local function u16be(value)
  local hi = math.floor(value / 256) % 256
  local lo = value % 256
  return string.char(hi, lo)
end

local function u24be(value)
  local b1 = math.floor(value / 65536) % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = value % 256
  return string.char(b1, b2, b3)
end

local function u32be(value)
  local b1 = math.floor(value / 16777216) % 256
  local b2 = math.floor(value / 65536) % 256
  local b3 = math.floor(value / 256) % 256
  local b4 = value % 256
  return string.char(b1, b2, b3, b4)
end

local function encode_vlq(value)
  local v = math.max(0, math.floor(value + 0.5))
  local bytes = { v % 128 }
  v = math.floor(v / 128)
  while v > 0 do
    table.insert(bytes, 1, (v % 128) + 128)
    v = math.floor(v / 128)
  end

  local chars = {}
  for i = 1, #bytes do
    chars[i] = string.char(bytes[i])
  end
  return table.concat(chars)
end

-- Mantra: velocidad MIDI valida para no perder energia ritmica.
local function extract_velocity(note_column)
  local velocity = note_column.volume_value
  if type(velocity) == "number" and velocity >= 0 and velocity <= 127 then
    return clamp_int(velocity, 1, 127)
  end
  return DEFAULT_VELOCITY
end

-- Mantra: automatizacion util, no ruido.
local function find_parameter_by_hints(track, hints)
  local mixer_device = track.devices and track.devices[1]
  if not mixer_device or not mixer_device.parameters then
    return nil
  end

  for _, parameter in ipairs(mixer_device.parameters) do
    local name = string.lower(parameter.name or "")
    for i = 1, #hints do
      if name:find(hints[i], 1, true) then
        return parameter
      end
    end
  end
  return nil
end

local function collect_automation_targets(track)
  local targets = {}
  local specs = {
    { cc = 7, hints = { "vol" } },
    { cc = 10, hints = { "pan" } },
    { cc = 8, hints = { "width", "stereo" } }
  }

  for i = 1, #specs do
    local spec = specs[i]
    local parameter = find_parameter_by_hints(track, spec.hints)
    if parameter then
      targets[#targets + 1] = {
        cc = spec.cc,
        parameter = parameter
      }
    end
  end

  return targets
end

-- Mantra: cada evento en su tick; ningun evento sin destino.
local function collect_track_events(song, track_index)
  local track = song.tracks[track_index]
  local sequence = song.sequencer.pattern_sequence
  local lpb = math.max(1, song.transport.lpb or 4)
  local ticks_per_line = MIDI_PPQ / lpb
  local automation_targets = collect_automation_targets(track)

  local events = {}
  local event_order = 0
  local active_by_column = {}
  local timeline_tick = 0.0

  local function push_event(tick, kind, data1, data2, priority)
    event_order = event_order + 1
    events[#events + 1] = {
      tick = math.max(0, math.floor(tick + 0.5)),
      kind = kind,
      data1 = data1,
      data2 = data2,
      priority = priority or 10,
      order = event_order
    }
  end

  for seq_pos = 1, #sequence do
    local pattern_index = sequence[seq_pos]
    local pattern = song.patterns[pattern_index]
    local pattern_track = pattern:track(track_index)
    local lines = pattern.number_of_lines
    local visible_columns = math.max(1, track.visible_note_columns or 1)

    for line_index = 1, lines do
      local line = pattern_track:line(line_index)
      if not line.is_empty then
        local line_tick = timeline_tick + ((line_index - 1) * ticks_per_line)
        for column = 1, visible_columns do
          local note_column = line.note_columns[column]
          local note_value = note_column.note_value

          if note_value >= 0 and note_value <= 119 then
            local delayed_tick = line_tick + ((note_column.delay_value or 0) / 256.0) * ticks_per_line
            local note_tick = math.floor(delayed_tick + 0.5)
            local previous = active_by_column[column]
            if previous then
              local off_tick = math.max(previous.start_tick, note_tick)
              push_event(off_tick, "note_off", previous.pitch, 0, 1)
            end

            local velocity = extract_velocity(note_column)
            active_by_column[column] = {
              pitch = note_value,
              start_tick = note_tick
            }
            push_event(note_tick, "note_on", note_value, velocity, 3)

          elseif note_value == 120 then
            local previous = active_by_column[column]
            if previous then
              local delayed_tick = line_tick + ((note_column.delay_value or 0) / 256.0) * ticks_per_line
              local off_tick = math.floor(delayed_tick + 0.5)
              off_tick = math.max(previous.start_tick, off_tick)
              push_event(off_tick, "note_off", previous.pitch, 0, 1)
              active_by_column[column] = nil
            end
          end
        end
      end
    end

    if #automation_targets > 0 then
      for i = 1, #automation_targets do
        local target = automation_targets[i]
        local automation = pattern_track:find_automation(target.parameter)
        if automation then
          for _, point in ipairs(automation.points) do
            local point_tick = timeline_tick + ((point.time - 1) * ticks_per_line)
            local cc_value = clamp_int(math.floor((point.value * 127) + 0.5), 0, 127)
            push_event(point_tick, "cc", target.cc, cc_value, 2)
          end
        end
      end
    end

    timeline_tick = timeline_tick + (lines * ticks_per_line)
  end

  local end_tick = math.max(0, math.floor(timeline_tick + 0.5))
  for _, active_note in pairs(active_by_column) do
    local off_tick = end_tick
    if off_tick <= active_note.start_tick then
      off_tick = active_note.start_tick + 1
    end
    push_event(off_tick, "note_off", active_note.pitch, 0, 1)
  end

  table.sort(events, function(a, b)
    if a.tick ~= b.tick then
      return a.tick < b.tick
    end
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.order < b.order
  end)

  return events
end

-- Mantra: estructura MIDI firme; reproduccion confiable.
local function build_midi_bytes(track_name, bpm, events)
  local chunks = {}
  local previous_tick = 0

  local safe_name = tostring(track_name or "Track")
  safe_name = safe_name:gsub("[\r\n]", " ")

  local tempo_mpqn = math.floor((60000000 / math.max(1, bpm or 125)) + 0.5)
  tempo_mpqn = clamp_int(tempo_mpqn, 1, 16777215)

  chunks[#chunks + 1] = encode_vlq(0)
  chunks[#chunks + 1] = string.char(0xFF, 0x03)
  chunks[#chunks + 1] = encode_vlq(#safe_name)
  chunks[#chunks + 1] = safe_name

  chunks[#chunks + 1] = encode_vlq(0)
  chunks[#chunks + 1] = string.char(0xFF, 0x51, 0x03)
  chunks[#chunks + 1] = u24be(tempo_mpqn)

  for i = 1, #events do
    local event = events[i]
    local delta = event.tick - previous_tick
    if delta < 0 then
      delta = 0
    end
    chunks[#chunks + 1] = encode_vlq(delta)

    if event.kind == "note_on" then
      chunks[#chunks + 1] = string.char(
        NOTE_ON_STATUS,
        clamp_int(event.data1, 0, 127),
        clamp_int(event.data2, 0, 127)
      )
    elseif event.kind == "note_off" then
      chunks[#chunks + 1] = string.char(
        NOTE_OFF_STATUS,
        clamp_int(event.data1, 0, 127),
        clamp_int(event.data2, 0, 127)
      )
    elseif event.kind == "cc" then
      chunks[#chunks + 1] = string.char(
        CC_STATUS,
        clamp_int(event.data1, 0, 127),
        clamp_int(event.data2, 0, 127)
      )
    end

    previous_tick = event.tick
  end

  chunks[#chunks + 1] = encode_vlq(0)
  chunks[#chunks + 1] = string.char(0xFF, 0x2F, 0x00)

  local track_data = table.concat(chunks)
  local header = "MThd" .. u32be(6) .. u16be(0) .. u16be(1) .. u16be(MIDI_PPQ)
  local track_chunk = "MTrk" .. u32be(#track_data) .. track_data
  return header .. track_chunk
end

local function write_binary_file(path, data)
  local handle, err = io.open(path, "wb")
  if not handle then
    return false, err or "No se pudo abrir archivo para escritura."
  end
  handle:write(data)
  handle:close()
  return true, nil
end

-- Mantra: orden visible; flujo rapido hacia Musescore.
local function build_ordered_filename(export_order, track_name)
  local clean_name = sanitize_filename(track_name)
  return string.format("%02d_%s.mid", export_order, clean_name)
end

-- Mantra: una track, una salida; resultado determinista.
function M.export_single_track(song, track_index, export_order, output_dir)
  if not song then
    return nil, "No hay una cancion abierta."
  end

  local track = song.tracks[track_index]
  if not track then
    return nil, string.format("Track %d no existe.", track_index)
  end
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    return nil, string.format("Track %d no es secuenciadora.", track_index)
  end

  local file_name = build_ordered_filename(export_order, track.name)
  local output_path = next_available_path(join_path(output_dir, file_name))
  local bpm = song.transport.bpm or 125
  local events = collect_track_events(song, track_index)
  local midi_bytes = build_midi_bytes(track.name, bpm, events)
  local ok, write_err = write_binary_file(output_path, midi_bytes)
  if not ok then
    return nil, string.format(
      "Track %d (%s): %s",
      track_index,
      tostring(track.name),
      tostring(write_err)
    )
  end

  return output_path, nil
end

-- Mantra: una pasada por track; cero bloqueos innecesarios.
function M.export_selected_tracks(song, selected_tracks, custom_output_dir)
  if not song then
    return nil, "No hay una cancion abierta."
  end
  if type(selected_tracks) ~= "table" or #selected_tracks == 0 then
    return nil, "No hay tracks seleccionadas para exportar."
  end

  local output_dir = tostring(custom_output_dir or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if output_dir == "" then
    output_dir = resolve_output_dir(song)
  end

  local writable, writable_err = ensure_directory_writable(output_dir)
  if not writable then
    return nil, "Sin permisos de escritura en: " .. tostring(output_dir) .. " (" .. tostring(writable_err) .. ")"
  end

  local result = {
    output_dir = output_dir,
    ppq = MIDI_PPQ,
    exported_files = {},
    errors = {}
  }

  for i = 1, #selected_tracks do
    local track_index = selected_tracks[i]
    local output_path, single_err = M.export_single_track(song, track_index, i, output_dir)
    if output_path then
      result.exported_files[#result.exported_files + 1] = output_path
    else
      result.errors[#result.errors + 1] = single_err
    end
  end

  if #result.exported_files == 0 then
    return nil, "No se pudo exportar ninguna track."
  end

  return result, nil
end

return M
