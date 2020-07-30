#!/bin/sh

set -e

f="$HOME/.config/instantos/xmenu.sh"
if [ ! -f "$f" ]; then
    mkdir -p "$(dirname $f)"
    cp /usr/bin/xmenu.sh "$f"
    chmod 0700 "$f"
fi
if [ "$f" != "$0" ]; then
    # only execute user version
    "$f" "$@"
    exit $?
fi

menu_edit() {
  gedit "$f"
}

window_manager_edit() {
  cd ~/code/gui/dwm
  gedit ~/code/gui/dwm/config.h
  menu_sudo xterm -e vim +"make install -j"
}

free_mem() {
    free | awk '/Mem/ {printf "%d GB/%d GB\n", $4/1024/1024, $2/1024/1024.0}'
}

volume() {
    printf "%s(%s)" $(amixer get -D pulse Master | awk -F'[][]' 'END {print $2," ",$4}')
}

record() {
    echo $(slop -f "%x %y %w %h %g %i") | {
        # each piped command run in subshell
        read -r X Y W H G ID
        local file="$HOME/Videos/screenrecord-$(date -I).$(date +%s).mp4"
        echo -n "$file" | xclip -selection clipboard
        notify-send "$file" "Copied Filename.\nWriting to $file ..."
        ffmpeg -f x11grab -s "$W"x"$H" -i :0.0+$X,$Y -f alsa -i pulse "$file"
    }
}
recordStop() {
    local pid=$(ps aux | awk '/[ ]+ffmpeg.*screenrecord-.*.mp4/ { print $2 }')
    if [ -z $pid ] ; then
        echo
    else
        printf "\tStop Recording   \tkill -15 $pid"
    fi
}

screenshot() {
    mkdir -p ~/Pictures
    local file="screenshot-$(date -I)-$(date +%T).png"
    {
        maim -s | tee "$HOME/Pictures/$file" | xclip -selection clipboard -t image/png
    } && notify-send "$file" "Copied to clipboard.\nSaved to $HOME/Pictures"
}

terminal() {
    alacritty || xterm
}

browser() {
    firefox
}

gedit() {
    alacritty -e vim "$1" ||
    scite "$1" ||
    xterm -e vim "$1" ||
    st -e vim "$1" ||
    gnome-terminal -e vim "$1" ||
    exit 1
}

networkIP() {
    notify-send "Your PublicIP" "$(curl ifconfig.me)"
}

showdate() {
    xsetroot -name "$(date)🤣"
    echo "$(LANG=zh_CN.utf8 date)  "
}

launchpad() {
    rofi -modi drun -show drun -dpi 192
}

help() {
    cat <<EOF
	help doc for you
	Ctrl+Space to Switch InputMethod
	Super+Space to lanuch applications
EOF
}

releasemem() {
    menu_sudo sh -c "sync; /usr/bin/echo 3 > /proc/sys/vm/drop_caches" && {
        notify-send "Available Memory Now:" "$(free_mem)"
    }
}

menu_sudo() {
    SUDO_ASKPASS=/usr/bin/rofi-pass sudo -A "$@"
}

display() {
    xrandr | awk '/ primary/ { print $4 }' | cut -d'+' -f1
}

menu_resolution() {
    for mon in $(xrandr | awk '/ connected/ {print $1}')
    do
        printf "\t${mon} Resolution   \n"
        xrandr | awk -v monitor="^DisplayPort-0 connected" '
          /connected/ {p=0}; $0 ~ monitor {p=1}; p {print "\t\t", $1, "   \t", "xrandr -s ", $1}' | sed -n '2,$p'
        # DPI setting
        printf "\t%s %s\n" ${mon} "$(sed -n '/Xft.dpi/p' ~/.Xresources)"
        for factor in 96 120 144 168 192 ; do
            printf "\t\t%s  \t%s\n" "$factor" "sed -i '/Xft.dpi/d ; /Xft.autohint/ i Xft.dpi:$factor' ~/.Xresources ; xrdb ~/.Xresources"
        done
    done
}

[ "$f" = "$0" ] && [ ! -z $1 ] && {
    echo [instantos] "$@"
    "$@"
    exit $?
}

# format: Name <Tab> CMD
# format: CMD
# submenu start with one or more <Tab> as level getting deeper
# name format: IMG:./icons/web.png string
# cmd format: shell command
cat <<EOF | xmenu | sh &
$(showdate)

Help 帮助ヾ(*Őฺ∀Őฺ*)ﾉ
$(help)

Applications
	Web Browser	firefox
	File Browser	xterm -e ranger
	LaunchPad	"$0" launchpad

Terminal (sudo)	"$0" menu_sudo xterm

Setting
	Edit this Menu   	"$0" menu_edit
	Edit Windows Manager	"$0" window_manager_edit
	Bluetooth	xterm -e bluetoothctl
	Network Manager	xterm -e nmtui

Display: $(display)
$(menu_resolution)

Volume:  $(volume)
	Mute    	amixer -D pulse sset Master 0%
	20%	amixer -D pulse sset Master 20%
	40%	amixer -D pulse sset Master 40%
	60%	amixer -D pulse sset Master 60%
	80%	amixer -D pulse sset Master 80%
	100%	amixer -D pulse sset Master 100%
	More	pavucontrol
Memory:  $(free_mem)
	Relase Memory   	"$0" releasemem
Network: $(ip -br a | grep wlp5s0 | awk '{print $3,"    "}')
	Gateway: $(ip route | grep default | awk '{print $3,"    "}')
	What is my public IP?	"$0" networkIP
	VPN: (off)

Screenshot	"$0" screenshot
ScreenRecord	"$0" record
$(recordStop)

Suspend	systemctl suspend; i3lock
Power Menu
	Shutdown   	poweroff
	Reboot	reboot
	Logout	kill -9 -1
EOF


# vim: set list ts=25 sw=25 noexpandtab :
