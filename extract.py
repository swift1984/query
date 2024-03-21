from datetime import datetime

# Function to parse log file and extract timestamps
def extract_timestamps_from_log(log_file):
    timestamps = []
    with open(log_file, 'r') as file:
        for line in file:
            parts = line.split()
            if len(parts) < 2:
                continue  # Skip lines that don't contain timestamp
            timestamp_str = ' '.join(parts[:2])  # Extracting the date and time part
            try:
                timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
                timestamps.append(timestamp)
            except ValueError:
                pass  # Skip lines that don't match the expected timestamp format
    return timestamps

# Function to calculate time gaps between timestamps
def calculate_time_gaps(timestamps):
    time_gaps = []
    for i in range(1, len(timestamps)):
        diff = timestamps[i] - timestamps[i - 1]
        time_gap_seconds = diff.total_seconds()
        if time_gap_seconds > 5:
            time_gaps.append((timestamps[i - 1], timestamps[i], time_gap_seconds))
    return time_gaps

# Function to print time gaps
def print_time_gaps(time_gaps):
    print("Time gaps greater than zero seconds between log entries:")
    for gap in time_gaps:
        print(f"Gap between {gap[0]} and {gap[1]}: {gap[2]} seconds")

# Main function
def main():
    log_file = "postgresql-Sun.leaderlog"
    timestamps = extract_timestamps_from_log(log_file)
    time_gaps = calculate_time_gaps(timestamps)
    print_time_gaps(time_gaps)

# Execute main function
if __name__ == "__main__":
    main()
