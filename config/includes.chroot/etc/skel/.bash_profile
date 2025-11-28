# Autostart sway for the live user on tty1
if [ -z "${DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = "1" ] && command -v sway >/dev/null 2>&1; then
  export XDG_SESSION_TYPE=wayland
  export XDG_CURRENT_DESKTOP=sway
  export WLR_RENDERER_ALLOW_SOFTWARE=1
  exec sway
fi

# Fallback to default bash profile behavior
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
