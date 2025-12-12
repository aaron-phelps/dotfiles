if status is-interactive
    # Disable welcome message
    set -g fish_greeting
end

if test "$TERM" = "xterm-kitty"
    set -gx TERM xterm-256color
end
