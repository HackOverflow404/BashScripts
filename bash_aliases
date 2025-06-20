alias cat="batcat"
alias locate="sudo updatedb; locate"
alias clear="clear && figlet -tckf slant 'Hack Overflow'"
alias get_idf='. /home/d4rkc10ud/esp/esp-idf/export.sh'
alias copy='xclip -sel c <'
alias rwp='code ~/Documents/Projects/RemoteWebcam && exit'
alias stop-apparmor='sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0'
alias docker-start='stop-apparmor && systemctl --user restart docker-desktop'
alias cs225='docker-start && code ~/Documents/School/UIUC/CS225 && exit'
alias cdp='cd ~/Documents/Projects/'
alias rupd='cd ~/Documents/Projects/fetch-resume/ && node index.js && cd -'
