--==============================================================================
-- Pattern Line Balancer (API v6 Compatible)
--==============================================================================

local MIN_LINES = 1
local MAX_LINES = 512
local VISIBLE_ROWS = 5

local vb = renoise.ViewBuilder()
local dialog = nil

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function get_average_lines(patterns)
  local total = 0
  for _, p in ipairs(patterns) do
    total = total + p.number_of_lines
  end
  return (#patterns == 0) and 0 or (total / #patterns)
end

--------------------------------------------------------------------------------
-- Main Dialog
--------------------------------------------------------------------------------

local function show_dialog()

  if dialog and dialog.visible then
    dialog:show()
    return
  end

  local song = renoise.song()
  local patterns = song.patterns

  local mode = "A"
  local global_value = 64
  local pattern_settings = {}

  for i, pattern in ipairs(patterns) do
    pattern_settings[i] = {
      enabled = false,
      value = pattern.number_of_lines
    }
  end

  local function apply_mode_a()
    if global_value < MIN_LINES or global_value > MAX_LINES then
      renoise.app():show_warning("Valor inválido.")
      return
    end

    song:describe_undo("Uniform Pattern Lines")

    for _, p in ipairs(patterns) do
      p.number_of_lines = global_value
    end

    renoise.app():show_status("Patrones ajustados a " .. global_value)
  end

  local function apply_mode_b()

    song:describe_undo("Custom Pattern Lines")

    local count = 0

    for i, p in ipairs(patterns) do
      if pattern_settings[i].enabled then
        local val = pattern_settings[i].value
        if val >= MIN_LINES and val <= MAX_LINES then
          p.number_of_lines = val
          count = count + 1
        end
      end
    end

    renoise.app():show_status("Ajustados " .. count .. " patrones")
  end

  --------------------------------------------------------------------------------
  -- Pattern List (5 visible rows + scrollbar)
  --------------------------------------------------------------------------------

  local scroll_offset = 0
  local max_offset = math.max(0, #patterns - VISIBLE_ROWS)
  local current_indices = {}  -- 1-based pattern index for each visible row
  local row_controls = {}     -- { checkbox, text, valuebox } per row

  local function update_current_indices()
    for r = 1, VISIBLE_ROWS do
      current_indices[r] = scroll_offset + r
    end
  end

  local function refresh_visible_rows()
    for r = 1, VISIBLE_ROWS do
      local idx = current_indices[r]
      if idx <= #patterns then
        local pattern = patterns[idx]
        local name = (pattern.name ~= "") and pattern.name or string.format("Pattern %02X", idx - 1)
        row_controls[r].checkbox.value = pattern_settings[idx].enabled
        row_controls[r].checkbox.visible = true
        row_controls[r].text.text = name
        row_controls[r].text.visible = true
        row_controls[r].valuebox.value = pattern_settings[idx].value
        row_controls[r].valuebox.visible = true
      else
        row_controls[r].checkbox.visible = false
        row_controls[r].text.visible = false
        row_controls[r].valuebox.visible = false
      end
    end
  end

  local list_column = vb:column { spacing = 2 }

  for r = 1, VISIBLE_ROWS do
    local row_check = vb:checkbox {
      value = false,
      notifier = function(val)
        local idx = current_indices[r]
        if idx and idx <= #patterns then
          pattern_settings[idx].enabled = val
        end
      end
    }
    local row_text = vb:text { text = "", width = 200 }
    local row_value = vb:valuebox {
      value = 64,
      min = MIN_LINES,
      max = MAX_LINES,
      width = 70,
      notifier = function(val)
        local idx = current_indices[r]
        if idx and idx <= #patterns then
          pattern_settings[idx].value = val
        end
      end
    }
    row_controls[r] = { checkbox = row_check, text = row_text, valuebox = row_value }
    list_column:add_child(vb:row { spacing = 6, row_check, row_text, row_value })
  end

  update_current_indices()
  refresh_visible_rows()

  -- Solo crear la scrollbar si hay más de VISIBLE_ROWS patrones (max > min obligatorio en Renoise)
  local scroll_row
  if max_offset > 0 then
    local scrollbar = vb:scrollbar {
      value = 0,
      min = 0,
      max = max_offset,
      step = 1,
      pagestep = 1,
      size = { width = 18, height = 100 },
      notifier = function(val)
        scroll_offset = math.floor(val)
        update_current_indices()
        refresh_visible_rows()
      end
    }
    scroll_row = vb:row {
      vb:space { height = 4 },
      vb:text { text = "Desplazar (" .. #patterns .. " patrones):" },
      vb:space { width = 8 },
      scrollbar
    }
  else
    scroll_row = vb:space { height = 1 }
  end

  --------------------------------------------------------------------------------
  -- UI
  --------------------------------------------------------------------------------

  local content = vb:column {

    margin = 10,
    spacing = 8,

    vb:row {
      spacing = 10,
      vb:text { text = "Modo:" },
      vb:chooser {
        items = { "Modo A (Uniforme)", "Modo B (Individual)" },
        value = 1,
        notifier = function(val)
          mode = (val == 1) and "A" or "B"
        end
      }
    },

    vb:row {
      spacing = 6,

      vb:text { text = "Líneas Globales:" },

      vb:valuebox {
        value = global_value,
        min = MIN_LINES,
        max = MAX_LINES,
        width = 80,
        notifier = function(val)
          global_value = val
        end
      },

      vb:text {
        text = "Promedio: " ..
          math.ceil(get_average_lines(patterns))
      }
    },

    vb:space { height = 8 },

    vb:horizontal_aligner {
      mode = "center",
      vb:button {
        text = "Aplicar",
        width = 120,
        notifier = function()
          if mode == "A" then
            apply_mode_a()
          else
            apply_mode_b()
          end
        end
      }
    },

    vb:space { height = 10 },

    vb:column {
      style = "group",
      vb:text { text = "Modo B - Ajustes Individuales" },
      list_column,
      scroll_row
    }
  }

  dialog = renoise.app():show_custom_dialog(
    "Pattern Line Balancer",
    content
  )
end

--------------------------------------------------------------------------------
-- Tool Registration (MANDATORY for API v6)
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Pattern Line Balancer...",
  invoke = show_dialog
}
