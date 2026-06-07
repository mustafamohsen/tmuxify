# bash completion for tmuxify

_tmuxify_completion_options() {
  tmuxify --completion-options 2>/dev/null
}

_tmuxify_option_words() {
  _tmuxify_completion_options | tr '|:' '\n' | grep '^-'
}

_tmuxify_file_options() {
  _tmuxify_completion_options | awk -F: '$2 == "file" { print $1 }' | tr '|' '\n'
}

_tmuxify() {
  local cur prev opts file_opts
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  opts=$(_tmuxify_option_words)
  file_opts=$(_tmuxify_file_options)

  if printf '%s\n' "$file_opts" | grep -Fxq -- "$prev"; then
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    return 0
  fi

  if [[ $cur == -* ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
  fi
}

complete -F _tmuxify tmuxify
