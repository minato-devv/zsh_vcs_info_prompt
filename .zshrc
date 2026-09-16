setopt prompt_subst

autoload -Uz vcs_info 
add-zsh-hook precmd vcs_info

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' formats ' %m'
zstyle ':vcs_info:*' actionformats ' %m (%a)'

+vi-git-format-array() {
	local -a git_items git_aheadbehind
	git_items+=("${hook_com[branch]}")
	local ahead_count behind_count untracked_count staged_count unstaged_count

	ahead_count="$(git rev-list --count @{upstream}..HEAD 2>/dev/null)"
	behind_count="$(git rev-list --count HEAD..@{upstream} 2>/dev/null)"
	[[ $ahead_count -gt 0 ]] && git_aheadbehind+=("↑${ahead_count}")
	[[ $behind_count -gt 0 ]] && git_aheadbehind+=("↓${behind_count}")
	[[ -n "${git_aheadbehind}" ]] && git_items+=("${(j::)git_aheadbehind}")

	staged_count="$(git diff --cached --numstat | wc -l | tr -d ' ')"
	unstaged_count="$(git diff --name-only | wc -l | tr -d ' ')"
	[[ "${staged_count}" -gt 0 ]] && git_items+=("+${staged_count}")
	[[ "${unstaged_count}" -gt 0 ]] && git_items+=("*${unstaged_count}")

	untracked_count="$(git status --porcelain | /usr/bin/grep -c '??')"
	[[ $untracked_count -gt 0 ]] && git_items+=("?${untracked_count}")

	hook_com[misc]="⎇ ${(j: :)git_items}"
}
zstyle ':vcs_info:git*+post-backend:*' hooks git-format-array

export PROMPT='%n@%m %1~${vcs_info_msg_0_} %# '
