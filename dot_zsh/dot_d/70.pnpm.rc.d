if command -v pnpm 1>/dev/null; then

  export PNPM_HOME="${XDG_DATA_HOME}/pnpm"
  export PATH=$PATH:$PNPM_HOME

fi
