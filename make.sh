#!/bin/bash

logfile="log.install.log"

install() {
    if ! whoami | grep -iq '^root'; then
        echo "requires root access to install packages"
        exit
    fi
    rm -f "$logfile" && touch "$logfile"
    logdo "instantOS Installation Begin"
    # Tasks
    {
        download aptPackages
        compile instantOSPackages
    } |& echo_progess
}

download() {
    while ! logdo Download "$@"
    do
        echo "[instantOS][Error: downloading packages failed, please reconnect to internet]"
        sleep 10
    done
}

compile() {
    while ! logdo Compile "$@"
    do
        echo "[instantOS][Error: fail to process instantOS package file, please review $logfile]"
        sleep 10
    done
}

aptPackages() {
    apt install -y fzf expect git os-prober dialog imvirt lshw bash curl python3-tqdm
    apt install -y dunst lxpolkit xdotool compton lightdm
    apt install -y mpv mpd mpc slop maim mupdf xwallpaper #muti-media
    apt install -y scite # gui super lightweight gui text editor (alt. featherpad)
    apt install -y fcitx fcitx-libpinyin # input method framework
    apt install -y build-essential libx11-dev xorg-dev # build tools for windows manager
}

instantOSPackages() {
      git submodule update --init --recursive
      cd-do instawm/ make install -j$(nproc)
      cd-do instantDEB/ cp -r usr /usr
      cd-do instantDEB/ cp -r etc /etc
}

cd-do() {
    cd "$1"
    shift 1
    "$@"
    cd - >& /dev/null
}

# read from stdin
echo_progess() {
    if command -v tqdm >& /dev/null ; then
        # tqdm --total 12 --desc "${input}\nProgress" > /dev/null
        python3 <(cat <<EOF
from tqdm import tqdm
import time
import fileinput
t = tqdm(fileinput.input(), desc="Progress", total=2)
for text in t:
    if text.startswith('[instantOS]'):
        t.write(text.strip())
EOF
)
    else
        xargs -l1 echo
    fi
}

# log and does the operation
# log description cmd/function
logdo() {
    local -r desc="$1"
    shift 1
    local -r cmd="$@"
    local -r message=$(echo [instantOS][$(date -I)-$(date +"%T.%3N")] "$desc" "$cmd")
    echo -n "$message" | tee -a "$logfile" ; echo >> "$logfile"
    if test ! -z "$cmd"
    then
        "$cmd" >> $logfile 2>&1  &
        local -r pid="$!"
        spinner "$pid"
        echo
        wait "$pid" #capture exit code
        return $?
    else
        echo
    fi
}

spinner() {
    local spin="/|\\-/|\\-"
    local i=0
    tput civis # cursor invisible
    while kill -0 "$1" 2>/dev/null
    do
        local i=$(((i+1) % ${#spin}))
        printf "%s" "${spin:$i:1}"
        printf "\b"
        sleep .1
    done
    printf "\b ..."
    tput cnorm
}

restoreState() {
    tput cnorm
}

trap restoreState EXIT

"$@"
