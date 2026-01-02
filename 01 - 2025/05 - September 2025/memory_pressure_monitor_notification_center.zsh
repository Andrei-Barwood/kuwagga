#!/bin/zsh

# Memory monitoring script with Notification Center integration
THRESHOLD=20

check_memory() {
    memory_info=$(memory_pressure 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        free_percentage=$(echo "$memory_info" | grep "System-wide memory free percentage" | grep -o '[0-9]\+')
        
        if [[ -n "$free_percentage" && "$free_percentage" -lt "$THRESHOLD" ]]; then
            osascript -e "display notification \"Free memory: ${free_percentage}% (below ${THRESHOLD}% threshold)\" with title \"Memory Alert\" subtitle \"Low Memory Warning\" sound name \"Ping\""
        fi
    fi
}

check_memory
