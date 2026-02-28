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

-- Mantra: solo datos exportables; solo tracks secuenciadoras.
local function collect_sequencer_tracks(song)
  local list = {}
  for index = 1, #song.tracks do
    local track = song.tracks[index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      list[#list + 1] = {
        index = index,
        name = track.name or ("Track " .. tostring(index))
      }
    end
  end
  return list
end

-- Mantra: acepta retorno de boton en texto o indice.
local function is_cancel_pressed(value)
  if value == "Cancelar" then
    return true
  end
  if value == 2 then
    return true
  end
  if type(value) == "string" and string.lower(value) == "cancelar" then
    return true
  end
  return false
end

-- Mantra: seleccion clara; flujo sin friccion.
function M.prompt_track_selection(song)
  if not song then
    return nil, "No hay una cancion abierta.", false
  end

  local tracks = collect_sequencer_tracks(song)
  if #tracks == 0 then
    return nil, "No hay tracks secuenciadoras para exportar.", false
  end

  local vb = renoise.ViewBuilder()
  local checks = {}
  local syncing = false
  local select_all

  -- Mantra: una intencion; muchas casillas.
  local function set_all(value)
    syncing = true
    for i = 1, #checks do
      checks[i].value = value
    end
    syncing = false
  end

  -- Mantra: estado global nace de estados locales.
  local function update_select_all_from_children()
    if syncing then
      return
    end

    local all_checked = true
    for i = 1, #checks do
      if not checks[i].value then
        all_checked = false
        break
      end
    end

    syncing = true
    select_all.value = all_checked
    syncing = false
  end

  select_all = vb:checkbox {
    value = true,
    notifier = function(value)
      if syncing then
        return
      end
      set_all(value)
    end
  }

  local root = vb:column {
    margin = 10,
    spacing = 6
  }

  root:add_child(vb:text {
    text = "Selecciona tracks para exportar a MIDI",
    font = "bold"
  })

  root:add_child(vb:text {
    text = "Solo se exportan notas y automatizaciones MIDI-relevantes."
  })

  root:add_child(vb:row {
    spacing = 6,
    select_all,
    vb:text {
      text = "Seleccionar Todo"
    }
  })

  root:add_child(vb:space { height = 4 })

  local list_column = vb:column { spacing = 4 }
  for i = 1, #tracks do
    local track_info = tracks[i]
    local cb = vb:checkbox {
      value = true,
      notifier = update_select_all_from_children
    }
    checks[#checks + 1] = cb

    list_column:add_child(vb:row {
      spacing = 6,
      cb,
      vb:text {
        text = string.format("[%02d] %s", track_info.index, track_info.name)
      }
    })
  end
  root:add_child(list_column)

  local pressed = renoise.app():show_custom_prompt(
    "Export Tracks to MIDI",
    root,
    { "Exportar", "Cancelar" }
  )

  if is_cancel_pressed(pressed) then
    return nil, nil, true
  end

  local selected = {}
  for i = 1, #checks do
    if checks[i].value then
      selected[#selected + 1] = tracks[i].index
    end
  end

  if #selected == 0 then
    return nil, "Debes seleccionar al menos una track.", false
  end

  return {
    track_indexes = selected
  }, nil, false
end

return M
