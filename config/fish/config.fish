if status is-interactive
    # Disable welcome message
    set -g fish_greeting

    # White prompt colors
    set -g fish_color_user white
    set -g fish_color_host white
    set -g fish_color_host_remote white
    set -g fish_color_cwd white
end

if test "$TERM" = "xterm-kitty"
    set -gx TERM xterm-256color
end
