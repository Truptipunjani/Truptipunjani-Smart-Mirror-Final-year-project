#!/bin/bash
  # use bash instead of sh
[ -f ./untrack-css.sh ] && ./untrack-css.sh

if grep docker /proc/1/cgroup -qa; then
  # if running in docker, only start electron

  electron js/electron.js $1;
else
  # not running in docker

  if [ -z "$DISPLAY" ]; then #If not set DISPLAY is SSH remote or tty
    export DISPLAY=:0 # Set by default display
  fi
  # get the processor architecture
  arch=$(uname -m)
  false='false'
  true='true'

  # get the config option, if any
  # only check non comment lines
  serveronly=$(grep -v '^[[:blank:]]*//'  config/config.js | grep -i serveronly: | awk -F: '{print tolower($2)}' | tr -d ,\"\'\\r | sed -e 's/^[[:space:]]*//')
  # set default if not defined in config
  serveronly=${serveronly:-false}
  # check for xwindows running
  xorg=$(pgrep Xorg)
  if [ "$xorg." == "." ]; then
     # check for x on Lubuntu
     xorg=$(pgrep X)
  fi
  #check for macOS
  mac=$(uname)
  el_installed=$true
  if [ ! -d node_modules/electron ]; then
    el_installed=$false
  fi
  #
  # if the user requested serveronly OR
  #    electron support for armv6l has been dropped OR
  #    system is in text mode
  #
  if [ "$serveronly." != "false." -o  "$arch" == "armv6l" -o "$arch" == "i686" -o $el_installed == $false  ]  ||  [ "$xorg." == "." -a $mac != 'Darwin' ]; then

      t=$(ps -ef | grep  "node serveronly" | grep -m1 -v color | awk '{print $2}')
      if [ "$t." != '.' ]; then
        sudo kill -9 $t >/dev/null 2>&1
      fi
    # if user explicitly configured to run server only (no ui local)
    # OR there is no xwindows running, so no support for browser graphics
    if [ "$serveronly." == "true." ] || [ "$xorg." == "." -a $mac != 'Darwin' ]; then
      # start server mode,
      node serveronly
    else
      # start the server in the background
      # wait for server to be ready
      # need bash for this
      exec 3< <(node serveronly)

      # Read the output of server line by line until one line 'point your browser'
      while read line; do
         case "$line" in
         *point\ your\ browser*)
            echo $line
            break
            ;;
         *)
            echo $line
            #sleep .25
            ;;
         esac
      done <&3

      # Close the file descriptor
      #exec 3<&-

      # lets use chrome to display here now
      # get the server port address from the ready message
      port=$(echo $line | awk -F\: '{print $4}')
      # start chromium
      echo "Starting chromium browser now, have patience, it takes a minute"
      # continue to spool stdout to console
      tee <&3 &
			if [ $mac != 'Darwin' ]; then
        b="chromium"
        if [ $(which $b). == '.' ]; then
          b='chromium-browser'
        fi
        if [ $(which $b). != '.' ]; then
				  "$b" -noerrdialogs -kiosk -start_maximized  --disable-infobars --app=http://localhost:$port  --ignore-certificate-errors-spki-list --ignore-ssl-errors --ignore-certificate-errors 2>/dev/null
        else
          echo "Chromium_browser not installed"
        fi
			else
			  open -a "Google Chrome" http://localhost:$port --args -noerrdialogs -kiosk -start_maximized  --disable-infobars --ignore-certificate-errors-spki-list --ignore-ssl-errors --ignore-certificate-errors 2>/dev/null
			fi
      exit
    fi
  else
    # we can use electron directly
    node_modules/.bin/electron js/electron.js $1;
  fi
fi
