--[[============================================================================
  moon eyes for karen - Renoise Tool
  Generates predefined "mapas" (pattern sequences) with optional coloring/naming.

  Source maps: Airport.rtf (Mega Doll / renoise)

  Color for "terror" / "phantoms" (back2back only): #AEF504 -> RGB {0xAE, 0xF5, 0x04}

  NOTE ON PATTERN INDICES
  -----------------------
  Map tables use UI numbers (0-based) as shown in the Pattern Sequencer.
  Renoise API uses 1-based indices (UI 00 <-> patterns[1]).
============================================================================]]--

local TOOL_NAME = "moon eyes for karen"
local TOOL_VERSION = "1.1.6"
-- Submenu label under Tools / Pattern Sequencer / Pattern Matrix
local MENU_FOLDER = "moon eyes for karen"

local GREEN_R, GREEN_G, GREEN_B = 0xAE, 0xF5, 0x04  -- #AEF504

--------------------------------------------------------------------------------
-- Helpers: UI (0-based) <-> API (1-based)
--------------------------------------------------------------------------------
local function ui_to_api(ui_pattern)
  return ui_pattern + 1
end

local function copy_green()
  return {GREEN_R, GREEN_G, GREEN_B}
end

--------------------------------------------------------------------------------
-- Build a map from a plain list of UI pattern numbers:
--   numbers_to_map({0, 1, 2}) -> {{pattern=0},{pattern=1},{pattern=2}}
--------------------------------------------------------------------------------
local function numbers_to_map(numbers)
  local map = {}
  for _, n in ipairs(numbers) do
    table.insert(map, {pattern = n})
  end
  return map
end

--------------------------------------------------------------------------------
-- Ensure enough patterns exist in the song pool
--------------------------------------------------------------------------------
local function ensure_patterns_exist(max_ui_pattern)
  local song = renoise.song()
  local sequencer = song.sequencer
  local needed = ui_to_api(max_ui_pattern)

  while #song.patterns < needed do
    sequencer:insert_new_pattern_at(#sequencer.pattern_sequence + 1)
  end
end

--------------------------------------------------------------------------------
-- Set pattern name (ui_pattern is 0-based UI number)
--------------------------------------------------------------------------------
local function set_pattern_name(ui_pattern, name)
  local pat = renoise.song():pattern(ui_to_api(ui_pattern))
  if pat then
    pat.name = name
  end
end

--------------------------------------------------------------------------------
-- Set custom color on ALL tracks of a pattern (Pattern Matrix slots)
-- color_rgb = {r,g,b} or nil to clear
--------------------------------------------------------------------------------
local function set_pattern_color(ui_pattern, color_rgb)
  local song = renoise.song()
  local pat = song:pattern(ui_to_api(ui_pattern))
  if not pat then return 0 end

  local colored = 0
  for t = 1, #song.tracks do
    local ptrack = pat:track(t)
    if ptrack then
      if color_rgb then
        ptrack.color = {color_rgb[1], color_rgb[2], color_rgb[3]}
      else
        ptrack.color = nil
      end
      colored = colored + 1
    end
  end
  return colored
end

--------------------------------------------------------------------------------
-- MAP DEFINITIONS
-- Each entry in MAPS: { id, title, map }
-- map entries: { pattern = N [, label = "...", color = true] }
--------------------------------------------------------------------------------

-- back2back: special labels + green matrix colors (from original design)
local MAP_BACK2BACK = {
  {pattern = 0},
  {pattern = 1},
  {pattern = 0},
  {pattern = 1},
  {pattern = 2},
  {pattern = 3},
  {pattern = 4},
  {pattern = 5},
  {pattern = 6},
  {pattern = 7,  label = "terror",   color = true},
  {pattern = 8},
  {pattern = 9,  label = "phantoms", color = true},
  {pattern = 6},
  {pattern = 7},
  {pattern = 6},
  {pattern = 5,  label = "terror",   color = true},
  {pattern = 4},
  {pattern = 10},
  {pattern = 11, label = "go"},
  {pattern = 10},
  {pattern = 4},
  {pattern = 5},
  {pattern = 6},
  {pattern = 7},
  {pattern = 12},
  {pattern = 13},
}

-- Remaining maps from Airport.rtf (numbers only)
local MAP_CITIBANK = numbers_to_map {
  0, 1, 2, 3, 4, 3, 4, 3, 2, 5, 6, 7, 8, 9, 8, 9,
  10, 11, 12, 13, 12, 11, 14, 15, 14, 16, 10, 9, 8, 7, 17, 1, 2, 18,
}

local MAP_UNA_ALCOHOLIC4 = numbers_to_map {
  0, 1, 2, 3, 4, 5, 4, 3, 6, 7, 8, 9, 10, 11, 12, 7, 6, 13,
  2, 3, 4, 5, 14, 5, 4, 3, 6, 7, 12, 15, 16, 15, 12, 11, 17, 11, 10, 18,
}

local MAP_ALTO_VOLTAJE = numbers_to_map {
  0, 1, 2, 2, 2, 2, 6, 7, 8, 9, 10, 10, 10, 11, 12, 13, 12,
  14, 15, 16, 17, 16, 18, 18, 18, 19, 20,
}

local MAP_DICTADERA = numbers_to_map {
  0, 1, 2, 3, 4, 3, 2, 5, 2, 3, 4, 6, 6, 8, 9, 10, 11, 12,
  11, 13, 14, 14, 14, 15, 0, 16, 17, 14, 13, 18,
}

local MAP_CYNTHIA = numbers_to_map {
  0, 1, 2, 3, 4, 5, 6, 7, 8, 5, 4, 3, 9, 10, 8, 7, 11, 7, 6, 5,
  8, 12, 8, 10, 13, 10, 4, 14, 15, 16, 16, 17, 18, 19, 18, 17, 20,
  5, 8, 7, 21, 22, 22, 22, 23, 24, 25, 26,
}

local MAP_BANDERSNATCH = numbers_to_map {
  0, 1, 2, 1, 3, 4, 5, 6, 7, 6, 8, 9, 0, 1, 2, 1, 3, 4,
  10, 11, 10, 4, 5, 6, 7, 6, 8, 9, 12,
}

local MAP_BOOGIE_L_GRASO = numbers_to_map {
  0, 1, 2, 3, 4, 5, 6, 5, 7, 5, 6, 5, 4, 8, 9, 1, 0, 1,
  10, 11, 12, 13, 14, 13, 15, 8, 9, 1, 2, 16,
}

local MAP_TAXIISTA = numbers_to_map {
  0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 3, 4, 5, 6, 7, 8, 9, 10, 9,
  10, 11, 12, 10, 13, 14, 15, 16, 15, 14, 13, 10, 9, 8, 7, 6, 5, 4, 3,
  0, 3, 0, 17, 17, 17, 17, 18, 19, 20, 21, 22, 23,
}

local MAP_ASCENSORES = numbers_to_map {
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 8, 9, 10, 11, 12, 5, 13, 5, 13, 5,
  13, 14, 13, 5, 12, 15, 16, 17, 18, 11, 10, 9, 8, 19,
}

local MAP_AMPERES = numbers_to_map {
  0, 1, 2, 1, 0, 3, 4, 5, 6, 7, 6, 8, 6, 7, 9, 8, 6, 5,
  10, 11, 6, 8, 12, 8, 6, 5, 13, 14, 15,
}

local MAP_HAZARAT_ABRAHAM = numbers_to_map {
  0, 1, 2, 3, 2, 4, 5, 6, 7, 8, 7, 8, 9, 10, 9, 8, 7, 6,
  11, 8, 9, 10, 12, 13, 14, 15, 0, 1, 2, 4, 11, 8, 9, 10, 12,
  16, 17, 18, 18, 19, 0, 1, 2, 4, 5, 20,
}

local MAP_LEYES = numbers_to_map {
  0, 1, 0, 1, 2, 2, 2, 2, 3, 4, 5, 4, 5, 6, 5, 4, 7, 4, 5,
  8, 9, 8, 5, 10, 11, 12, 13, 12, 11, 14, 15, 16, 15, 14, 11, 10,
  17, 18, 19, 20,
}

local MAP_REACTOR = numbers_to_map {
  0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 12, 13, 14, 8, 7,
  15, 16, 17, 7, 8, 18, 6, 7, 6, 18, 19, 20, 1, 0, 21, 1, 2, 3, 3, 4,
  22, 23, 24, 23, 5, 6, 7, 15, 16, 25, 26, 26, 27, 10, 10, 11, 12, 21,
  0, 1, 2, 3, 3, 4, 5, 6, 7, 15, 16, 22,
}

local MAP_DONUTS = numbers_to_map {
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 12, 2, 4, 10, 11, 12, 13,
  14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 14, 24, 25, 24, 14, 23, 22, 21,
  26, 27, 28,
}

-- Registry: order = menu order
local MAPS = {
  {id = "back2back",        title = "back2back",          map = MAP_BACK2BACK},
  {id = "Citibank",         title = "Citibank",           map = MAP_CITIBANK},
  {id = "unaAlcoholic4",    title = "unaAlcoholic4",      map = MAP_UNA_ALCOHOLIC4},
  {id = "AltoVoltaje",      title = "AltoVoltaje",        map = MAP_ALTO_VOLTAJE},
  {id = "dictadera",        title = "dictadera",          map = MAP_DICTADERA},
  {id = "Cynthia",          title = "Cynthia",            map = MAP_CYNTHIA},
  {id = "bandersnatch",     title = "bandersnatch",       map = MAP_BANDERSNATCH},
  {id = "BoogieLGraso",     title = "Boogie 'L Graso",    map = MAP_BOOGIE_L_GRASO},
  {id = "taxiista",         title = "taxiista",           map = MAP_TAXIISTA},
  {id = "Ascensores",       title = "Ascensores",         map = MAP_ASCENSORES},
  {id = "Amperes",          title = "Amperes",            map = MAP_AMPERES},
  {id = "HazaratAbraham",   title = "HazaratAbraham",     map = MAP_HAZARAT_ABRAHAM},
  {id = "Leyes",            title = "Leyes",              map = MAP_LEYES},
  {id = "reactor",          title = "reactor",            map = MAP_REACTOR},
  {id = "donuts",           title = "donuts",             map = MAP_DONUTS},
}

--------------------------------------------------------------------------------
-- Apply a map (replaces the entire pattern sequence)
--------------------------------------------------------------------------------
local function apply_map(map, map_name)
  local song = renoise.song()
  local sequencer = song.sequencer
  local win = renoise.app().window

  -- Keep Pattern Matrix closed for the whole apply (and force closed at the end).
  win.pattern_matrix_is_visible = false

  song:describe_undo(string.format("%s: Apply map '%s'", TOOL_NAME, map_name))

  -- 1. Highest UI pattern needed
  local max_ui = 0
  for _, entry in ipairs(map) do
    if entry.pattern > max_ui then
      max_ui = entry.pattern
    end
  end

  -- 2. Ensure pool size
  ensure_patterns_exist(max_ui)

  -- 3. Build API sequence
  local new_sequence = {}
  for _, entry in ipairs(map) do
    table.insert(new_sequence, ui_to_api(entry.pattern))
  end

  -- 4. Replace sequence
  sequencer.pattern_sequence = new_sequence

  -- 5. Labels + colors
  local colored_patterns = {}
  local named_patterns = {}
  local color_list = {}

  for _, entry in ipairs(map) do
    local p = entry.pattern

    if entry.label and not named_patterns[p] then
      set_pattern_name(p, entry.label)
      named_patterns[p] = true
    end

    if entry.color and not colored_patterns[p] then
      set_pattern_color(p, copy_green())
      colored_patterns[p] = true
      table.insert(color_list, string.format("%02d", p))
    end
  end

  -- 6. Cursor to start of sequence
  song.selected_sequence_index = 1

  -- 7. Always keep Pattern Matrix closed (never force it open).
  -- Some Renoise UI paths open it when sequence/slot colors change; force it shut.
  renoise.app().window.pattern_matrix_is_visible = false

  -- 8. Feedback
  local color_info = (#color_list > 0)
    and (" | green: " .. table.concat(color_list, ","))
    or ""

  renoise.app():show_status(string.format(
    "[%s] Mapa '%s' aplicado (%d slots)%s",
    TOOL_NAME, map_name, #new_sequence, color_info
  ))
  print(string.format(
    "%s v%s: Applied map '%s' (%d slots). Colored: %s",
    TOOL_NAME, TOOL_VERSION, map_name, #new_sequence,
    (#color_list > 0) and table.concat(color_list, ",") or "(none)"
  ))
end

--------------------------------------------------------------------------------
-- Register menus + keybindings for every map
--------------------------------------------------------------------------------
local function register_map_actions(map_def)
  local title = map_def.title
  local map = map_def.map
  local invoke = function()
    apply_map(map, title)
  end

  renoise.tool():add_menu_entry {
    name = "Main Menu:Tools:" .. MENU_FOLDER .. ":" .. title,
    invoke = invoke,
  }
  renoise.tool():add_menu_entry {
    name = "Pattern Sequencer:" .. MENU_FOLDER .. ":" .. title,
    invoke = invoke,
  }
  renoise.tool():add_menu_entry {
    name = "Pattern Matrix:" .. MENU_FOLDER .. ":" .. title,
    invoke = invoke,
  }
  -- Keybinding: exactly "scope:topic:name" (only two colons total).
  renoise.tool():add_keybinding {
    name = "Global:Tools:" .. TOOL_NAME .. " - " .. title,
    invoke = invoke,
  }
end

for _, map_def in ipairs(MAPS) do
  register_map_actions(map_def)
end

--------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------
print(string.format(
  "%s v%s loaded (%d maps). Tools > %s > …",
  TOOL_NAME, TOOL_VERSION, #MAPS, MENU_FOLDER
))
