#!/bin/bash

logfile="log.install.log"

install() {
    if ! whoami | grep -iq '^root'; then
        echo "requires root access to install packages"
        exit
    fi
    download aptPackages
    download instantOSPackages
}

download() {
    while ! logdo "$@"
    do
        echo "downloading packages failed, please reconnect to internet"
        sleep 10
    done
}

aptPackages() {
    apt install -y fzf expect git os-prober dialog imvirt lshw bash curl python3-tqdm
}

instantOSPackages() {
      git submodule update --init --recursive
      cp instantOS/imenu.sh /usr/bin/imenu
      chmod 755 /usr/bin/imenu
}

# log and does the operation
# log cmd/function
logdo() {
    local -r message=$(echo [$(date -I).$(date +"%T.%3N")] "$@")
    echo -n "$message" | tee -a "$logfile" ; echo >> "$logfile"
    if command -v tqdm >& /dev/null ; then
        echo
        "$@" > >(tqdm --total 1 --desc Progress >> $logfile) 2>&1
    else
        "$@" >> $logfile 2>&1 &
        local -r pid="$!"
        spinner "$pid"
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
    printf "\b...\n"
    tput cnorm
    wait "$1" #capture exit code
    return $?
}

restoreState() {
    tput cnorm
}

trap restoreState EXIT

"$@"
