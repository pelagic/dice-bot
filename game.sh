#!/bin/bash

function do_usage
{
   echo "usage: [--help][--games <num_of>][--id <player>][--strategy <name>]"
   echo "       [debug]"
   echo ""
   echo "       --debug        activate debug"
   echo "       --games        stops after <num_of> games (err are ignored)"
   echo "       --help         this text"
   echo "       --id           send <player> as name of this bot"
   echo "       --strategy     uses the strategy <name> for this game"
   echo "                      --strategy Primitive"
   echo "                      --strategy Px,17      (limit=17)"
   echo ""
}

CMD="./dicebot"
#CMD="./dicebot.pl"
#CMD="echo SIM_MODE"
WINS=0
LOST=0
ERR=0
GAMES_LEFT=0
MAX_GAMES=1
ID="julius"
STRATEGY="Primitive"
DEBUG=0

while [ "$1" != "" ]; do
   case $1 in
      --debug)
         DEBUG=1
	 ;;
      --help)
         do_usage
	 exit 0
	 ;;
      --games)
         shift
	 MAX_GAMES=$1
	 ;;
      --id)
         shift
	 ID=$1
	 ;;
      --strategy)
         shift
	 STRATEGY=$1
	 ;;
      *)
	 PARM=$1
         echo "unknown ARG passed: $PARM"
	 exit 1
	 ;;
   esac
   shift
done

if [ $MAX_GAMES -lt 1 ]; then
   MAX_GAMES=1
fi

## concatenate option string
##
OPT="--id $ID --strategy $STRATEGY"
if [ $DEBUG -gt 0 ]; then
   OPT="$OPT --debug"
fi

while true; 
do
   $CMD $OPT
   RC=$?
   
   if [ $RC -eq 0 ]; then
      WINS=$(($WINS+1))
   elif [ $RC -eq 1 ]; then
      LOST=$(($LOST+1))   
   else
      ERR=$((ERR+1))
      sleep 1
   fi

   if [ $MAX_GAMES -ne 0 ]; then
      GAMES_LEFT=$(($MAX_GAMES-($WINS+$LOST)))

      echo "total: won=$WINS lost=$LOST err=$ERR left=$GAMES_LEFT"
      if [ $GAMES_LEFT -eq 0 ]; then
         exit 0      
      fi
   else
      echo "total: won=$WINS lost=$LOST err=$ERR"
   fi
done
