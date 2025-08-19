### Issue:
ansible LSP will not load or recognize filetypes properly in neovim

### Cause:
usually due to recognized LSP filetype extension missing in file name, LSP looks for 'yaml.ansible'

### Resolution:
`mkdir -p ~/.config/nvim/ftdetect/ansible.vim` and add these lines{

    au BufRead,BufNewFile */playbooks/*.yml setlocal ft=yaml.ansible
    au BufRead,BufNewFile */playbooks/*.yaml setlocal ft=yaml.ansible
    au BufRead,BufNewFile */roles/*/tasks/*.yml setlocal ft=yaml.ansible
    au BufRead,BufNewFile */roles/*/tasks/*.yaml setlocal ft=yaml.ansible
    au BufRead,BufNewFile */roles/*/handlers/*.yml setlocal ft=yaml.ansible
    au BufRead,BufNewFile */roles/*/handlers/*.yaml setlocal ft=yaml.ansible
}

### Supporting material:
https://ansible.readthedocs.io/projects/vscode-ansible/#without-file-inspection

https://www.reddit.com/r/neovim/comments/15txftn/need_help_to_enable_ansible_lsp_dont_want_to_use/
