#!/bin/bash

# Function to display the summary of actions
display_summary() {
    echo -e "\nSummary of Actions:\n"
    echo -e "Package\t\t\t\tStatus\t\tVersion"
    echo -e "------------------------------------------------------------"
    echo -e "JDK (from RPM)\t\t\tPending\t\tN/A"
    echo -e "Git (from YUM)\t\t\tPending\t\tN/A"
    echo -e "Maven (from YUM)\t\tPending\t\tN/A"
    echo -e "Jenkins (from WAR)\t\tPending\t\t2.462.3"
    echo -e "Docker\t\t\t\tPending\t\tN/A"
    echo -e "------------------------------------------------------------"
}

# Function to display progress
show_progress() {
    echo -n "Running "
    while :; do
        echo -n "."
        sleep 1
    done &
    progress_pid=$!
}

# Function to stop progress
stop_progress() {
    kill $progress_pid
    wait $progress_pid 2>/dev/null
    echo
}

# Function to install JDK
install_jdk() {
    echo "Starting JDK installation..."
    echo "=============================="
    show_progress
	wget -q https://download.oracle.com/java/17/archive/jdk-17.0.12_linux-x64_bin.rpm > /dev/null 2>&1
    sudo rpm -ivh jdk-17.0.12_linux-x64_bin.rpm > /dev/null 2>&1
    stop_progress
    echo "JDK installation completed."
    echo
}

# Function to install Git and Maven
install_git_and_maven() {
    echo "Starting Git and Maven installation..."
    echo "======================================="
    show_progress
    sudo yum install -y git maven > /dev/null 2>&1
    stop_progress
    echo "Git and Maven installation completed."
    echo
}

# Function to download and install Jenkins
install_jenkins() {
    echo "Starting Jenkins installation..."
    echo "==============================="
    show_progress
    wget -q https://get.jenkins.io/war-stable/2.462.3/jenkins.war > /dev/null 2>&1
    java -jar jenkins.war > /dev/null 2>&1 &
    stop_progress
    echo "Jenkins installation completed."
    echo "Starting Jenkins... "
    show_progress  # Show running status for Jenkins
    sleep 30  # Wait for Jenkins to start
    stop_progress
    echo "Jenkins is running."
    echo
}

# Function to install Docker
install_docker() {
    echo "Starting Docker installation..."
    echo "==============================="
    show_progress
    sudo yum install -y docker > /dev/null 2>&1
    sudo systemctl enable docker > /dev/null 2>&1
    sudo systemctl start docker > /dev/null 2>&1
    stop_progress
    echo "Docker installation completed."
    echo
}

# Function to display final output
display_final_output() {
    echo -e "\nFinal Output:\n"
    echo -e "Package\t\t\t\tStatus\t\tVersion"
    echo -e "------------------------------------------------------------"
    echo -e "JDK (from RPM)\t\t\tInstalled\t$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')"
    echo -e "Git (from YUM)\t\t\tInstalled\t$(git --version | awk '{print $3}')"
    echo -e "Maven (from YUM)\t\tInstalled\t$(mvn -version | grep 'Apache Maven' | awk '{print $3}')"
    echo -e "Jenkins (from WAR)\t\tRunning\t\t2.462.3"
    echo -e "Docker\t\t\t\tInstalled\t$(docker --version | awk '{print $3}')"

    # Retrieve and display the Jenkins initial admin password from the correct location
    if [ -f /root/.jenkins/secrets/initialAdminPassword ]; then
        jenkins_password=$(cat /root/.jenkins/secrets/initialAdminPassword)
        echo -e "Jenkins Password\t\tAvailable\t$jenkins_password"
    else
        echo -e "Jenkins Password\t\tNot Available\tN/A"
    fi
}

# Main script execution
display_summary

# User confirmation
read -p "Proceed with installation? (y/n): " choice
if [[ "$choice" != "y" ]]; then
    echo "Installation aborted."
    exit 1
fi

# Execute installation functions
install_jdk
install_git_and_maven
install_jenkins
install_docker

# Display final output
display_final_output
