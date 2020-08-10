#!/bin/bash

logfile="log.install.log"

install() {
    if ! whoami | grep -iq '^root'; then
        sudo echo || die "requires root access to install packages"
    fi
    echo > "$logfile"
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
        download instantOSSystem
        process  instantOSUser
    }
}

# read from stdin
echo_progess() {
    if command -v tqdm >& /dev/null ; then
        tqdm --tee --total 9 --desc "Progress" > /dev/null
    else
        xargs -l1 echo
    fi
}

download() {
    while ! logdo Download "$@"
    do
        echo "[instantOS][Error: downloading packages failed, please reconnect to internet]"
        sleep 10
    done
}

process() {
    while ! logdo Compile "$@"
    do
        echo "[instantOS][Error: fail to process instantOS package file, please review $logfile]"
        sleep 10
    done
}

bootstrap() {
    # sudo apt-get install aptitude ubuntu-minimal
    # sudo aptitude markauto '~i!~nubuntu-minimal'
    # sudo apt install linux-image-generic
    # sudo apt install -y python3-pip git
    # pip3 install -U 'git+https://github.com/tqdm/tqdm@cli-tee#egg=tqdm'
    sudo apt update
    git submodule update --init
}

aptPackages() {
    sudo apt install -y fzf expect imvirt lshw read-edid
    sudo apt install -y xrandr xdotool xterm xclip xwallpaper rofi dunst
    sudo apt install herbstluftwm --no-install-recommends
}

media-player() {
    sudo apt install -y mpv slop maim #muti-media
    sudo apt install -y okular # pdf, epub, markdown viewer
}

media-editing() {
    sudo apt install -y gimp gimp-help gimp-data-extras
}

text-editor() {
    sudo apt install -y vim
    sudo apt install -y notepadqq # gui text editor for new users (alt. scite featherpad)
}

input-method() {
    sudo apt install -y fcitx fcitx-libpinyin # input method framework
    sudo apt install -y fcitx-frontend-gtk3 # firefox need this
}

download-tools() {
    sudo apt install curl wget
}

build-tools() {
    # for tools need be compiled from sources (e.g. windows manager)
    sudo apt install -y build-essential libx11-dev xorg-dev #dwm
    sudo apt install -y libimlib2-dev #xmenu
}

instantOSSystem() {
      cd_do src/instantDEB/ ./make.sh download
      cd_do src/instantDEB/ ./make.sh unpack
      cd_do src/instantDEB/ sudo cp -r usr /usr
      cd_do src/instantDEB/ sudo cp -r etc /etc
      cd_do src/instantWM/ sudo make install -j$(nproc)
      cd_do src/xmenu/ sudo make install -j$(nproc)
      cd_do core/ sudo cp xmenu.sh /usr/bin/
      cd_do core/ sudo cp rofi-sudo /usr/bin/
      cd_do core/ sudo cp fonts/* /usr/share/fonts/
}

instantOSUser() {
      local -r configdir=$HOME/.config/instantos/
      mkdir -p "$configdir"
      mkdir -p "$HOME/.config/herbstluftwm"
      link core/rofi-sudo.rasi "$configdir/rofi-sudo.rasi"
      link core/xmenu.sh "$configdir/xmenu.sh"
      link core/dunstrc "$HOME/.config/dunst/dunstrc"
      link core/xprofile ~/.xprofile
      link core/Xresources ~/.Xresources
      link core/xinitrc ~/.xinitrc
      cd_do core/ sudo cp herbstluftwm-autostart ~/.config/herbstluftwm/autostart
      link core/wallpapers/1041uuu-Shore-Animatio.mp4 /usr/share/backgrounds/
      link core/wallpapers/NihonJin.jpg /usr/share/backgrounds/
      [ -z "${DISPLAY+x}" ] || {
          xrdb ~/.Xresources
          pkill dunst
          dunst &
      }
}

link() {
    backupdir="backup/$(date -I).$(date +%H-%M)"
    mkdir -p "$backupdir"
    from="$1"
    to="$2"
    if [ -e "$to" ]; then
        cp "$to" "$backupdir"
        rm -fr "$to"
    fi
    # hardlink
    ln "$from" "$to"
}

cd_do() {
    cd "$1"
    shift 1
    "$@"
    cd - >& /dev/null
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

die() {
    echo "$1"
    exit 1
}

restoreState() {
    tput cnorm
}

trap restoreState EXIT

if [ -z $1 ] ; then
    echo "Usage:"
    echo "./make.sh install"
else
    "$@"
fi
