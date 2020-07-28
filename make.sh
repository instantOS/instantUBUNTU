#!/bin/bash

logfile="log.install.log"

install() {
    if ! whoami | grep -iq '^root'; then
        echo "requires root access to install packages"
        exit
    fi
    rm -f "$logfile" && touch "$logfile"
    logdo "Installation Begin @ $(date -I)-$(date +"%T.%3N")"
    # Tasks
    {
        download bootstrap
        download download-tools
        download media-player
        download text-editor
        download input-method
        download build-tools
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

bootstrap() {
    apt update
    # apt install python3-tqdm
    pip3 install -U 'git+https://github.com/tqdm/tqdm@cli-tee#egg=tqdm'
}

aptPackages() {
    apt install -y fzf expect git os-prober dialog imvirt lshw bash curl
    apt install -y dunst lxpolkit xdotool compton lightdm
}

media-player() {
    apt install -y mpv mpd mpc slop maim mupdf xwallpaper #muti-media
}

text-editor() {
    apt install vim
    apt install -y scite # gui super lightweight gui text editor (alt. featherpad)
}

input-method() {
    apt install -y fcitx fcitx-libpinyin # input method framework
}

download-tools() {
    apt install curl wget
}

build-tools() {
    # for tools need be compiled from sources (e.g. windows manager)
    apt install -y build-essential libx11-dev xorg-dev
    apt install -y libimlib2-dev
}

instantOSPackages() {
      git submodule update --init --recursive
      cd_do instawm/ make install -j$(nproc)
      cd_do instantDEB/ ./make.sh download
      cd_do instantDEB/ ./make.sh unpack
      cd_do instantDEB/ cp -r usr /usr
      cd_do instantDEB/ cp -r etc /etc
}

cd_do() {
    cd "$1"
    shift 1
    "$@"
    cd - >& /dev/null
}

# read from stdin
echo_progess() {
    if command -v tqdm >& /dev/null ; then
        tqdm --tee --total 8 --desc "Progress" > /dev/null
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
    local -r message=$(echo [instantOS][$(date +"%T.%3N")] "$desc" "$cmd")
    echo -n "$message" | tee -a "$logfile" ; echo >> "$logfile"
    if test ! -z "$cmd"
    then
        "$cmd" >> $logfile 2>&1  &
        local -r pid="$!"
        # spinner "$pid"
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

if [ -z $1 ] ; then
    echo "Usage:"
    echo "sudo ./make.sh install"
else
    "$@"
fi
