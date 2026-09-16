setopt prompt_subst # allow variable substitution in the prompt

autoload -Uz vcs_info # register vcs_info for zsh to lazy load
add-zsh-hook precmd vcs_info # add vcs_info to native zsh hook; precmd executes after carriage return but before the command executes

zstyle ':vcs_info:*' enable git # use git version control system
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' formats ' %m' # use the miscellaneous array to display customized data
zstyle ':vcs_info:*' actionformats ' %m (%a)' # appearance when actions are available	

+vi-git-format-array() {
	local -a git_items git_aheadbehind # declare an array to store all info (added to miscellaneous array in the end) and an array to store both ahead and behind commit status
	git_items+=("${hook_com[branch]}") # include branch name
	local ahead_count behind_count untracked_count staged_count unstaged_count # declare vars that will store integers

	ahead_count="$(git rev-list --count @{upstream}..HEAD 2>/dev/null)"
	behind_count="$(git rev-list --count HEAD..@{upstream} 2>/dev/null)"
	[[ $ahead_count -gt 0 ]] && git_aheadbehind+=("↑${ahead_count}") # if ahead count is positive, add to the array
	[[ $behind_count -gt 0 ]] && git_aheadbehind+=("↓${behind_count}") # if behind count is positive, add to the array
	[[ -n "${git_aheadbehind}" ]] && git_items+=("${(j::)git_aheadbehind}") # finally, add ahead/behind data to array storing all info

	staged_count="$(git diff --cached --numstat | wc -l | tr -d ' ')"
	unstaged_count="$(git diff --name-only | wc -l | tr -d ' ')"
	[[ "${staged_count}" -gt 0 ]] && git_items+=("+${staged_count}") # same pattern previous
	[[ "${unstaged_count}" -gt 0 ]] && git_items+=("*${unstaged_count}") # same pattern as previous

	untracked_count="$(git status --porcelain | /usr/bin/grep -c '??')"
	[[ $untracked_count -gt 0 ]] && git_items+=("?${untracked_count}") # same pattern as previous

	hook_com[misc]="⎇ ${(j: :)git_items}" # finally, define vcs_info misc array holding all contextual information
}
zstyle ':vcs_info:git*+post-backend:*' hooks git-format-array # register custom hook to post-backend

export PROMPT='%n@%m %1~${vcs_info_msg_0_} %# ' # append the the information to display in the default prompt
