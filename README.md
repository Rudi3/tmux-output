# tmux-output
Bash tool to get the output of commands sent to an interactive cli program using tmux

-------

I made this because of a question on [unix.stackexchange.com](https://unix.stackexchange.com/questions/543206/read-output-from-screen), which touched upon this problem.
I tought that it may be convenient to have a "quick" way to send commands to a shell-like program and get the result synchronously. If the shell has a prompt string or symbol, waiting for the symbol would make more sense than what this is doing here. This is meant for "symbol-idependent detection" of when a command is done.

**Currently, this is not really stable or reliable**
This is a proof-of-concept. Suggestions and or PRs are welcome.
 
# How to use

You can start the a `tmux` session like that:

    tmux new-session -d -s mysession "python3"

How to run a command (and get the output):

    ./trun.sh -s mysession -c "the command"

It should return the desired output. You may have to adjust the `-H` and `-T` parameters. In some cases, like the `python3` interpreter, you may have to use `-e "C-m C-m` (double `enter`) for multiline commands.

# Theory of operation

**Send command**
`tmux send-keys -t $session_name "$command" C-m` will send a command to the program running in the `tmux` session.

**Detect when the command is done**
To detect when the command is done, these checks are performed in a loop:
- Check if process is in interruptable sleep
- Check if process is running
- If both previous conditions apply, check if stacktrace "looks stuck"
- If all of the statements are true, the command should be completed. (It could still get stuck at something else...)

**Capturing the output**

- Prior to sending the command, create a temporary file and pipe the tmux output into it: `tmux pipe-pane -t $session_name -o "cat > $tmpfile"`.

- Send the command and wait for completion

- Stop piping into the file: `tmux pipe-pane -t $session_name`

- Output the file contents (and crop as needed)

# Tests
I tested this with `python3` and `zsh`:

**Python**

    >tmux new-session -d -s pytest "python3"
    >./myscript.sh -s pytest -c 'for i in range(1000000): print("test")' -e "C-m C-m"
    test
    [redacted]
    test

**ZSH**

    >tmux new-session -d -s zshtest "/bin/zsh"
    >./myscript.sh -s zshtest -c 'ls' -T 1
    [some folders]
