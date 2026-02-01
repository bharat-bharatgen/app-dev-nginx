#!/bin/bash

# Script to get Docker logs for medsum-server for a specific date and time range in IST
# Usage: ./get-logs.sh [DATE] [START_HOUR] [END_HOUR]
# Example: ./get-logs.sh 2026-01-31 15 18

# Default values
DATE="${1:-2026-01-31}"
START_HOUR="${2:-15}"  # 3 PM in 24-hour format
END_HOUR="${3:-18}"    # 6 PM in 24-hour format
CONTAINER_NAME="medsum-server"

# Create output filename with date and time range
# Format: logs-YYYY-MM-DD-HHh-HHh.txt (e.g., logs-2026-01-31-15h-18h.txt)
OUTPUT_FILE="logs-${DATE}-$(printf "%02d" $START_HOUR)h-$(printf "%02d" $END_HOUR)h.txt"

# Construct timestamps in IST (UTC+5:30)
START_TIME="${DATE}T$(printf "%02d" $START_HOUR):00:00+05:30"
END_TIME="${DATE}T$(printf "%02d" $END_HOUR):00:00+05:30"

echo "Fetching logs for $CONTAINER_NAME"
echo "Date: $DATE"
echo "Time range: $START_HOUR:00 to $END_HOUR:00 IST"
echo "Output file: $OUTPUT_FILE"
echo "----------------------------------------"

# Get logs with timestamps
docker logs "$CONTAINER_NAME" \
    --since "$START_TIME" \
    --until "$END_TIME" \
    --timestamps > "$OUTPUT_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "Logs saved to $OUTPUT_FILE"
    echo "Total lines: $(wc -l < $OUTPUT_FILE)"
else
    echo "Error fetching logs. Please check if the container exists."
    exit 1
fi
