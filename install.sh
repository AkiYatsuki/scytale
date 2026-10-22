#!/bin/sh
# Scytale installer — symlink scripts, seed config/state, wire up .zshrc
set -eu

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

REPO=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ZSH_HOME="${ZSH_HOME:-$HOME/.zsh}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

mkdir -p "$ZSH_HOME/themes" "$CONFIG_HOME"

# 1. scripts + themes (symlinked, so repo edits are live)
ln -sfn "$REPO/zsh/starship-theme.zsh"    "$ZSH_HOME/starship-theme.zsh"
ln -sfn "$REPO/zsh/highlight-selector.zsh" "$ZSH_HOME/theme-selector.zsh"
for f in "$REPO"/themes/*.zsh; do
  [ -e "$f" ] || continue
  ln -sfn "$f" "$ZSH_HOME/themes/$(basename "$f")"
done
say "link  $ZSH_HOME/starship-theme.zsh, $ZSH_HOME/theme-selector.zsh, themes/*.zsh"

# 2. starship.toml is a generated artifact, not the source of truth
if [ -e "$CONFIG_HOME/starship.toml" ] && [ "$FORCE" -eq 0 ]; then
  say "skip  $CONFIG_HOME/starship.toml (exists; use --force to overwrite)"
else
  [ -e "$CONFIG_HOME/starship.toml" ] && cp "$CONFIG_HOME/starship.toml" "$CONFIG_HOME/starship.toml.bak"
  cp "$REPO/starship/starship.toml" "$CONFIG_HOME/starship.toml"
  say "write $CONFIG_HOME/starship.toml"
fi

# 3. state defaults
[ -e "$CONFIG_HOME/starship-theme" ]  || printf 'everforest auto\n' > "$CONFIG_HOME/starship-theme"
[ -e "$CONFIG_HOME/starship-layout" ] || printf 'powerline\n'        > "$CONFIG_HOME/starship-layout"

# 4. .zshrc block (idempotent)
BEGIN="# >>> scytale >>>"
END="# <<< scytale <<<"
if grep -qF "$BEGIN" "$ZSHRC" 2>/dev/null; then
  say "skip  $ZSHRC (block present)"
else
  {
    printf '\n%s\n' "$BEGIN"
    printf 'source "$HOME/.zsh/theme-selector.zsh"\n'
    printf 'source "$HOME/.zsh/starship-theme.zsh"\n'
    printf '%s\n' "$END"
  } >> "$ZSHRC"
  say "write $ZSHRC (block)"
fi

command -v starship >/dev/null 2>&1 || warn "starship not found: https://starship.rs"
command -v python3  >/dev/null 2>&1 || warn "python3 not found: layout switching needs it"
[ -d "$ZSH_HOME/themes/zsh-syntax-highlighting/themes" ] || \
  warn "catppuccin syntax-highlighting themes missing (optional)"

say ""
say "done — restart your shell:  exec zsh"
