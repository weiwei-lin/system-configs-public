# Autocompletion for jj
source <(COMPLETE=zsh jj)

# Echo "jj" or "git" if either is found in $PWD or its parent directories
function pwd_in_jj_or_git() {
  # using the shell is much faster than `git rev-parse --git-dir` or `jj root`
  local D="/$PWD"
  while test -n "$D" ; do
    test -e "$D/.jj" && { echo "jj" ; return; }
    test -e "$D/.git" && { echo "git" ; return; }
    D="${D%/*}"
  done
}

# region Replace git_prompt_info with jj_prompt_info when appropriate

# Print jj repository information
function jj_prompt_info() {
  local jj_or_git="`pwd_in_jj_or_git`"
  if [[ "$jj_or_git" != "jj" ]]; then
    return 0
  fi

  # Get necessary information. Use `--ignore-working-copy` to avoid inspecting $PWD and concurrent
  # snapshotting which could create divergent commits.
  local temp nearest_bookmark short_change_hex full_change_hex is_divergent has_conflict
  temp="`\
    jj --ignore-working-copy --no-pager \
      log --no-graph --color=never \
      -r 'heads(::@ & bookmarks())' \
      -T 'bookmarks' \
  `"
  read -r nearest_bookmark _ <<< "$temp"
  temp="`\
    jj --ignore-working-copy --no-pager \
      log --no-graph --color=never \
      -r @ \
      -T ' \
        separate( \
          " ", \
          change_id.shortest(), \
          change_id.normal_hex(), \
          if(divergent, "Y", "N"), \
          if(conflict, "Y", "N"), \
        ) \
      ' \
  `"
  read -r short_change_hex full_change_hex is_divergent has_conflict <<< "$temp"

  # Construct the most appropriate label.
  local label="%{$fg_bold[blue]%}jj:(%{$fg_bold[red]%}"
  if [[ -n "$nearest_bookmark" ]]; then
    label+="$nearest_bookmark%{$fg_bold[black]%}"
    local distance="`\
      jj --ignore-working-copy --no-pager \
        log --no-graph --color=never \
        -r 'heads(::@ & bookmarks())+::@' \
        -T 'commit_id ++ " \n"' \
      | wc -l \
      | xargs \
    `"
    if [[ "$distance" = 1 ]]; then
      label+="+"
    elif [[ "$distance" -gt 1 ]]; then
      label+="+{$distance}"
    fi
  else
    label+="$short_change_hex"
    hex_suffix_len=7-${#short_change_hex}
    if [[ "$hex_suffix_len" -gt 0 ]]; then
      label+="%{$fg_bold[black]%}${full_change_hex:${#short_change_hex}:$hex_suffix_len}"
    fi

    if [[ "$is_divergent" = Y ]]; then
      label+="%{$fg_bold[yellow]%}??"
    fi
  fi

  label+="%{$fg_bold[blue]%}) "
  if [[ "$has_conflict" = Y ]]; then
    label+="%{$fg_bold[yellow]%}%1{×%} "
  fi

  label+="%{$reset_color%}"
  echo -n $label
}
_omz_register_handler jj_prompt_info

# Print jj repository information asynchronously.
function jj_prompt_info_async() {
  if [[ -n "${_OMZ_ASYNC_OUTPUT[jj_prompt_info]}" ]]; then
    echo -n "${_OMZ_ASYNC_OUTPUT[jj_prompt_info]}"
  fi
}

# Save the original git_prompt_info function
original_git_prompt_info_body=$(typeset -f git_prompt_info | sed '1d;$d')
function original_git_prompt_info() {
  eval "$original_git_prompt_info_body"
}

# Print jj or Git repository information
function jj_or_git_prompt_info() {
  local jj_or_git="`pwd_in_jj_or_git`"
  if [[ "$jj_or_git" = "jj" ]]; then
    jj_prompt_info_async
  elif [[ "$jj_or_git" = "git" ]]; then
    original_git_prompt_info
  fi
}

# Override git_prompt_info to use jj_or_git_prompt_info
function git_prompt_info() {
  jj_or_git_prompt_info
}

# endregion
