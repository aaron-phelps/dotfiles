if status is-interactive
    # Commands to run in interactive sessions can go here
end
if test "$TERM" = "xterm-kitty"
    set -gx TERM xterm-256color
end
