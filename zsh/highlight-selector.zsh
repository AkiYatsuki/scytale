# Scytale — 给 zsh-syntax-highlighting 加载与 starship 一致的主题
#
# 与 starship-theme.zsh 共用 ~/.config/starship-theme（内容 "<family> <mode>"）
# family: everforest | catppuccin | nord
# mode:   auto | light | dark | <flavor>
#
# 查找顺序（本仓库主题优先，其次上游 catppuccin 仓库）：
#   <repo>/themes/<family>-<mode>.zsh
#   <repo>/themes/<family>.zsh
#   $ZSH_HL_UPSTREAM/<family>_<mode>-zsh-syntax-highlighting.zsh
#   $ZSH_HL_UPSTREAM/<family>-<mode>-zsh-syntax-highlighting.zsh
#
# 上游默认位置：~/.zsh/themes/zsh-syntax-highlighting/themes
# （git clone https://github.com/catppuccin/zsh-syntax-highlighting）

_zsh_hl_themes="${0:A:h:h}/themes"
_zsh_hl_upstream="${ZSH_HL_UPSTREAM:-$HOME/.zsh/themes/zsh-syntax-highlighting/themes}"
_zsh_hl_state="${XDG_CONFIG_HOME:-$HOME/.config}/starship-theme"

_zsh_hl_is_dark() {
    [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]
}

_zsh_hl_resolve() {
    local family mode
    if [[ -r "$_zsh_hl_state" ]]; then
        read -r family mode < "$_zsh_hl_state"
    fi
    family="${family:-everforest}"
    mode="${mode:-auto}"

    if [[ "$mode" == "auto" ]]; then
        if _zsh_hl_is_dark; then mode=dark; else mode=light; fi
    fi

    # catppuccin 没有 light/dark 文件，映射到 latte/mocha
    if [[ "$family" == "catppuccin" ]]; then
        case "$mode" in
            light) mode=latte ;;
            dark)  mode=mocha ;;
        esac
    fi

    print -r -- "$family $mode"
}

_zsh_hl_file() {
    local family="$1" mode="$2" f
    local -a candidates=(
        "$_zsh_hl_themes/${family}-${mode}.zsh"
        "$_zsh_hl_themes/${family}.zsh"
        "$_zsh_hl_upstream/${family}_${mode}-zsh-syntax-highlighting.zsh"
        "$_zsh_hl_upstream/${family}-${mode}-zsh-syntax-highlighting.zsh"
    )
    for f in "${candidates[@]}"; do
        # -s：空文件视为不可用，避免清空现有样式
        [[ -s "$f" ]] && { print -r -- "$f"; return 0 }
    done
    return 1
}

_zsh_highlighting_select_theme() {
    local choice family mode file
    choice="$(_zsh_hl_resolve)"
    family="${choice%% *}"
    mode="${choice#* }"

    if ! file="$(_zsh_hl_file "$family" "$mode")"; then
        print -u2 "zsh-highlight: 没有 ${family}/${mode} 对应的高亮主题，保持现状"
        return 1
    fi

    # 清空旧键，避免切换主题后残留
    typeset -gA ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_STYLES=()
    source "$file"
}

_catppuccin_select_theme() { _zsh_highlighting_select_theme }

_zsh_highlighting_select_theme
