#!/bin/bash

# Show a fuzzy-finder TUI for picking new packages to install.

fzf_args=(
  --multi
  --preview '[[ -n "{1}" ]] && zypper info {1}' # apt show, dnf info
  --preview-label='alt-p: toggle description, alt-j/k: scroll, tab: multi-select'
  --preview-label-pos='bottom'
  --preview-window 'down:65%:wrap'
  --bind 'alt-p:toggle-preview'
  --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up'
  --bind 'alt-k:preview-up,alt-j:preview-down'
  --color 'pointer:green,marker:green'
)

# dnf repoquery --all --available --qf "%{name}" | sort -u | fzf
# apt-cache pkgnames | fzf
# pacman -Slq | fzf

pkg_names=$(zypper --quiet search -t package "" | awk -F'|' '/^i/ || /^ / {print $2}' | tr -d ' ' | fzf "${fzf_args[@]}")


if [[ -n "$pkg_names" ]]; then
  # Convert newline-separated selections to space-separated
  echo "$pkg_names" | tr '\n' ' ' | xargs sudo zypper in
fi
