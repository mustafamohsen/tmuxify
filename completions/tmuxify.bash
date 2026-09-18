# bash completion for tmuxify

_tmuxify_completion_options() {
  tmuxify --completion-options 2>/dev/null
}

_tmuxify_option_words() {
  _tmuxify_completion_options | tr '|:' '\n' | grep '^-'
}

_tmuxify_argument_options() {
  _tmuxify_completion_options | awk -F: -v kind="$1" '$2 == kind { print $1 }' | tr '|' '\n'
}

_tmuxify() {
  local cur prev opts file_opts directory_opts candidate
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  opts=$(_tmuxify_option_words)
  file_opts=$(_tmuxify_argument_options file)
  directory_opts=$(_tmuxify_argument_options directory)

  if printf '%s\n' "$directory_opts" | grep -Fxq -- "$prev"; then
    while IFS= read -r candidate; do
      COMPREPLY+=("$candidate")
    done < <(compgen -d -- "$cur")
    return 0
  fi

  if printf '%s\n' "$file_opts" | grep -Fxq -- "$prev"; then
    while IFS= read -r candidate; do
      COMPREPLY+=("$candidate")
    done < <(compgen -f -- "$cur")
    return 0
  fi

  if [[ $cur == -* ]]; then
    while IFS= read -r candidate; do
      COMPREPLY+=("$candidate")
    done < <(compgen -W "$opts" -- "$cur")
  fi
}

complete -F _tmuxify tmuxify
