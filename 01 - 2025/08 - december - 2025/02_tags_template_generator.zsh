#!/usr/bin/env zsh
set -euo pipefail

# Rutas
CSV_FILE="${1:-./Mega-Doll-Catalogo-Completo.csv}"
if [[ ! -f "$CSV_FILE" ]]; then
  echo "❌ CSV no encontrado: $CSV_FILE"
  exit 1
fi

echo "Pega ruta de discografía:"
read -r root_dir || {
  echo "❌ Entrada cancelada por el usuario." >&2
  exit 1
}

# Limpiar la ruta (puede venir con comillas desde Finder)
root_dir="${(Q)root_dir}"
root_dir="${root_dir#"${root_dir%%[![:space:]]*}"}"
root_dir="${root_dir%"${root_dir##*[![:space:]]}"}"
root_dir="${root_dir%/}"


#--------------------


> "${root_dir}/mismatches.log"  # Log limpio
echo "Álbumes únicos en CSV ($(awk -F, 'NR>1 && !seen[$3]++ {cnt++} END{print cnt}' "$CSV_FILE")):" | head -5
awk -F, -v n=5 'NR>1 && !seen[$3]++ {print; if(++c==n)exit}' "$CSV_FILE" | cut -d, -f3 | sort -u


#--------------------

if [[ ! -d "$root_dir" ]]; then
  echo "❌ Ruta inválida: $root_dir"
  exit 1
fi

# Subdirs (álbumes)
subdirs=($(find "$root_dir" -mindepth 1 -maxdepth 1 -type d | sort -f))  # case insensitive sort

if (( ${#subdirs[@]} == 0 )); then
  echo "❌ Sin subdirectorios."
  exit 1
fi

echo "Subdirs encontrados: ${#subdirs[@]}"

# Opción bulk?
echo -n "¿Bulk para todos? (s/n): "
read bulk_ans || {
  echo "❌ Entrada cancelada por el usuario." >&2
  exit 1
}

if [[ "$bulk_ans" != [sSyY]* ]]; then
  echo "Elige [1-${#subdirs[@]}]:"
  for i ({1..${#subdirs[@]}} ) { echo "[$i] ${subdirs[i]:t}" }
  read choice || {
    echo "❌ Entrada cancelada por el usuario." >&2
    exit 1
  }
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "❌ Opción no válida." >&2
    exit 1
  fi
  (( choice >=1 && choice <= ${#subdirs[@]} )) || {
    echo "❌ Número fuera de rango." >&2
    exit 1
  }
  generate_tags "${subdirs[choice]}" "$CSV_FILE"
  exit
fi

for dir in "${subdirs[@]}"; do
  generate_tags "$dir" "$CSV_FILE"
done

if [[ -s "${root_dir}/mismatches.log" ]]; then
  echo ""
  echo "📋 LOG ERRORES: ${root_dir}/mismatches.log"
  echo "Ejemplo mismatches:"
  tail -5 "${root_dir}/mismatches.log"
  echo ""
  echo "💡 AJUSTES SUGERIDOS:"
  echo "- Renombra subdirs a 'Release Name' exacto (e.g. 'Reflejos de tu Corazon en un Espejo Antiguo')"
  echo "- O edita tags.txt manual en dirs no-match"
  echo "- Bulk tags previos solo en dirs con tags.txt generados"
else
  echo "🎉 Todos matches OK, ¡ejecuta tag_audio.zsh!"
fi


# Función para generar tags.txt en un dir álbum
# Plantilla manual si no match (de script anterior, simplificada)
create_template() {
  local dir="$1" template="$dir/tags.txt"
  typeset -a files=( "$dir"/*.{mp3,m4a,flac}(N) )
  files=("${(@on)files}")  # sort
  if (( ${#files[@]} == 0 )); return; fi
  {
    echo "# Plantilla manual para: ${dir:t}"
    echo "# Edita: titulo|artista|album|genero|año"
    for f in "${files[@]}"; do
      echo "${f:t:r}||||"  # basename sin ext
    done
  } > "$template"
  echo "  📝 Creada plantilla manual: $template"
}

# Generador mejorado con log/sugerencias
generate_tags() {
  local dir="$1" csv="$2" log_file="${root_dir}/mismatches.log"
  local album="${dir:t}"

  # Intento match CSV
  awk -F, -v alb="$album" 'NR>1 && $3==alb { gsub(/"/,"",$10);gsub(/"/,"",$12);gsub(/"/,"",$7);gsub(/"/,"",$6); print $10 "|" ($12?$12:"Mega Doll") "|" $3 "|" $7 "|" substr($6,1,4) }' "$csv" | sort > "$dir/tags.txt.tmp"

  if [[ -s "$dir/tags.txt.tmp" ]]; then
    {
      echo "# Auto desde CSV: $album ($(wc -l < "$dir/tags.txt.tmp") pistas)"
      echo "# titulo|artista|album|genero|año"
      cat "$dir/tags.txt.tmp"
    } > "$dir/tags.txt"
    rm "$dir/tags.txt.tmp"
    echo "✅ $album: tags.txt creado."
    return
  fi

  # No match: log + sugerencias + manual template
  if [[ -f "$log_file" ]] || touch "$log_file" 2>/dev/null; then
    echo "$album - Sin match exacto en CSV." >> "$log_file"
  fi
  echo "  Sugerencias similares (grep en Release Name):"
  if awk -F, 'NR>1 {print $3}' "$csv" 2>/dev/null | grep -i -m5 "$album" 2>/dev/null | sort -u | while IFS= read -r sug || [[ -n "$sug" ]]; do
    [[ -n "$sug" ]] && echo "    → '$sug'"
  done; then
    : # Sugerencias mostradas
  else
    echo "    (No se encontraron sugerencias similares)"
  fi
  create_template "$dir"
  if [[ -f "$log_file" ]] || touch "$log_file" 2>/dev/null; then
    echo "$album >> log mismatches.log" >> "$log_file"  # Dup to log
  fi
}

