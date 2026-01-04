#!/usr/bin/env zsh
set -euo pipefail

# Extensiones soportadas
typeset -a AUDIO_EXT
AUDIO_EXT=(mp3 m4a flac)

# Verificación simple de dependencias
need_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Falta el comando requerido: $cmd"
    echo "   Instálalo y vuelve a ejecutar el script."
    exit 1
  fi
}

need_cmd eyeD3
need_cmd AtomicParsley
need_cmd metaflac

# Buscar la primera imagen de portada en un directorio (jpg/jpeg/png)
find_cover_image() {
  local dir="$1"
  local cover
  cover="$(find "$dir" -maxdepth 1 \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | head -n 1 || true)"
  echo "$cover"
}

# Crear plantilla tags.txt en un subdirectorio
create_template() {
  local dir="$1"
  local template="$dir/tags.txt"

  typeset -a files
  files=()

  for ext in "${AUDIO_EXT[@]}"; do
    for f in "$dir"/*."$ext"(N); do
      files+=("$f")
    done
  done

  if (( ${#files[@]} == 0 )); then
    echo "⚠️  No hay archivos de audio en $dir, no se crea plantilla."
    return
  fi

  # Ordena los archivos por nombre
  files=("${(@on)files}")

  {
    echo "# Plantilla de tags para el directorio: $dir"
    echo "# Una línea por pista en este formato:"
    echo "# titulo|artista|album|genero|año"
    echo "# Rellena y guarda este archivo, luego vuelve a ejecutar el script."
    for f in "${files[@]}"; do
      local base="${f:t}"
      echo "${base%.*}||||"
    done
  } > "$template"

  echo "📝 Se creó plantilla: $template"
}

# Aplicar tags a un archivo según la extensión
tag_file() {
  local file="$1"
  local title="$2"
  local artist="$3"
  local album="$4"
  local genre="$5"
  local year="$6"
  local cover="$7"

  local ext="${file##*.}"
  ext="${ext:l}"  # a minúsculas

  echo "  → Etiquetando: ${file:t}"

  case "$ext" in
    mp3)
      # Limpia imágenes anteriores y aplica nueva portada + tags
      if [[ -n "$cover" && -f "$cover" ]]; then
        eyeD3 --remove-all-images "$file" >/dev/null 2>&1 || true
        if ! eyeD3 --add-image "${cover}:FRONT_COVER" "$file" >/dev/null 2>&1; then
          echo "    ⚠️  No se pudo agregar la portada" >&2
        fi
      fi
      if ! eyeD3 \
        --title "$title" \
        --artist "$artist" \
        --album "$album" \
        --genre "$genre" \
        ${year:+--year "$year"} \
        "$file" >/dev/null 2>&1; then
        echo "    ⚠️  Error al aplicar tags" >&2
        return 1
      fi
      ;;
    m4a)
      # AtomicParsley reescribe el archivo con --overWrite
      if [[ -n "$cover" && -f "$cover" ]]; then
        if ! AtomicParsley "$file" \
          --title "$title" \
          --artist "$artist" \
          --album "$album" \
          --genre "$genre" \
          ${year:+--year "$year"} \
          --artwork "$cover" \
          --overWrite >/dev/null 2>&1; then
          echo "    ⚠️  Error al aplicar tags con portada" >&2
          return 1
        fi
      else
        if ! AtomicParsley "$file" \
          --title "$title" \
          --artist "$artist" \
          --album "$album" \
          --genre "$genre" \
          ${year:+--year "$year"} \
          --overWrite >/dev/null 2>&1; then
          echo "    ⚠️  Error al aplicar tags" >&2
          return 1
        fi
      fi
      ;;
    flac)
      # Tags Vorbis y portada con metaflac
      # Primero limpiamos tags concretos para evitar duplicados
      metaflac \
        --remove-tag=TITLE \
        --remove-tag=ARTIST \
        --remove-tag=ALBUM \
        --remove-tag=GENRE \
        --remove-tag=DATE \
        "$file"

      metaflac \
        --set-tag="TITLE=$title" \
        --set-tag="ARTIST=$artist" \
        --set-tag="ALBUM=$album" \
        --set-tag="GENRE=$genre" \
        ${year:+--set-tag="DATE=$year"} \
        "$file"

      if [[ -n "$cover" && -f "$cover" ]]; then
        # Opcional: eliminar imágenes previas
        metaflac --remove --block-type=PICTURE "$file" 2>/dev/null || true

        local mime="image/jpeg"
        case "${cover:e:l}" in
          png) mime="image/png" ;;
          jpg|jpeg) mime="image/jpeg" ;;
        esac

        if ! metaflac \
          --import-picture-from="|$mime|||$cover" \
          "$file" 2>/dev/null; then
          echo "    ⚠️  Error al importar portada" >&2
        fi
      fi
      ;;
    *)
      echo "  ⚠️ Extensión no soportada: $ext"
      ;;
  esac
}

# Procesar un subdirectorio (un álbum)
process_album_dir() {
  local dir="$1"
  echo "📂 Álbum: $dir"

  local template="$dir/tags.txt"

  if [[ ! -f "$template" ]]; then
    echo "  No se encontró tags.txt en este directorio."
    create_template "$dir"
    echo "  Edita tags.txt y vuelve a ejecutar el script para este álbum."
    return
  fi

  # Leer archivos de audio
  typeset -a files
  files=()
  for ext in "${AUDIO_EXT[@]}"; do
    for f in "$dir"/*."$ext"(N); do
      files+=("$f")
    done
  done

  if (( ${#files[@]} == 0 )); then
    echo "  ⚠️ No hay archivos de audio soportados en $dir."
    return
  fi

  files=("${(@on)files}")

  # Leer plantilla
  typeset -a titles artists albums genres years
  titles=() ; artists=() ; albums=() ; genres=() ; years=()

  while IFS='|' read -r title artist album genre year; do
    # Saltar comentarios y líneas vacías
    [[ -z "${title:-}" ]] && continue
    [[ "${title[1]}" == "#" ]] && continue

    titles+=("$title")
    artists+=("${artist:-}")
    albums+=("${album:-}")
    genres+=("${genre:-}")
    years+=("${year:-}")
  done < "$template"

  if (( ${#titles[@]} == 0 )); then
    echo "  ⚠️ La plantilla $template no contiene líneas válidas."
    return
  fi

  if (( ${#files[@]} != ${#titles[@]} )); then
    echo "  ⚠️ Desajuste: ${#files[@]} archivos de audio, pero ${#titles[@]} líneas de datos."
    echo "     Asegúrate de que haya una línea por cada archivo en el mismo orden."
    return
  fi

  local cover
  cover="$(find_cover_image "$dir")"
  if [[ -n "$cover" ]]; then
    echo "  Usando portada: ${cover:t}"
  else
    echo "  ⚠️ No se encontró imagen de portada (jpg/jpeg/png) en $dir."
  fi

  local i
  for i in {1..${#files[@]}}; do
    tag_file "${files[i]}" "${titles[i]}" "${artists[i]}" "${albums[i]}" "${genres[i]}" "${years[i]}" "$cover"
  done

  echo "✅ Álbum procesado: $dir"
}

# --- Entrada principal ---

echo "Pega la ruta desde Finder (directorio raíz de tu discografía o un álbum específico):"
read -r root_dir || {
  echo "❌ Entrada cancelada por el usuario." >&2
  exit 1
}

# Limpiar la ruta (puede venir con comillas desde Finder)
root_dir="${(Q)root_dir}"
root_dir="${root_dir#"${root_dir%%[![:space:]]*}"}"
root_dir="${root_dir%"${root_dir##*[![:space:]]}"}"
root_dir="${root_dir%/}"

if [[ ! -d "$root_dir" ]]; then
  echo "❌ La ruta no es un directorio válido: $root_dir"
  exit 1
fi


# Buscar subdirectorios inmediatos
typeset -a subdirs
subdirs=()
while IFS= read -r d; do
  subdirs+=("$d")
done < <(find "$root_dir" -mindepth 1 -maxdepth 1 -type d | sort)

if (( ${#subdirs[@]} == 0 )); then
  # Sin subdirectorios: tratamos root_dir como un solo álbum
  process_album_dir "$root_dir"
  exit 0
fi

echo "Se encontraron ${#subdirs[@]} subdirectorios (posibles álbumes) en:"
echo "  $root_dir"

echo -n "¿Quieres actualizar los tags en BULK mode para TODOS los subdirectorios? (s/n): "
read -r bulk_answer || {
  echo "❌ Entrada cancelada por el usuario." >&2
  exit 1
}

if [[ "$bulk_answer" == [sS] ]]; then
  for d in "${subdirs[@]}"; do
    process_album_dir "$d"
  done
  exit 0
fi

echo "Subdirectorios disponibles:"
local idx=1
for d in "${subdirs[@]}"; do
  echo "  [$idx] ${d:t}"
  ((idx++))
done

echo -n "Elige el número de un subdirectorio para procesar solo ese álbum: "
read -r choice || {
  echo "❌ Entrada cancelada por el usuario." >&2
  exit 1
}

if ! [[ "$choice" == <-> ]]; then
  echo "❌ Opción no válida." >&2
  exit 1
fi

if (( choice < 1 || choice > ${#subdirs[@]} )); then
  echo "❌ Número fuera de rango." >&2
  exit 1
fi

process_album_dir "${subdirs[choice]}"

