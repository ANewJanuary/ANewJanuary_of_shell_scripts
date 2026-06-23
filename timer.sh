#!/bin/bash

PIDDIR=/tmp/timer.sh-pids
mkdir -p "$PIDDIR"

if [[ $1 == "k" ]]; then
    makoctl dismiss -a -h
    # mako leaves a stale surface behind when notifications on multiple
    # anchors (e.g. clock top-right + timer bottom-center) are dismissed
    # at once; reload forces it to redraw/clean up.
    makoctl reload
    for pidfile in "$PIDDIR"/*.pid; do
        [[ -e $pidfile ]] || continue
        pid=$(cat "$pidfile")
        kill "$pid" 2>/dev/null
        rm -f "$pidfile"
    done
    exit
fi

run_clock() {
    pidfile="$PIDDIR/clock.pid"
    echo $$ > "$pidfile"
    trap 'rm -f "$pidfile"' EXIT

    while true; do
        time=$(date +"%H:%M:%S")
        date_str=$(date +"%A, %B %-d")
        dunstify -a "clock" -r 77777 -t 0 -u low \
                 --stack-tag clock \
                 "$time" "$date_str"
        sleep 1
    done
}

run_timer() {
    entry=$(zenity --entry --text="Minutes to count down:")
    [[ -z $entry ]] && exit
    DURATION=$((entry * 60))

    pidfile="$PIDDIR/timer.pid"
    echo $$ > "$pidfile"
    trap 'rm -f "$pidfile"' EXIT

    echo "Starting $entry minute countdown..."
    makoctl dismiss -a -h

    remaining=$DURATION
    while [ $remaining -gt 0 ]; do
        mins=$((remaining / 60))
        secs=$((remaining % 60))

        progress=$((100 - (remaining * 100 / DURATION)))
        bars=$((progress / 5))
        printf -v progress_bar "[%-20s]" "$(printf '█%.0s' $(seq 1 $bars))"

        crit=$(( (DURATION * 15) / 100 ))
        urg=$(( (DURATION * 30) / 100 ))
        if [ $remaining -lt $crit ]; then
            urgency="critical"
        elif [ $remaining -lt $urg ]; then
            urgency="normal"
        else
            urgency="low"
        fi

        dunstify -a "timer" -r 88888 -t 0 -u "$urgency" \
                 --stack-tag timer \
                 "⏰ $(printf "%02d:%02d" $mins $secs)" \
                 "$progress_bar ${progress}%"

        sleep 1
        remaining=$((remaining - 1))
    done

    dunstify -a "timer" -r 88888 -t 5000 -u critical "✅ Timer Complete!" "$entry minutes have elapsed"
    echo "Timer finished!"
}

mode=$(printf "Clock\nTimer" | fuzzel --dmenu --prompt="Mode: ")

case "$mode" in
    Clock) run_clock ;;
    Timer) run_timer ;;
    *) exit 0 ;;
esac
