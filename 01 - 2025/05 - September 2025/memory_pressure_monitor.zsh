#!/bin/zsh

# Set memory threshold (percentage)
THRESHOLD=20  # Alert when free memory drops below 20%

# Function to send notification
send_notification() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Ping\""
}

# Get memory pressure information
memory_info=$(memory_pressure 2>/dev/null)
if [[ $? -eq 0 ]]; then
    # Extract free memory percentage
    free_percentage=$(echo "$memory_info" | grep "System-wide memory free percentage" | grep -o '[0-9]\+')
    
    if [[ -n "$free_percentage" && "$free_percentage" -lt "$THRESHOLD" ]]; then
        send_notification "Low Memory Warning" "Free memory: ${free_percentage}% (below ${THRESHOLD}% threshold)"
        echo "$(date): Low memory detected - ${free_percentage}% free" >> ~/memory_alerts.log
    fi
fi
