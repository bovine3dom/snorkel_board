#!/bin/sh
# mostly written by google gemini because i don't want to learn shell scripting sorry

# --- Configuration ---
LOCK_DIR="/tmp/jelly_wgetter.lock"  # Using a directory for atomic lock creation
CHECK_FILE="/mnt/us/linkss/screensavers/bg_ss00.png" # File to check modification time
MAX_AGE_SECONDS=5          # 1 hour = 3600 seconds
PING_TARGET="8.8.8.8"         # Reliable IP target for connectivity checks
PING_TIMEOUT=2                # Seconds to wait for each ping reply
WAIT_RETRIES=3               # How many times to retry ping when waiting (12 * 5s = 1 min)
WAIT_SLEEP=5                  # Seconds to sleep between wait retries
echo "change the url"
exit 1
FILE_URL="http://example.org" # URL to download
OUTPUT_FILE="/mnt/us/linkss/screensavers/bg_ss00.png"        # Where to save the downloaded file
WGET_TIMEOUT=30               # Seconds for wget connection/read timeout

# --- State Variables ---
wifi_was_off=0 # Flag to track if we (theoretically) turned wifi on

# --- Cleanup Function ---
# This function will be called on script exit (normal or error) to remove the lock
cleanup() {
    echo "Cleaning up..."
    # Remove the lock directory if it exists and was created by us
    # The check prevents accidentally removing a lock held by another process
    # if our mkdir failed but the script continued somehow.
    if [ -d "$LOCK_DIR" ]; then
        rmdir "$LOCK_DIR"
        if [ $? -eq 0 ]; then
            echo "Lock released."
        else
            echo "Warning: Failed to remove lock directory '$LOCK_DIR'. Might be held by another process or removed already."
        fi
    fi

    # 7. Turn Wi-Fi off *if* we turned it on
    if [ "$wifi_was_off" -eq 1 ]; then
        echo "Turning Wi-Fi off (placeholder)..."
        # Add your command here to turn Wi-Fi OFF
        # Example: ifconfig wlan0 down
        # Example: nmcli radio wifi off
    fi
}

# --- Trap Exit Signals ---
# Ensures cleanup() runs when the script exits, HUPs, INTERRUPTs, or TERMs
trap cleanup EXIT HUP INT TERM

# --- Main Script Logic ---

# 1. Set Lock
echo "Attempting to acquire lock..."
if mkdir "$LOCK_DIR"; then
    echo "Lock acquired ($LOCK_DIR)."
else
    echo "Error: Lock directory '$LOCK_DIR' already exists. Another instance running?"
    # Exit without running cleanup because we didn't acquire the lock
    trap - EXIT HUP INT TERM # Disable the trap
    exit 1
fi

# 2. Check File Modification Time
echo "Checking modification time of '$CHECK_FILE'..."
if [ ! -f "$CHECK_FILE" ]; then
    echo "Warning: Check file '$CHECK_FILE' does not exist. Assuming it's old enough."
    # Or uncomment below to exit if the file *must* exist:
    # echo "Error: Check file '$CHECK_FILE' does not exist."
    # exit 1
else
    # Get file modification time (seconds since epoch)
    mod_time=$(stat -c %Y "$CHECK_FILE")
    # Get current time (seconds since epoch)
    current_time=$(date +%s)
    # Calculate age
    age=$((current_time - mod_time))

    echo "File age: $age seconds."
    if [ "$age" -le "$MAX_AGE_SECONDS" ]; then
        echo "File '$CHECK_FILE' was modified within the last hour ($MAX_AGE_SECONDS seconds). Exiting."
        exit 0 # Exit normally, no error, just nothing to do
    else
        echo "File is older than $MAX_AGE_SECONDS seconds. Proceeding..."
    fi
fi

# 3. Check for Internet Access
echo "Checking initial internet access (pinging $PING_TARGET)..."
if ping -c 1 -W $PING_TIMEOUT $PING_TARGET > /dev/null 2>&1; then
    echo "Internet access detected."
else
    echo "Initial internet check failed."
    wifi_was_off=1 # Assume wifi needs to be turned on

    # 4. Turn on Wi-Fi (Placeholder)
    echo "Turning Wi-Fi on (placeholder)..."
    # Add your command here to turn Wi-Fi ON
    # Example: ifconfig wlan0 up
    # Example: nmcli radio wifi on
    # You might need a small sleep here after enabling it
    # sleep 5

    # 5. Wait for Network
    echo "Waiting for network connection..."
    retries=$WAIT_RETRIES
    while [ $retries -gt 0 ]; do
        if ping -c 1 -W $PING_TIMEOUT $PING_TARGET > /dev/null 2>&1; then
            echo "Network connection established."
            break
        fi
        echo "Network not up yet. Retrying in $WAIT_SLEEP seconds... ($retries retries left)"
        sleep $WAIT_SLEEP
        retries=$((retries - 1))
    done

    if [ $retries -eq 0 ]; then
        echo "Error: Network connection timed out after $WAIT_RETRIES retries."
        exit 1
    fi
fi

# 6. Get File using wget
echo "Downloading '$FILE_URL' to '$OUTPUT_FILE'..."
# -q: quiet, -T: timeout, -O: output file
wget -q -T $WGET_TIMEOUT -O "$OUTPUT_FILE" "$FILE_URL"
wget_exit_code=$?

if [ $wget_exit_code -eq 0 ]; then
    echo "File downloaded successfully."
else
    echo "Error: wget failed with exit code $wget_exit_code."
    # Optional: remove partially downloaded file
    rm -f "$OUTPUT_FILE"
    exit 1
fi

# 7. Turn off Wi-Fi (handled by cleanup trap)

# 8. Unset Lock (handled by cleanup trap)

echo "Script finished successfully."
exit 0 # Explicit successful exit, triggers cleanup
