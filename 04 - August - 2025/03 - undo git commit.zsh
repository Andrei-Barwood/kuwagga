#!/bin/zsh
set -euo pipefail

# Colors (true color)
GREY='\033[38;2;99;98;124m'        # 63627C - replacing red
LIGHT_BLUE='\033[38;2;195;206;222m' # C3CEDE - replacing green
YELLOW='\033[38;2;255;255;184m'     # FFFFB8 - custom yellow
DARK_BLUE='\033[38;2;72;81;153m'    # 485199 - replacing cyan
PALE_BLUE='\033[38;2;167;183;207m'  # A7B7CF - replacing blue
NC='\033[0m'

# Verbose echo (to stderr to avoid mixing with data)
vecho() { print -r -- "${PALE_BLUE}[verbose]${NC} $*" >&2; }

show_reset_explanations() {
  echo "${DARK_BLUE}=== Git Reset Options Explained ===${NC}"
  echo "${LIGHT_BLUE}Soft Reset (--soft)${NC}: Move HEAD back, keep all changes staged for commit (safe for message fixes or adding files)."
  echo "${YELLOW}Mixed Reset (default)${NC}: Move HEAD back, keep changes in working tree but unstaged, good to split commits, but you will have to use 'git add .' and 'git commit -m' again."
  echo "${GREY}Hard Reset (--hard)${NC}: Move HEAD back and discard staged/unstaged changes; destructive and irreversible."
  echo "${PALE_BLUE}Interactive Rebase${NC}: Edit/reword/squash/drop commits interactively for history cleanup."
}

# Discover .git repos under a given directory
discover_git_repos_under() {
  local root="$1"
  local maxdepth="${2:-8}"
  vecho "Scanning: $root (depth: $maxdepth)"
  # Print only repo paths to stdout
  find "$root" -type d -name ".git" -maxdepth "$maxdepth" 2>/dev/null | sed 's:/.git$::'
}

get_unpushed_commits() {
  local repo="$1"
  local upstream
  upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || return 2
  git -C "$repo" log "${upstream}..HEAD" --oneline 2>/dev/null || return 1
}

get_recent_commits() {
  local repo="$1"
  git -C "$repo" log --oneline -10 2>/dev/null || return 1
}

select_from_list() {
  local -a items=("$@")
  local count=${#items[@]}
  local choice
  read "choice?Enter number (1-$count), or 0 to cancel: "
  [[ "$choice" =~ ^[0-9]+$ ]] || { echo "${GREY}Invalid input${NC}"; return 1; }
  (( choice == 0 )) && { echo "${YELLOW}Cancelled.${NC}"; return 2; }
  (( choice >= 1 && choice <= count )) || { echo "${GREY}Out of range${NC}"; return 1; }
  echo $choice
  return 0
}

list_immediate_dirs() {
  local base="$1"
  find "$base" -mindepth 1 -maxdepth 1 -type d ! -name ".*" 2>/dev/null | sort
}

build_repo_info() {
  local repo="$1"
  local unpushed
  if unpushed=$(get_unpushed_commits "$repo"); then
    if [[ -n "$unpushed" ]]; then
      echo "$repo|HAS_UNPUSHED|$unpushed"
      return
    fi
  fi
  local recent
  if recent=$(get_recent_commits "$repo"); then
    if [[ -n "$recent" ]]; then
      echo "$repo|NO_UPSTREAM|$recent"
      return
    fi
  fi
  echo "$repo|EMPTY|"
}

manage_repo() {
  local repo="$1"
  local info="$2"
  local repo_status commits
  IFS='|' read -r _ repo_status commits <<< "$info"

  echo
  echo "${LIGHT_BLUE}Selected repository:${NC} $repo"
  if [[ "$repo_status" == "EMPTY" ]]; then
    echo "${YELLOW}Repository has no commits.${NC}"
    return
  fi

  echo
  echo "${YELLOW}Actions:${NC}"
  echo "${LIGHT_BLUE}1. Soft reset${NC} — keep changes staged"
  echo "${YELLOW}2. Mixed reset${NC} — keep changes unstaged"
  echo "${GREY}3. Hard reset${NC} — discard all changes"
  echo "${PALE_BLUE}4. Interactive rebase${NC} — edit recent commits"
  echo "5. Show detailed history"
  echo "6. Show explanations"
  echo "7. Cancel"

  local action
  read "action?Choose (1-7): "
  case "$action" in
    1)
      echo "${DARK_BLUE}Soft reset: undo last commit, keep changes staged.${NC}"
      read "ok?Proceed? (y/N): "
      [[ "$ok" =~ ^[Yy]$ ]] && git -C "$repo" reset --soft HEAD~1 && echo "${LIGHT_BLUE}Done.${NC}"
      ;;
    2)
      echo "${DARK_BLUE}Mixed reset: undo last commit, unstage changes.${NC}"
      read "ok?Proceed? (y/N): "
      [[ "$ok" =~ ^[Yy]$ ]] && git -C "$repo" reset HEAD~1 && echo "${LIGHT_BLUE}Done.${NC}"
      ;;
    3)
      echo "${GREY}Hard reset: destructive, removes changes permanently.${NC}"
      read "ok?Type 'DELETE MY WORK' to confirm: "
      [[ "$ok" == "DELETE MY WORK" ]] && git -C "$repo" reset --hard HEAD~1 && echo "${LIGHT_BLUE}Done.${NC}"
      ;;
    4)
      echo "${DARK_BLUE}Interactive rebase last 5 commits...${NC}"
      git -C "$repo" rebase -i HEAD~5
      ;;
    5)
      git -C "$repo" log --oneline --graph -20
      ;;
    6)
      show_reset_explanations
      ;;
    7)
      echo "${YELLOW}Cancelled.${NC}"
      ;;
    *)
      echo "${GREY}Invalid action.${NC}"
      ;;
  esac

  echo
  echo "${LIGHT_BLUE}Status:${NC}"
  git -C "$repo" status --short || true
}

main() {
  echo "${LIGHT_BLUE}=== Git Commit Manager ===${NC}"
  vecho "Listing folders in home directory (~)"

  local homedir="$HOME"
  local -a root_dirs
  local d
  while IFS= read -r d; do root_dirs+=("$d"); done < <(list_immediate_dirs "$homedir")

  if (( ${#root_dirs[@]} == 0 )); then
    echo "${GREY}No folders found in home directory.${NC}"
    exit 1
  fi

  echo "${YELLOW}Select a top-level folder under ~ to search:${NC}"
  local idx=1
  for p in "${root_dirs[@]}"; do
    echo "${PALE_BLUE}[$idx]${NC} $p"
    ((idx++))
  done

  local choice
  choice=$(select_from_list "${root_dirs[@]}") || exit 1
  local base="${root_dirs[$choice]}"
  vecho "Selected base: ${base}"

  echo
  echo "${YELLOW}Do you want to narrow the search to a subfolder inside:${NC} $base"
  echo "1. Yes — choose a subfolder"
  echo "2. No — scan the selected folder"
  local narrow
  read "narrow?Choose (1-2): "
  local scan_root="$base"

  if [[ "$narrow" == "1" ]]; then
    vecho "Listing immediate subfolders of: $base"
    local -a sub_dirs=()
    while IFS= read -r d; do sub_dirs+=("$d"); done < <(list_immediate_dirs "$base")
    if (( ${#sub_dirs[@]} == 0 )); then
      echo "${GREY}No subfolders found; scanning selected folder.${NC}"
    else
      echo "${YELLOW}Select a subfolder to scan:${NC}"
      local j=1
      for p in "${sub_dirs[@]}"; do
        echo "${PALE_BLUE}[$j]${NC} $p"
        ((j++))
      done
      local choice2
      choice2=$(select_from_list "${sub_dirs[@]}") || true
      if [[ -n "${choice2:-}" && "$choice2" != "2" ]]; then
        scan_root="${sub_dirs[$choice2]}"
        vecho "Selected subfolder: ${scan_root}"
      fi
    fi
  fi

  echo
  vecho "Starting scan under: $scan_root"
  local -a repos
  while IFS= read -r r; do repos+=("$r"); done < <(discover_git_repos_under "$scan_root" 8)

  if (( ${#repos[@]} == 0 )); then
    echo "${GREY}No git repositories found under selected path.${NC}"
    exit 1
  fi

  echo "${YELLOW}Found ${#repos[@]} repositories:${NC}"
  local -a repo_info
  local r
  for r in "${repos[@]}"; do
    vecho "Probing: $r"
    repo_info+=("$(build_repo_info "$r")")
  done

  local k=1
  for info in "${repo_info[@]}"; do
    local repo_path repo_status commits
    IFS='|' read -r repo_path repo_status commits <<< "$info"
    echo "${PALE_BLUE}[$k]${NC} $repo_path"
    case "$repo_status" in
      HAS_UNPUSHED)
        echo "    ${GREY}📤 Unpushed commits:${NC}"
        print -- "$commits" | while IFS= read -r c; do [[ -n "$c" ]] && echo "      • $c"; done
        ;;
      NO_UPSTREAM)
        echo "    ${YELLOW}⚠️  No upstream branch set${NC}"
        echo "    Recent commits:"
        print -- "$commits" | head -3 | while IFS= read -r c; do [[ -n "$c" ]] && echo "      • $c"; done
        ;;
      EMPTY)
        echo "    ${LIGHT_BLUE}✅ No commits${NC}"
        ;;
    esac
    echo
    ((k++))
  done

  echo "${LIGHT_BLUE}Select a repository to manage commits (or type 'help' for explanations):${NC}"
  local sel
  read "sel?Enter number (1-${#repos[@]}) or 'help': "
  if [[ "$sel" == "help" ]]; then
    show_reset_explanations
    read "sel?Enter number (1-${#repos[@]}): "
  fi
  [[ "$sel" =~ ^[0-9]+$ ]] || { echo "${GREY}Invalid selection.${NC}"; exit 1; }
  (( sel >= 1 && sel <= ${#repos[@]} )) || { echo "${GREY}Out of range.${NC}"; exit 1; }

  manage_repo "${repos[$sel]}" "${repo_info[$sel]}"
}

main "$@"
