#!/bin/bash

# Initialize our own variables
WAIT_TIME=""
FILES=()

# Function to display usage
function usage() {
    echo "Usage: $0 -f \"filename1 filename2 ...\" -t wait_time"
    exit 1
}

# Parse command line options.
while getopts "f:t:" opt; do
    case "${opt}" in
        f)
            IFS=' ' read -ra FILES <<< "${OPTARG}"
            ;;
        t)
            WAIT_TIME="${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Validate input parameters
if [[ ${#FILES[@]} -eq 0 ]] || [[ -z "$WAIT_TIME" ]]; then
    usage
fi

# Create a pipe to pass back error codes from background jobs
mkfifo /tmp/errorpipe
exec 3<>/tmp/errorpipe
rm /tmp/errorpipe

# Function to wait for a single file
wait_for_file() {
    local file=$1
    local wait_time=$2
    while (( wait_time > 0 )); do
        if [[ -e $file ]]; then
            echo "File $file exists."
            return 0
        fi
        sleep 1
        ((wait_time--))
    done

    # If the file does not exist after the specified time, write an error code
    if [[ ! -e $file ]]; then
        echo "File $file does not exist after waiting for $WAIT_TIME seconds."
        echo 2 >&3
        return 2
    fi
}

# Start the background jobs
for FILE in "${FILES[@]}"; do
    wait_for_file "$FILE" "$WAIT_TIME" &
done

# Wait for all background jobs to finish
wait

# Check if any background job reported an error
if read -r -t 0.1 err <&3; then
    exit "$err"
fi
