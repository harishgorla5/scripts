#!/bin/bash
# Exit on error
set -e

# Welcome message
echo "=================================================="
echo "            Welcome to HINTechnologies!           "
echo "=================================================="
echo "You are now part of our exclusive job-oriented DevOps Trainings!"
echo
echo "This script will assist you in installing the essential packages for K8s -Kubeadm Setup and Docker."
echo "For any training inquiries, please reach out to us at:"
echo "   +91 9866240424 (or) +91 9030880875"
echo
echo "**HINTechnologies** has been a leader in job-oriented training since 2014, successfully placing over 500+ students."
echo "We offer comprehensive programs in Middleware, DevOps, and Python."
echo
echo "Join us to enhance your skills and boost your career opportunities!"
echo "            *Learn More and Earn More!*"
echo "=================================================="
echo

# Function to log the process information with proper alignment and table structure
log_process() {
    local process_name=$1
    local command=$2
    local status=$3

    # Print the log in table format with fixed-width columns and proper borders
    printf "| %-18s | %-30s | %-13s |\n" "$process_name" "$command" "$status"
}

# Print the table header with borders
echo "+--------------------+--------------------------------+---------------+"
printf "| %-18s | %-30s | %-13s |\n" "Process_Name" "Command_Executed" "Status"
echo "+--------------------+--------------------------------+---------------+"

# Variables for the process details
process_name="System Update"
command="yum update -y"
status=""

# Run the yum update command and capture the exit status without printing the execution message
if yum update -y &> /dev/null; then
    status="Completed"
else
    status="Failed"
fi

# Log the result in the table format
log_process "$process_name" "$command" "$status"

# Print the table footer with borders
echo "+--------------------+--------------------------------+---------------+"
