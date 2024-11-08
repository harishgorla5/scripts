#!/bin/bash

# Exit on error
set -e

# Prompt for admin username and password
read -p "Enter the Jenkins username: " ADMIN_USERNAME
read -s -p "Enter the Jenkins password: " ADMIN_PASSWORD
echo

# Function to display status
display_status() {
  local process_name=$1
  local status=$2
  local progress=$3
  printf "| %-50s | %-10s | %-14s |\n" "$process_name" "$status" "$progress"
}

# Function to print the table header
print_table_header() {
  echo "+--------------------------------------------------+------------+----------------+"
  echo "| Process Name                                       | Status     | Install Status  |"
  echo "+--------------------------------------------------+------------+----------------+"
}

# Function to print the table footer
print_table_footer() {
  echo "+--------------------------------------------------+------------+----------------+"
}

# Function to add a new row to the table
add_row() {
  local process_name=$1
  local status=$2
  local progress=$3
  display_status "$process_name" "$status" "$progress"
}

# Print table header
print_table_header

# Step 1: Install Git
{
  if command -v git &> /dev/null; then
      GIT_VERSION=$(git --version | awk '{print $3}')  # Extract only version number
      add_row "Git Installing" "DONE" "$GIT_VERSION"
  else
      add_row "Git Installing" "RUNNING" "0%"
      yum install git -y &> /dev/null
      GIT_VERSION=$(git --version | awk '{print $3}')
      add_row "Git Installing" "COMPLETED" "$GIT_VERSION"
  fi
}

# Step 2: Install Maven
{
  if command -v mvn &> /dev/null; then
      MAVEN_VERSION=$(mvn -v | head -n 1 | awk '{print $3}')  # Extract only version number
      add_row "Maven Installing" "DONE" "$MAVEN_VERSION"
  else
      add_row "Maven Installing" "RUNNING" "0%"
      yum install maven -y &> /dev/null
      MAVEN_VERSION=$(mvn -v | head -n 1 | awk '{print $3}')
      add_row "Maven Installing" "COMPLETED" "$MAVEN_VERSION"
  fi
}

# Step 3: Install Docker
{
  if command -v docker &> /dev/null; then
      DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')  # Extract only version number
      add_row "Docker Installing" "DONE" "$DOCKER_VERSION"
  else
      add_row "Docker Installing" "RUNNING" "0%"
      yum install docker -y &> /dev/null
      DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
      add_row "Docker Installing" "COMPLETED" "$DOCKER_VERSION"
  fi
}

# Step 4: Enable and Start Docker
{
  add_row "Enabling Docker" "RUNNING" "0%"
  sudo systemctl enable docker &> /dev/null
  add_row "Enabling Docker" "COMPLETED" "Enabled"
}

{
  add_row "Starting Docker" "RUNNING" "0%"
  sudo systemctl start docker &> /dev/null
  add_row "Starting Docker" "COMPLETED" "Started"
}

# Step 5: Download JDK
{
  if java -version &> /dev/null; then
      JDK_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')  # Extract only version number
      add_row "JDK Download" "DONE" "$JDK_VERSION"
  else
      add_row "JDK Download" "RUNNING" "0%"
      sudo wget -q https://download.oracle.com/java/17/archive/jdk-17.0.12_linux-x64_bin.rpm -O jdk.rpm
      add_row "JDK Download" "COMPLETED" "Downloaded"
  fi
}

# Step 6: Install JDK with Debugging
{
  if ! java -version &> /dev/null; then
      add_row "Installing JDK" "RUNNING" "0%"
      if sudo rpm -ivh jdk.rpm &> /dev/null; then
          JDK_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')  # Extract only version number
          add_row "Installing JDK" "COMPLETED" "$JDK_VERSION"
      else
          add_row "Installing JDK" "FAILED" "Installation Error"
          echo "JDK Installation failed. Check the logs for details."
          exit 1
      fi
  else
      JDK_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')  # Extract only version number
      add_row "Installing JDK" "DONE" "$JDK_VERSION"
  fi
}

# Step 7: Download Jenkins WAR file
{
  add_row "Downloading Jenkins WAR file" "RUNNING" "0%"
  
  wget -q --show-progress --progress=bar:force:noscroll https://get.jenkins.io/war-stable/2.462.3/jenkins.war 2>&1 | 
  while IFS= read -r line; do
      if [[ $line == *"%"* ]]; then
          progress="${line##* }"  # Get the progress percentage
          add_row "Downloading Jenkins WAR file" "RUNNING" "$progress"
      fi
  done
  
  add_row "Downloading Jenkins WAR file" "COMPLETED" "100%"
}

# Step 8: Start Jenkins
{
  add_row "Starting Jenkins for initial setup" "RUNNING" "0%"
  nohup java -jar jenkins.war > jenkins.log 2>&1 &
  sleep 2  # Give some time to start
  add_row "Starting Jenkins for initial setup" "COMPLETED" "100%"
}

# Step 9: Wait for Jenkins to start
{
  add_row "Waiting for Jenkins to start" "RUNNING" "0%"
  sleep 90  # Adjust as needed
  if grep -q "Jenkins is fully up and running" jenkins.log; then
      add_row "Waiting for Jenkins to start" "COMPLETED" "100%"
  else
      add_row "Waiting for Jenkins to start" "FAILED" "0%"
      echo "Jenkins failed to start. Check jenkins.log for details."
      exit 1
  fi
}

# Step 10: Configure Jenkins Security
JENKINS_HOME=~/.jenkins
{
  add_row "Configuring Jenkins security in config.xml" "RUNNING" "0%"
  mkdir -p "$JENKINS_HOME"
  cat <<EOF > "$JENKINS_HOME/config.xml"
<?xml version='1.1' encoding='UTF-8'?>
<hudson>
  <authorizationStrategy class="hudson.security.FullControlOnceLoggedInAuthorizationStrategy">
    <allowAnonymousRead>false</allowAnonymousRead>
  </authorizationStrategy>
  <securityRealm class="hudson.security.HudsonPrivateSecurityRealm">
    <disableSignup>true</disableSignup>
    <enableCaptcha>false</enableCaptcha>
  </securityRealm>
  <slaveAgentPort>-1</slaveAgentPort>
</hudson>
EOF
  add_row "Configuring Jenkins security in config.xml" "COMPLETED" "100%"
}

# Step 11: Restart Jenkins
{
  add_row "Restarting Jenkins to apply security configuration" "RUNNING" "0%"
  pkill -f jenkins.war
  sleep 5
  nohup java -jar jenkins.war > jenkins.log 2>&1 &
  add_row "Restarting Jenkins to apply security configuration" "COMPLETED" "100%"
}

# Step 12: Install plugins and create admin user
{
  add_row "Creating admin user and configuring plugins" "RUNNING" "0%"
  mkdir -p "$JENKINS_HOME/init.groovy.d"
  cat <<EOF > "$JENKINS_HOME/init.groovy.d/setup-security-and-plugins.groovy"
import jenkins.model.*
import hudson.security.*
import jenkins.install.*

println("Setting up Jenkins user: $ADMIN_USERNAME")
def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("$ADMIN_USERNAME", "$ADMIN_PASSWORD")
instance.setSecurityRealm(hudsonRealm)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()
println("Admin user setup completed.")

// Install suggested plugins
def pluginManager = instance.getPluginManager()
def updateCenter = instance.getUpdateCenter()
def pluginsToInstall = ["git", "workflow-aggregator", "docker-workflow"]  // Add other required plugins here

pluginsToInstall.each { pluginName ->
    println("Installing plugin: " + pluginName)
    def plugin = updateCenter.getPlugin(pluginName)
    if (plugin != null) {
        plugin.deploy()
    }
}
println("All plugins installed.")
EOF
  add_row "Creating admin user and configuring plugins" "COMPLETED" "100%"
}

# Step 13: Restart Jenkins to apply the plugin installation
{
  add_row "Restarting Jenkins for plugin installation" "RUNNING" "0%"
  pkill -f jenkins.war
  sleep 5
  nohup java -jar jenkins.war > jenkins.log 2>&1 &
  add_row "Restarting Jenkins for plugin installation" "COMPLETED" "100%"
}

# Print table footer
print_table_footer

# Print admin credentials and Jenkins URL
echo "Jenkins installation and configuration completed!"
echo "Access Jenkins at: http://localhost:8080"
echo "Admin Username: $ADMIN_USERNAME"
echo "Admin Password: $ADMIN_PASSWORD"
