#!/bin/bash

session_name=
command=
headcrop=2
tailcrop=2
enter="C-m"
debug=0

print_usage() {
        printf "Usage:\n-H Headcrop, Integer, Output will start at given line number, Default: 2 to remove the first line (which should be the command sent)
-T  Tailcrop: Integer, Will stop output at line number, counting from bottom up, Default: 2 to remove the last line(which is usually the prompt)
-o  Line Offset: Amount of lines of output expected, Default: 1 (The prompt line does not count as output, see option above. To include it, set -o 2 -t 0)
-e  Enter Sequence: Some shells/commands may require a two enter symbols to run the command (e.g. multiline mode of the python interpreter) Default: \"C-m\" Use double Quotes!
More Coming soon™\n"
}

while getopts 'dhs:c:T:H:e:' flag; do
    case "${flag}" in
        d) debug=1 ;;
        h) print_usage
           exit 1 ;;
        s) session_name="${OPTARG}" ;;
        c) command="${OPTARG}" ;;
        e) enter="${OPTARG}" ;;
        H) headcrop="${OPTARG}" ;;
        T) tailcrop="${OPTARG}" ;;
        *) print_usage
           exit 1 ;;
    esac
done

IS_ST=

function p_is_stuck () {
    #check if process is in iterruptable sleep
    is_idle=$(ps -p $1 -ocmd,stat,wchan | tail -n1 | tr -s '[:blank:]' | cut -d' ' -f2 | grep -c S)

    #check if process is running
    is_running=$(ps -p $1 -ocmd,stat,wchan | tail -n1 | tr -s '[:blank:]' | cut -d' ' -f3 | grep -c -)
    
    if [ "$debug" -eq "1" ]; then echo "idle: $is_idle, running: $is_running"; fi

    if [ "$is_idle" -eq "1" ] && [ "$is_running" -eq "1" ]; then
            if [ "$debug" -eq "1" ]; then echo "Checking syscall..."; fi
            #is_read=$(strace -p $1 -e read -q 2> >(head -c 8 | grep -czPo "^read\([0-9]+"))

            strace=$(timeout 0.05 strace -p $1 -q 2>&1)
            is_stuck=$(echo "$strace" | grep -czPo "^[^\(]+\(([^,]+, )+[^,]* <detached ...>")

            if [ "$is_stuck" -eq "1" ]; then
                    IS_ST="1"
            else
                    IS_ST="0"
            fi
    else
            IS_ST="0"
    fi

}

function y_pos () {
        echo $(tmux display -p -t $session_name '#{cursor_y}')
}

###prepare
#get pid of process
pid=$(tmux display -p -t $session_name '#{pane_pid}')

#temporarily pipe tmux output to a file
tmpfile=$(mktemp /tmp/tmux-out.XXXXXX)
tmux pipe-pane -t $session_name -o "cat > $tmpfile"

#send command to session
tmux send-keys -t $session_name "$command" $enter

###wait for process to be stuck
if [ "$debug" -eq "1" ]; then echo "Begin waiting loop..."; fi
i=0
while true
do
        if [ "$debug" -eq "1" ]; then echo "Iteration: $i"; fi
        p_is_stuck $pid
        if [ "$IS_ST" -eq "1" ]; then
                break;
        else
                sleep 1
        fi
        let "i++"
done

if [ "$debug" -eq "1" ]; then echo "Done waiting."; fi

#stop piping output
tmux pipe-pane -t $session_name

if [ "$debug" -eq "1" ]; then printf "#####################\nOutput:\n"; fi
#crop the file and print it
cat "$tmpfile" | tail -n "+$headcrop" | head -n "-$tailcrop"

#remove temporary file
rm -f "$tmpfile"
