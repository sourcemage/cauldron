#!/bin/bash

. /usr/share/smgl.install/libenchant

function main_menu() {
}

function main_loop() {
  if $MENU ;then
    main_menu
    MENU=false
  else
    step=$(enchant_getstep)
    if ! [[ -x /usr/share/smgl.install/menu/$step ]] ;then
      echo "No gui code found for step $step, falling back to shell..."
      exit
    fi
    /usr/share/smgl.install/menu/$step
    rc=$?
    if [[ $rc == 0 ]] ;then
      : # Carry on with the next step, nothing to do
      # (Step will have set the current installer step already)
    elif [[ $rc == 1 ]] ;then
      MENU=true
    elif [[ $rc == 2 ]] ;then
      echo "Switching to shell, type \e[1mmenu\e[1m to return to menu"
      echo "Type \e[1mtodo\e1m to see the current step's documentation"
      exit
    else
      echo "Bailing to shell (gui step returned $rc)..."
      exit
    fi
  fi
}
