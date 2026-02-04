#!/usr/bin/env bash
#
# OnyxNode Ping Sweep Tool
#

set -o pipefail

# --- Configuration Defaults ---
BASE_NAME="onyxnode"
START_RANGE=1
END_RANGE=200
LOG_FILE="scan_results.log"
TIMEOUT=1
PING_COUNT=2
VERBOSE=false

# --- Counters ---
UP_COUNT=0
DOWN_COUNT=0

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---

print_banner() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}             NETWORK SWEEPER           ${NC}"
    echo -e "${BLUE}=======================================${NC}"
}

usage() {
    print_banner
    echo -e "\nUsage: $0 [options]"
    echo -e "\nOptions:"
    echo -e "  -h, --help           Show this help message"
    echo -e "  -r, --range <num>    Set max range (default: 200)"
    echo -e "  -b, --base <name>    Set hostname base (default: onyxnode)"
    echo -e "  -c, --count <num>    Set number of pings per host (default: 2)"
    echo -e "  -o, --output <file>  Set log file (default: scan_results.log)"
    echo -e "  -t, --timeout <sec>  Ping timeout in seconds (default: 1)"
    echo -e "  -v, --verbose        Show unreachable hosts in final output"
    echo -e "\nExamples:"
    echo -e "  $0                   # Standard scan (2 pings)"
    echo -e "  $0 -c 1              # Fast scan (1 ping)"
    echo -e "  $0 -c 5              # Thorough scan (5 pings)"
    echo ""
}

perform_sweep() {
    echo -e "Target: ${YELLOW}${BASE_NAME}[01..${END_RANGE}]${NC}"
    echo -e "Pings per host: ${YELLOW}${PING_COUNT}${NC}"
    echo -e "Scanning... (Please wait for timeout to complete)"
    
    # Create a temporary file to store unordered results
    local temp_file
    temp_file=$(mktemp)

    # Initialize log file
    echo "--- Scan started at $(date) ---" > "$LOG_FILE"
    echo "--- Parameters: Count=$PING_COUNT, Timeout=$TIMEOUT ---" >> "$LOG_FILE"

    # Loop through the range
    for (( i=START_RANGE; i<=END_RANGE; i++ )); do
        (
            # Padding Logic:
            # If i < 100, add a leading zero (01, 02..99)
            # If i >= 100, leave it alone (100, 101..)
            if [ "$i" -lt 10 ]; then
                suffix="0$i"
            elif [ "$i" -lt 100 ]; then
                suffix="$i"
            fi
            
            if [ "$i" -lt 100 ]; then
                 printf -v suffix "%02d" "$i"
            else
                 printf -v suffix "%d" "$i"
            fi
            
            local host="${BASE_NAME}${suffix}"
            
            # Ping: Uses $PING_COUNT variable
            if ping -c "$PING_COUNT" -W "$TIMEOUT" "$host" &> /dev/null; then
                echo "UP $host" >> "$temp_file"
            else
                    echo "DOWN $host" >> "$temp_file"
            fi
        ) & 
    done

    # Wait for all background pings to finish
    wait

    # 3. Calculate Counts (Always accurate because we read the file)
    local count_up
    local count_down
    count_up=$(grep -c "^UP" "$temp_file")
    count_down=$(grep -c "^DOWN" "$temp_file")

    # --- Process and Sort Results ---
    
    echo -e "\n${BLUE}--- Active Nodes (Sorted) ---${NC}"
    
    if [ -s "$temp_file" ]; then
        sort -V "$temp_file" | while read -r line; do
            status=$(echo "$line" | awk '{print $1}')
            host=$(echo "$line" | awk '{print $2}')
            
            if [ "$status" == "UP" ]; then
                echo -e "${GREEN}[UP]${NC}   $host"
                echo "[$(date "+%H:%M:%S")] [UP] $host" >> "$LOG_FILE"
            else
                # Only show DOWN nodes on screen if VERBOSE is true
                if [ "$VERBOSE" = true ]; then
                    echo -e "${RED}[DOWN]${NC} $host"
                fi
                # Always log DOWN nodes to the file
                echo "[$(date "+%H:%M:%S")] [DOWN] $host" >> "$LOG_FILE"            
                fi
        done
    else
        echo -e "${RED}No hosts found.${NC}"
    fi

    echo -e "\n${BLUE}Scan Complete.${NC} Results saved to $LOG_FILE"
    echo -e "${GREEN}Total UP: $count_up${NC}"
    echo -e "${RED}Total DOWN: $count_down${NC}"
    rm -f "$temp_file"
}

# --- Argument Parsing ---

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -r|--range) END_RANGE="$2"; shift ;;
        -b|--base) BASE_NAME="$2"; shift ;;
        -c|--count) PING_COUNT="$2"; shift ;;
        -o|--output) LOG_FILE="$2"; shift ;;
        -t|--timeout) TIMEOUT="$2"; shift ;;
        -v|--verbose) VERBOSE=true ;;
        *) echo "Unknown parameter: $1"; usage; exit 1 ;;
    esac
    shift
done

# --- Main Execution ---
print_banner
perform_sweep