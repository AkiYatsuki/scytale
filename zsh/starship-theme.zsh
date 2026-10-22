# Scytale — Starship 多主题 palette + 布局切换
#
#   starship-theme                      # 查看当前配色与可用主题
#   starship-theme <family> [mode]      # family: everforest | catppuccin | gruvbox
#                                       # mode:   auto(默认) | light | dark | <flavor>
#   starship-layout                     # 查看当前布局
#   starship-layout <powerline|color|plain|reload>
#
# 配色选择持久化到 ~/.config/starship-theme，布局选择到 ~/.config/starship-layout；
# precmd 时同步到 starship.toml。zsh-syntax-highlighting 读同一个配色状态文件，
# 所以提示符和高亮永远一致。

STARSHIP_CONFIG_FILE="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"
STARSHIP_THEME_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/starship-theme"
STARSHIP_LAYOUT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/starship-layout"
# 本文件位于 <repo>/zsh/，布局文件位于 <repo>/starship/layouts/
STARSHIP_FORMAT_DIR="${0:A:h:h}/starship/layouts"

# 家族 → 浅色 palette : 深色 palette（auto 模式用）
typeset -gA _STARSHIP_THEME_FAMILIES
_STARSHIP_THEME_FAMILIES=(
  everforest "everforest_light:everforest_dark"
  catppuccin "catppuccin_latte:catppuccin_mocha"
  gruvbox    "gruvbox_light:gruvbox_dark"
)

_starship_palette_exists() {
  [[ -n "$1" ]] && grep -qE "^\[palettes\.${1}\]" "$STARSHIP_CONFIG_FILE" 2>/dev/null
}

_starship_flavors() {
  sed -nE "s/^\[palettes\.${1}_([a-z0-9]+)\]/\1/p" "$STARSHIP_CONFIG_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
}

_starship_read_choice() {
  local family mode
  if [[ -r "$STARSHIP_THEME_FILE" ]]; then
    read -r family mode < "$STARSHIP_THEME_FILE"
  fi
  print -r -- "${family:-everforest} ${mode:-auto}"
}

_starship_is_dark() {
  [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]
}

# 把 "<family> <mode>" 解析成实际的 palette 名
_starship_resolve_palette() {
  local choice family mode pair light dark
  choice="$(_starship_read_choice)"
  family="${choice%% *}"
  mode="${choice#* }"

  pair="${_STARSHIP_THEME_FAMILIES[$family]}"
  if [[ -z "$pair" ]]; then
    print -u2 "starship-theme: 未知主题家族 '$family'（可用: ${(k)_STARSHIP_THEME_FAMILIES}）"
    return 1
  fi
  light="${pair%%:*}"
  dark="${pair##*:}"

  case "$mode" in
    auto) if _starship_is_dark; then print -r -- "$dark"; else print -r -- "$light"; fi ;;
    light) print -r -- "$light" ;;
    dark) print -r -- "$dark" ;;
    *)
      if _starship_palette_exists "${family}_${mode}"; then
        print -r -- "${family}_${mode}"
      else
        print -u2 "starship-theme: '$family' 没有 '$mode'（可用: auto $(_starship_flavors "$family")）"
        return 1
      fi
      ;;
  esac
}

_starship_read_layout() {
  local layout
  if [[ -r "$STARSHIP_LAYOUT_FILE" ]]; then
    read -r layout < "$STARSHIP_LAYOUT_FILE"
  fi
  case "$layout" in
    powerline|color|plain) print -r -- "$layout" ;;
    *) print -r -- powerline ;;
  esac
}

# 用 starship/layouts/<layout>.toml 替换 config 里的 "# layout: xxx\nformat = """...""""
_starship_sync_layout() {
  local want current fmt_file force="$1"
  want="$(_starship_read_layout)"
  current="$(sed -nE 's/^# layout: (powerline|color|plain)$/\1/p' "$STARSHIP_CONFIG_FILE" | head -n1)"
  [[ -z "$force" && "$current" == "$want" ]] && return 0

  fmt_file="$STARSHIP_FORMAT_DIR/$want.toml"
  [[ -r "$fmt_file" ]] || { print -u2 "starship-layout: 缺少 $fmt_file"; return 0 }

  python3 - "$STARSHIP_CONFIG_FILE" "$fmt_file" <<'PY'
import pathlib, re, sys

cfg, fmt = sys.argv[1], sys.argv[2]
src = pathlib.Path(cfg).read_text()
block = pathlib.Path(fmt).read_text().rstrip() + "\n"
out, n = re.subn(r'(?ms)^# layout: \w+\nformat = """.*?"""\n', block, src, count=1)
if n != 1:
    sys.exit("找不到可替换的 format 块")
pathlib.Path(cfg).write_text(out)
PY
  [[ $? -eq 0 ]] || print -u2 "starship-layout: 替换 format 失败"
}

_starship_sync_palette() {
  [[ -r "$STARSHIP_CONFIG_FILE" ]] || return 0

  local current want
  current="$(sed -nE 's/^palette *= *"([^"]+)".*/\1/p' "$STARSHIP_CONFIG_FILE" | head -n1)"
  want="$(_starship_resolve_palette)" || return 0

  if [[ -n "$want" && "$current" != "$want" ]]; then
    if _starship_palette_exists "$want"; then
      sed -i '' -E "s|^palette *= *\"[^\"]+\"|palette = \"$want\"|" "$STARSHIP_CONFIG_FILE"
      # starship 颜色变了，顺带让 zsh-syntax-highlighting 跟着切
      (( $+functions[_zsh_highlighting_select_theme] )) && _zsh_highlighting_select_theme
    else
      print -u2 "starship-theme: $STARSHIP_CONFIG_FILE 缺少 [palettes.$want]，跳过"
    fi
  fi

  _starship_sync_layout
}

starship-theme() {
  local family="$1" mode="${2:-auto}"

  if [[ -z "$family" || "$family" == (list|ls|-l|--list|help|-h|--help) ]]; then
    local choice family0 mode0 resolved
    choice="$(_starship_read_choice)"
    family0="${choice%% *}"; mode0="${choice#* }"
    if resolved="$(_starship_resolve_palette)"; then
      print "当前配色: ${family0} ${mode0} → ${resolved}"
    else
      print -u2 "当前配色: ${family0} ${mode0}（无效）"
    fi
    print "当前布局: $(_starship_read_layout)（starship-layout 切换）"
    print "可用主题:"
    local f pair
    for f in ${(ok)_STARSHIP_THEME_FAMILIES}; do
      pair="${_STARSHIP_THEME_FAMILIES[$f]}"
      print "  ${f}  浅=${pair%%:*}  深=${pair##*:}  ($(_starship_flavors "$f") | auto light dark)"
    done
    print "用法: starship-theme <family> [auto|light|dark|<flavor>]"
    return 0
  fi

  if [[ -z "${_STARSHIP_THEME_FAMILIES[$family]}" ]]; then
    print -u2 "starship-theme: 未知主题家族 '$family'（可用: ${(k)_STARSHIP_THEME_FAMILIES}）"
    return 1
  fi

  case "$mode" in
    auto|light|dark) ;;
    *)
      if ! _starship_palette_exists "${family}_${mode}"; then
        print -u2 "starship-theme: '$family' 没有 '$mode'（可用: auto $(_starship_flavors "$family")）"
        return 1
      fi
      ;;
  esac

  print -r -- "$family $mode" > "$STARSHIP_THEME_FILE"
  _starship_sync_palette
  print "已切换: $family $mode → $(_starship_resolve_palette)"
}

starship-layout() {
  local want="$1"

  if [[ -z "$want" || "$want" == (list|ls|-l|--list|help|-h|--help) ]]; then
    print "当前布局: $(_starship_read_layout)"
    print "可用布局:"
    print "  powerline  色块 + 箭头（默认）"
    print "  color      只给文字上色，无背景"
    print "  plain      纯色文字，无强调色"
    print "用法: starship-layout <powerline|color|plain|reload>"
    return 0
  fi

  if [[ "$want" == "reload" ]]; then
    _starship_sync_layout force
    print "已重新渲染布局: $(_starship_read_layout)"
    return 0
  fi

  case "$want" in
    powerline|color|plain) ;;
    *)
      print -u2 "starship-layout: 未知布局 '$want'（可用: powerline color plain）"
      return 1
      ;;
  esac

  print -r -- "$want" > "$STARSHIP_LAYOUT_FILE"
  _starship_sync_layout
  print "已切换布局: $want"
}

autoload -Uz add-zsh-hook
add-zsh-hook -d precmd _starship_sync_palette 2>/dev/null
add-zsh-hook precmd _starship_sync_palette
_starship_sync_palette
