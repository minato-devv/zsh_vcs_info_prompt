# `.zshrc` — zsh_vcs_info_prompt: Formal Documentation

## Overview

This `.zshrc` snippet configures a **Git-aware Zsh prompt** using Zsh's built-in `vcs_info` framework. It augments the standard version-control information with a custom formatting hook that reports branch divergence (ahead/behind), staged/unstaged/staged changes, and untracked files — all rendered inline in the shell prompt.

---

## Components

### 1. Prompt Substitution

```
setopt prompt_subst
```

Enables variable and command substitution inside prompt strings. Without this, `${vcs_info_msg_0_}` would be rendered literally rather than evaluated each time the prompt is drawn.

---

### 2. vcs_info Registration & Hook Wiring

```
autoload -Uz vcs_info
add-zsh-hook precmd vcs_info
```

- **`autoload -Uz vcs_info`** — lazy-loads the `vcs_info` function (Zsh's VCS abstraction layer) on first use. The `-U` flag suppresses alias expansion; `-z` enforces Zsh context.
- **`add-zsh-hook precmd vcs_info`** — registers `vcs_info` as a `precmd` hook. `precmd` runs after the previous command finishes (after carriage return) but before the next prompt is drawn, ensuring VCS state is fresh for every prompt redraw.

---

### 3. vcs_info Style Configuration

```
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' formats ' %m'
zstyle ':vcs_info:*' actionformats ' %m (%a)'
```

| Style | Scope | Effect |
|---|---|---|
| `enable git` | `:vcs_info:*` | Restricts `vcs_info` to Git repositories only. |
| `check-for-changes true` | `:vcs_info:*` | Tells `vcs_info` to inspect the working tree for uncommitted changes (needed so the hook fires with accurate state). |
| `formats ' %m'` | `:vcs_info:*` | Default format string: `%m` expands to the `misc` array (populated by the custom hook). The leading space is cosmetic padding. |
| `actionformats ' %m (%a)'` | `:vcs_info:*` | Format used when a VCS action is in progress (e.g., rebase, merge, cherry-pick). `%a` expands to the action name. |

---

### 4. Custom VCS Format Hook: `+vi-git-format-array`

```
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
```

#### Hook Registration

The function is wired via:

```
zstyle ':vcs_info:git*+post-backend:*' hooks git-format-array
```

This registers `git-format-array` (the `+vi-` prefix is conventional for `vcs_info` hooks; the style key omits the prefix) as a **post-backend hook** for Git. The hook fires after `vcs_info` has gathered raw backend data, allowing it to enrich `hook_com[misc]` before the format string is applied.

#### What the Hook Computes

The function builds a space-separated string assigned to `hook_com[misc]` (which `%m` in the format string expands to). It proceeds in four stages:

**a. Branch name** — always included as the first element:

```
git_items+=("${hook_com[branch]}")
```

`hook_com[branch]` is provided by `vcs_info`'s built-in Git backend.

**b. Ahead/behind divergence** — compared against `@{upstream}`:

```
ahead_count = git rev-list --count @{upstream}..HEAD
behind_count = git rev-list --count HEAD..@{upstream}
```

- `↑N` appended if ahead by N commits.
- `↓N` appended if behind by N commits.
- Both are joined with no separator (`${(j::)git_aheadbehind}`) and added as a single element if either is non-zero.

**c. Staged and unstaged changes:**

```
staged_count  = git diff --cached --numstat | wc -l   # lines changed in index
unstaged_count = git diff --name-only | wc -l          # files with unstaged diffs
```

- `+N` for N staged entries.
- `*N` for N unstaged entries.

**d. Untracked files:**

```
untracked_count = git status --porcelain | grep -c '??'
```

- `?N` for N untracked files (lines starting with `??` in porcelain output).

#### Final Assembly

```
hook_com[misc]="⎇ ${(j: :)git_items}"
```

All elements in `git_items` are joined with a single space and prefixed with the `⎇` (U+2382, "Bell" symbol in some fonts, used here as a VCS indicator glyph). The result looks like:

```
⎇ main ↑3 +2 *1 ?4
```

Meaning: on branch `main`, 3 commits ahead of upstream, 2 staged, 1 unstaged, 4 untracked.

---

### 5. Prompt Definition

```
export PROMPT='%n@%m %1~${vcs_info_msg_0_} %# '
```

| Token | Expansion |
|---|---|
| `%n` | Current user name |
| `%m` | Hostname (short form) |
| `%1~` | Current working directory, truncated to one level depth (e.g., `~/dev` instead of `~/dev/project/src`) |
| `${vcs_info_msg_0_}` | First element of `vcs_info`'s message array — here, the `misc` string produced by the custom hook |
| `%#` | `#` if privileged (root), `%` otherwise |

The `${vcs_info_msg_0_}` substitution works because `setopt prompt_subst` is active and `vcs_info` populates `vcs_info_msg_0_` during the `precmd` phase.

---

## Data Flow

```
precmd hook fires
  → vcs_info runs Git backend
    → post-backend hook (+vi-git-format-array) executes
      → queries git for ahead/behind, staged, unstaged, untracked counts
      → assembles git_items array
      → writes to hook_com[misc]
    → vcs_info applies format string (%m) → vcs_info_msg_0_
  → prompt redrawn with ${vcs_info_msg_0_} interpolated
```

---

## Symbolic Legend

| Symbol | Meaning |
|---|---|
| `⎇` | VCS indicator prefix (rendered before all status items) |
| `↑N` | N commits ahead of upstream tracking branch |
| `↓N` | N commits behind upstream tracking branch |
| `+N` | N files staged in the index |
| `*N` | N files with unstaged changes |
| `?N` | N untracked files |

---

## Requirements & Compatibility

- **Zsh** with `vcs_info` (standard in modern distributions).
- **Git** available on `PATH`.
- **`/usr/bin/grep`** — the hook hardcodes the path for `grep -c`; on systems where `grep` lives elsewhere this will break. Consider using just `grep` or `command grep`.
- **`rev-list`, `diff`, `status`** — standard Git plumbing commands; no exotic flags.

---

## Possible Extensions / Known Limitations

1. **Hardcoded `/usr/bin/grep`** — portability hazard; should use `grep` without absolute path or `command grep`.
2. **No error suppression on `git diff --cached --numstat`** — if not in a Git repo or if the repo is corrupted, the hook may emit stderr visibly. The ahead/behind queries use `2>/dev/null` but the diff/status queries do not.
3. **`wc -l | tr -d ' '`** — used to strip whitespace from `wc` output; `wc -l < file` or `git diff --cached --numstat | wc -l` may leave leading spaces on some systems.
4. **Performance** — four separate Git invocations per prompt redraw (rev-list twice, diff twice, status once). For large repos this could add measurable latency. Consider caching or reducing frequency.
5. **No handling of detached HEAD** — `hook_com[branch]` may be empty or show a commit hash; the hook doesn't special-case this.
6. **Action formats** — the `actionformats` style includes `(%a)` but the custom hook does not add action-specific data; it just reuses the same `misc` output.

---

## Summary

This is a self-contained, single-file Git prompt enhancement for Zsh. It uses `vcs_info`'s hook system to inject a custom, information-dense status string into the prompt, showing branch, upstream divergence, and working-tree cleanliness in a single glyph-prefixed token. The design follows Zsh conventions (`+vi-` prefix, `hook_com[misc]`, `precmd` hook) and is intended to be sourced from `.zshrc`.