toolkit_paths=(
  ~/.dotnet/tools
  ~/go/bin
  ~/.gem/ruby/3.2.0/bin
  ~/.basher/bin
)

for tp in $toolkit_paths; do
  if [[ -d $tp ]]; then
    path_suffix+=( $tp )
    case $tp in
      *basher/bin)
        export PATH=$PATH:$tp
        # `eval $(basher init - zsh)` fails, no idea why
        basher_init=$(basher init - zsh)
        eval $basher_init
      ;;
    esac
  fi
done
