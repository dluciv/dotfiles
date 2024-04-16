toolkit_paths = (
  ~/.dotnet/tools
  ~/go/bin
  ~/.gem/ruby/3.0.0/bin
)

for tp in $toolkint_paths; do
  if [[ -d $tp ]]; then
    path_suffix+=( $tp )
  fi
done
