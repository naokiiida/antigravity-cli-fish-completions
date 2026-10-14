# Autoload agy completions and wrap for antigravity alias
if test -f (status dirname)/agy.fish
    source (status dirname)/agy.fish
end
complete -c antigravity -f
complete -c antigravity -w agy
