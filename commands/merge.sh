#!/bin/bash
source "$GMP_DIR/shared.sh"

merge() {
  _git_check_clean_state || { echo "Your branch has uncommitted changes or is in rebase. Cancelling."; return 1; }

  local commits="$(_git_get_commits --reverse)"
  local IFS=$'\n' commits_array=($commits)
  local commit="${commits_array[0]}"

  local pr_number="$(_get_ref_pr_number "$commit")"
  local sha="$(_get_sha_in_local_queue "$commit")"
  local title="$(_git_get_commit_subject "$commit")"

  echo
  echo "${bold}Merging onto origin/$master oldest PR #$pr_number ($sha): $title${normal}"

  echo "If this is not the PR what you want to merge, then use \`$cmd edit\` to reorder your local history, or \`$cmd sync\` to sync your local queue."
  echo "${bold}Do you want to merge PR #$pr_number ($sha)? [yes/NO]:${normal} "
  read prompt

  case "$(echo "$prompt" | tr a-z A-Z)" in
    y | Y | yes | YES)
      if ! _is_all_changes_exported "$commit"; then
        echo "Unexported changes detected. You should first run \`$cmd export\` before you merge this PR."

        while true; do
          echo "${bold}Do you want to merge this PR as-is? [yes/diff/NO]:${normal} "
          read prompt

          case "$(echo "$prompt" | tr a-z A-Z)" in
            Y | YES)
              break
              ;;
            D | DIFF)
              _print_unexported_changes "$commit"
              ;;
            *)
              echo "Merge cancelled. Exiting."
              exit 1
              ;;
          esac
        done
      fi

      if [[ "${#commits_array[@]}" -ge 2 ]]; then
        local next_ref="${commits_array[1]}"
        _ensure_ref_pr_open "origin/$master" "$next_ref"
      fi

      local repo_org="$(_get_repo_org)"
      local repo_name="$(_get_repo_name)"
      local pr_url="$(_get_ref_pr_url "$commit")"

      echo "> $oksh add_comment \"$repo_org/$repo_name\" \"$pr_number\" \":unlock: Merging via \`$cmd merge\`\""
      $oksh add_comment "$repo_org/$repo_name" "$pr_number" ":unlock: Merging via \`$cmd merge\`"

      echo "> $oksh add_comment \"$repo_org/$repo_name\" \"$pr_number\" \":dash:\""
      $oksh add_comment "$repo_org/$repo_name" "$pr_number" ":dash:"

      echo "Check ${underline}$pr_url${normal} for the status on your merge."
      echo "When it is merged into master, sync your local queue with \`$cmd sync\`."
      echo "Any subsequent PRs will have invalid diffs until you export again with \`$cmd export\`."
      ;;
    *)
      echo "Merge cancelled. Exiting."
      exit 1
      ;;
  esac
}

_is_all_changes_exported() {
  local commit="$1"

  local branch="$(_git_get_branch)"
  local ref_branch="$(_get_ref_branch_name "$commit")"

  git checkout "$ref_branch" &>/dev/null

  git merge "origin/$master" --no-edit  &>/dev/null
  git diff --exit-code "$ref_branch".."$commit" &>/dev/null
  local retval="$?"

  git checkout "$branch" &>/dev/null

  return "$retval"
}

_print_unexported_changes() {
  local commit="$1"
  local ref_branch="$(_get_ref_branch_name "$commit")"

  git diff "$ref_branch".."$commit"
}
