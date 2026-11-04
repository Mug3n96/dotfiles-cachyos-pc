# Git für die Dotfiles. Die Dateien liegen an ihrem normalen Ort, das Repo in ~/.dotfiles.
#   dotfiles status                          was hat sich geändert
#   dotfiles add ~/.config/waybar/style.css  Datei aufnehmen
#   dotfiles commit -m "…" && dotfiles push
function dotfiles --wraps git --description 'Git für die Dotfiles (Bare-Repo ~/.dotfiles)'
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
end
