--[[============================================================================
  el sol perpendicular al amor - Renoise Tool
  Applies predefined "mapas" (pattern sequences) to the Pattern Sequence.

  Source maps: 04 - el sol perpendicular al amor.txt (Mega Doll / renoise)

  NOTE ON PATTERN INDICES
  -----------------------
  Map tables use UI numbers (0-based) as shown in the Pattern Sequencer.
  Renoise API uses 1-based indices (UI 00 <-> patterns[1]).
============================================================================]]--

local TOOL_NAME = "el sol perpendicular al amor"
local TOOL_VERSION = "1.0.0"
-- Submenu label under Tools / Pattern Sequencer / Pattern Matrix
local MENU_FOLDER = "el sol perpendicular al amor"

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
-- Source: 04 - el sol perpendicular al amor.txt (numbers only, no labels/colors)
--------------------------------------------------------------------------------

local MAP_TINTAEXPLOSIVA = numbers_to_map {
  0, 1, 1, 2, 2, 2, 2, 3, 4, 3, 5, 6, 5, 3, 2, 3,
  5, 7, 4, 8, 4, 2, 9, 3, 5, 4, 6, 8, 8, 8, 4, 4,
  2, 4, 8, 4, 5, 9, 4, 3, 3, 3, 6, 6, 3, 3, 6, 6,
  10, 11, 11, 11, 11, 12
}

local MAP_PABLOMRMOL = numbers_to_map {
  0, 1, 2, 1, 1, 2, 2, 3, 2, 1, 2, 3, 2, 1, 4, 5,
  6, 6, 6, 7, 7, 3, 3, 6, 3, 2, 4, 3, 2, 4, 8, 9
}

local MAP_FATALITYDUAL = numbers_to_map {
  0, 1, 1, 2, 3, 2, 2, 1, 1, 4, 1, 2, 4, 2, 5, 6,
  7, 7, 7, 8, 8, 9, 7, 6, 7, 8, 8, 8, 8, 9, 8, 10,
  6, 11, 12, 13, 13, 14, 12
}

local MAP_PEDROPICAPIEDRA = numbers_to_map {
  0, 1, 1, 1, 1, 1, 2, 3, 4, 5, 1, 5, 1, 5, 1, 2,
  2, 3, 3, 4, 3, 5, 6, 7, 8, 8, 9, 10, 10, 9, 7, 8,
  9, 9, 10, 10, 11, 11, 12, 12
}

local MAP_EMPTYVESSELFRICTION = numbers_to_map {
  0, 1, 1, 1, 1, 2, 2, 3, 1, 4, 4, 4, 5, 5, 6, 5,
  4, 7, 8, 9, 8, 8, 10, 10, 11, 10, 10, 4, 4, 4, 4
}

local MAP_PORFAVORNOINTERRUMPIR = numbers_to_map {
  0, 1, 2, 3, 4, 4, 3, 1, 3, 3, 5, 3, 3, 5, 4, 4,
  4, 4, 4, 6, 7, 8, 8, 7, 8, 8, 9
}

local MAP_ALASMALAS = numbers_to_map {
  0, 1, 2, 3, 4, 3, 3, 5, 6, 7, 6, 8, 8, 7, 6, 7,
  7, 9, 8, 6, 6, 10, 10, 11
}

local MAP_PRINCESITAVIDEOS = numbers_to_map {
  0, 1, 2, 3, 4, 5, 6, 6, 6, 7, 7, 7, 7, 8, 6, 7,
  7, 9, 8, 10, 10, 11
}

local MAP_MENTIRAPIADOSA = numbers_to_map {
  0, 1, 2, 3, 4, 5, 6, 6, 6, 7, 8, 9, 7, 8, 10, 10,
  11
}

local MAP_TRISITOSMATRICIDIO = numbers_to_map {
  0, 1, 1, 1, 1, 2, 3, 3, 3, 3, 4, 2, 4, 5, 6, 7,
  8, 9, 8, 9, 10, 8, 9, 10, 8, 8, 11
}

local MAP_MATICES = numbers_to_map {
  0, 1, 1, 1, 1, 2, 3, 3, 3, 3, 4, 2, 4, 5, 6, 7,
  6, 3, 4, 4, 8
}

local MAP_SUPLEMENTARIEDADDELVECTORRADIAL = numbers_to_map {
  0, 1, 2, 2, 2, 2, 1, 3, 4, 3, 5, 6, 6, 7, 7, 7,
  7
}

local MAP_CORTACUERVOSDELVERTICEADYACENTE = numbers_to_map {
  0, 1, 2, 2, 3, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9, 9,
  9, 10, 10, 8, 10, 9, 10
}

local MAP_CHIFLAMICASCLOROGEL = numbers_to_map {
  0, 1, 2, 2, 1, 3, 4, 4, 5, 5, 6, 7, 7, 7, 8, 9,
  10, 11, 12, 11, 13, 14, 14, 14, 14, 14, 14, 15
}

local MAP_CUATROPARQUESCONSECUTIVOSREVERSED = numbers_to_map {
  0, 1, 2, 2, 2, 1, 1, 3, 1, 3, 1, 4, 5, 6, 7, 5,
  6, 6, 6, 6, 8, 9, 9, 10, 10, 11, 12, 12, 12, 13, 11, 12,
  12, 5, 5, 11, 13, 13, 13, 14, 14, 15, 16, 15, 16, 11, 17, 17,
  17, 17, 17
}

local MAP_KADABRAPREDICCINPIKACHUVERTICE = numbers_to_map {
  0, 1, 2, 1, 1, 2, 2, 3, 2, 4, 4, 5, 6, 7, 8, 9,
  9, 9
}

local MAP_PICCONSECUTIVOANIC = numbers_to_map {
  0, 1, 1, 2, 2, 1, 1, 3, 2, 3, 3, 3, 3, 4, 4, 4,
  4, 2, 5, 5, 6, 5, 5, 7, 7, 7, 8
}

local MAP_MIEL = numbers_to_map {
  0, 1, 1, 2, 2, 3, 3, 4, 3, 4, 1, 1, 1, 2, 5, 6,
  7, 8, 7, 9, 7, 10, 11, 12
}

local MAP_CARBONILEO = numbers_to_map {
  0, 1, 1, 2, 2, 3, 3, 4, 3, 1, 2, 2, 2, 1, 5, 6,
  7, 6, 8, 9
}

local MAP_THEUHMADGURBINGHORALBAYEKSCARS = numbers_to_map {
  0, 1, 1, 2, 3, 3, 4, 5, 5, 2, 3, 2
}

local MAP_DOSVODKASTRIPLESPERPENDICULARES = numbers_to_map {
  0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 5, 6, 6, 7,
  8, 9, 7, 7, 7, 7, 6, 8, 6, 8, 8, 7, 7, 8, 7, 9,
  9, 10, 11, 11, 10, 10, 10, 11
}

local MAP_ALBANANOALVENENO = numbers_to_map {
  0, 1, 1, 2, 3, 3, 4, 1, 1, 1, 2, 2, 2, 4, 4, 5,
  6, 7, 8, 8, 7, 7, 9, 9, 9
}

local MAP_PAPELMACHETLIFEKNIVEGLASSOOR = numbers_to_map {
  0, 1, 1, 2, 2, 1, 1, 2, 3, 3, 2, 4, 4, 4, 2, 3,
  5, 6, 5, 6, 7
}

local MAP_TANPURAWALLSCATETOADYACENTE = numbers_to_map {
  0, 1, 1, 2, 3, 1, 2, 1, 1, 4, 5, 5, 4, 6, 7, 7,
  6, 6, 8, 8, 9
}

local MAP_ORACINPORTALENCERRONA = numbers_to_map {
  0, 0, 1, 0, 0, 2, 0, 0, 3, 4, 5, 4, 4, 6, 6, 6,
  7, 8, 9, 8, 9, 8, 8, 10, 10
}

local MAP_HOJASSECASPULVERIZADAS = numbers_to_map {
  0, 0, 1, 0, 0, 2, 0, 0, 3, 4, 5, 6, 6, 7, 7, 7,
  2, 4, 7, 7, 7, 8, 9, 9, 8, 9, 9, 6, 9, 10, 11, 10,
  10, 12
}

local MAP_ARBOLESVENENOSOSSECOSPULVERIZADOS = numbers_to_map {
  0, 1, 2, 1, 3, 3, 2, 4, 4, 5, 6, 6, 4, 7, 7, 8,
  8, 6, 6, 6, 6, 9, 8, 7, 7, 7
}

local MAP_REBELDESOLARBVEDADEMADERA = numbers_to_map {
  0, 1, 2, 1, 3, 3, 1, 2, 2, 1, 3, 3, 2, 4, 4, 5,
  6, 4, 4, 4, 5, 6, 6, 6, 4, 4, 5, 5, 6, 6, 7, 7,
  6, 6, 8, 7, 8, 9, 9, 9, 10, 11
}

-- Registry: order = menu order
local MAPS = {
  {id = "tintaexplosiva", title = "tinta explosiva", map = MAP_TINTAEXPLOSIVA},
  {id = "PabloMrmol", title = "Pablo Mármol", map = MAP_PABLOMRMOL},
  {id = "fatalitydual", title = "fatality dual", map = MAP_FATALITYDUAL},
  {id = "PedroPicapiedra", title = "Pedro Picapiedra", map = MAP_PEDROPICAPIEDRA},
  {id = "emptyVesselFriction", title = "empty Vessel Friction", map = MAP_EMPTYVESSELFRICTION},
  {id = "porfavorNoInterrumpir", title = "por favor No Interrumpir", map = MAP_PORFAVORNOINTERRUMPIR},
  {id = "alasmalas", title = "a las malas", map = MAP_ALASMALAS},
  {id = "princesitavideos", title = "princesita videos", map = MAP_PRINCESITAVIDEOS},
  {id = "mentirapiadosa", title = "mentira piadosa", map = MAP_MENTIRAPIADOSA},
  {id = "trisitosmatricidio", title = "trisitos matricidio", map = MAP_TRISITOSMATRICIDIO},
  {id = "matices", title = "matices", map = MAP_MATICES},
  {id = "suplementariedaddelvectorradial", title = "suplementariedad del vector radial", map = MAP_SUPLEMENTARIEDADDELVECTORRADIAL},
  {id = "cortacuervosdelverticeadyacente", title = "corta cuervos del vertice adyacente", map = MAP_CORTACUERVOSDELVERTICEADYACENTE},
  {id = "chiflamicasclorogel", title = "chifla micas cloro gel", map = MAP_CHIFLAMICASCLOROGEL},
  {id = "cuatroparquesconsecutivosreversed", title = "cuatro parques consecutivos reversed", map = MAP_CUATROPARQUESCONSECUTIVOSREVERSED},
  {id = "kadabraprediccinpikachuvertice", title = "kadabra predicción pikachu vertice", map = MAP_KADABRAPREDICCINPIKACHUVERTICE},
  {id = "picconsecutivoanic", title = "pic consecutivo a nic", map = MAP_PICCONSECUTIVOANIC},
  {id = "miel", title = "miel", map = MAP_MIEL},
  {id = "carbonileo", title = "carbonileo", map = MAP_CARBONILEO},
  {id = "TheUhmadGurBinGhoralBayekScars", title = "The 'Uhmad Gur Bin Ghor al Bayek' Scars", map = MAP_THEUHMADGURBINGHORALBAYEKSCARS},
  {id = "dosvodkastriplesperpendiculares", title = "dos vodkas triples perpendiculares", map = MAP_DOSVODKASTRIPLESPERPENDICULARES},
  {id = "AlBananoAlVeneno", title = "Al Banano Al Veneno", map = MAP_ALBANANOALVENENO},
  {id = "PapelMachetLifeKniveGlassoor", title = "Papel Machet Life Knive Glassoor", map = MAP_PAPELMACHETLIFEKNIVEGLASSOOR},
  {id = "TanpuraWallsCatetoAdyacente", title = "'Tanpura Walls' Cateto Adyacente", map = MAP_TANPURAWALLSCATETOADYACENTE},
  {id = "oracinportalencerrona", title = "oración portal encerrona", map = MAP_ORACINPORTALENCERRONA},
  {id = "hojassecaspulverizadas", title = "hojas secas pulverizadas", map = MAP_HOJASSECASPULVERIZADAS},
  {id = "Arbolesvenenosossecospulverizados", title = "Arboles venenosos secos pulverizados", map = MAP_ARBOLESVENENOSOSSECOSPULVERIZADOS},
  {id = "rebeldesolarbvedademadera", title = "rebelde solar bóveda de madera", map = MAP_REBELDESOLARBVEDADEMADERA},
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

  -- 5. Labels + colors (optional; none of these maps use them by default)
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
