#!/bin/zsh

# brew install terminal-notifier

THRESHOLD=20

send_advanced_notification() {
    local free_mem="$1"
    terminal-notifier \
        -title "Memory Alert" \
        -subtitle "System Memory Low" \
        -message "Available memory: ${free_mem}%" \
        -sound "Ping" \
        -appIcon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns" \
        -group "memory-monitor"
}
