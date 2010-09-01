#!/bin/bash

function do_usage
{
   echo "usage: [--help][--games <num_of>][--id <player>][--stra <strategy>]"
   echo ""
}

CMD="./dicebot"
WINS=0
LOST=0
ERR=0
GAMES_LEFT=0
MAX_GAMES=0

while [ "$1" != "" ]; do
   case $1 in
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
      --stra)
         shift
	 STRA=$1
	 ;;
      *)
	 PARM=$1
     echo found $PARM
	 ;;
   esac
   shift
done

if [ $MAX_GAMES -lt 0 ]; then
   MAX_GAMES=0
fi

while true; 
do
   $CMD $ID $STRA $PARM
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
