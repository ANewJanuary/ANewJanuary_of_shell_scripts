#!/bin/bash

# For gui entry, use zenity --entry
arg=$1
if [[ $arg == "k" ]]; then
    dunstctl close-all
    killall timer.sh
    exit
fi

entry=$(zenity --entry)
DURATION=$(($entry * 60))  # 30 minutes

echo "Starting $entry minute countdown..."

# Clear existing notifications
dunstctl close-all

remaining=$DURATION
while [ $remaining -gt 0 ]; do
    mins=$((remaining / 60))
    secs=$((remaining % 60))

    # Calculate progress
    progress=$((100 - (remaining * 100 / DURATION)))
    bars=$((progress / 5))

    # Create progress bar
    printf -v progress_bar "[%-20s]" "$(printf '█%.0s' $(seq 1 $bars))"

    # Set urgency based on time left
    crit=$(( ($DURATION * 15) / 100 ))
    urg=$(( ($DURATION * 30) / 100 ))
    if [ $remaining -lt $crit ]; then  # Last 5 minutes
        urgency="critical"
        color="#FF0000"
    elif [ $remaining -lt $urg ]; then  # Last 10 minutes
        urgency="normal"
        color="#FFA500"
    else
        urgency="low"
        color="#FFFFFF"
    fi

    # Update notification
    dunstify -r 88888 \
             -t 0 \
             -u "$urgency" \
             -h "string:frcolor:$color" \
             "⏰ $(printf "%02d:%02d" $mins $secs)" \
             "$progress_bar ${progress}%"

    sleep 1
    remaining=$((remaining - 1))
done

# Final notification
dunstify -r 88888 -t 5000 -u critical "✅ Timer Complete!" "$entry minutes have elapsed"
echo "Timer finished!"
