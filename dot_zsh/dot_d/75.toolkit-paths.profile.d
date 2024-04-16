toolkit_paths=(
  ~/.dotnet/tools
  ~/go/bin
  ~/.gem/ruby/3.2.0/bin
)

for tp in $toolkit_paths; do
  if [[ -d $tp ]]; then
    path_suffix+=( $tp )
  fi
done
