rdpSSM() {
    local fifo="/tmp/ssm-session-$$.fifo"
    mkfifo "$fifo"

    aws ssm start-session --target i-04e1816437ffce9e4 \
      --document-name AWS-StartPortForwardingSession \
      --parameters "localPortNumber=55678,portNumber=3389" > "$fifo" 2>&1 &

    # Wait for "Waiting for connections..." in the output
    while read -r line; do
        echo "$line"
        if [[ "$line" == *"Waiting for connections..."* ]]; then
            break
        fi
    done < "$fifo"

    "/Applications/Royal TSX.app/Contents/Resources/royalts" connect --name "rdpSSM" --port 55678 --protocol RDP --host localhost 

    rm "$fifo"
}