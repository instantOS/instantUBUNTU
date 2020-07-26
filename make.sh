#!/bin/bash

logfile="log.install.log"

install() {
    if ! whoami | grep -iq '^root'; then
        echo "requires root access to install packages"
        exit
    fi
    logdo echo "instantOS Installation Begin"
    {

        logdo download aptPackages
        logdo download instantOSPackages
        logdo compile

    } |& echo_progess
}

download() {
    while ! "$@"
    do
        echo "[Info][downloading packages failed, please reconnect to internet]"
        sleep 10
    done
}

aptPackages() {
    apt install -y fzf expect git os-prober dialog imvirt lshw bash curl python3-tqdm
    apt install -y mpv mpd mpc slop maim mupdf xwallpaper #muti-media
    apt install -y scite # gui super lightweight gui text editor (alt. featherpad)
    apt install -y fcitx fcitx-libpinyin # input method framework
    apt install -y build-essential libx11-dev xorg-dev # build tools for windows manager
}

instantOSPackages() {
      git submodule update --init --recursive
      # cp instantOS/imenu.sh /usr/bin/imenu
      # chmod 755 /usr/bin/imenu
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
    if text.startswith('[Info]'):
        t.write(text.strip())
EOF
)
    else
        xargs -l1 echo
    fi
}

# log and does the operation
# log cmd/function
logdo() {
    if test "$1" != echo
    then
        local -r message=$(echo [Info][$(date -I)-$(date +"%T.%3N")] "$@")
        echo -n "$message" | tee -a "$logfile" ; echo >> "$logfile"
        "$@" |& tee -a $logfile &
        local -r pid="$!"
        spinner "$pid"
        echo
        wait "$pid" #capture exit code
        return $?
    else
        shift 1
        local -r message=$(echo [Info][$(date -I).$(date +"%T.%3N")] "$@")
        echo "$message" | tee "$logfile"
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
    printf "\b... Done"
    tput cnorm
}

restoreState() {
    tput cnorm
}

trap restoreState EXIT

"$@"
