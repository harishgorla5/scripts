#!/bin/bash
#This is the script, will install all required tools and jenkins servers and user configuration  configure

# Exit on error
set -e

# Prompt for admin username and password
read -p "Enter the admin username: " ADMIN_USERNAME
read -s -p "Enter the admin password: " ADMIN_PASSWORD
echo

# Function to display status
display_status() {
  local process_name=$1
  local status=$2
  local progress=$3
  printf "| %-36s | %-10s | %-14s |\n" "$process_name" "$status" "$progress"
}

# Function to print the table header
print_table_header() {
  echo "+--------------------------------------+------------+----------------+"
  echo "| Process Name                         | Status     | Install Status  |"
  echo "+--------------------------------------+------------+----------------+"
}

# Function to print the table footer
print_table_footer() {
  echo "+--------------------------------------+------------+----------------+"
}

# Function to add a new row to the table
add_row() {
  local process_name=$1
  local status=$2
  local progress=$3

  # Print the row in a formatted manner
  display_status "$process_name" "$status" "$progress"
}

# Print table header
print_table_header

# Step 1: Download Jenkins WAR file
{
  add_row "Downloading Jenkins WAR file" "RUNNING" "0%"
  
  # Use wget to download the WAR file with progress
  wget -q --show-progress --progress=bar:force:noscroll https://get.jenkins.io/war-stable/2.462.3/jenkins.war 2>&1 | 
  while IFS= read -r line; do
      if [[ $line == *"%"* ]]; then
          # Update the install status based on wget's output
          progress="${line##* }"  # Get the progress percentage
          add_row "Downloading Jenkins WAR file" "RUNNING" "$progress"
      fi
  done
  
  # After download completes
  add_row "Downloading Jenkins WAR file" "COMPLETED" "100%"
}

# Step 2: Start Jenkins
{
  add_row "Starting Jenkins for initial setup" "RUNNING" "0%"
  nohup java -jar jenkins.war > jenkins.log 2>&1 &
  sleep 2  # Give some time to start
  add_row "Starting Jenkins for initial setup" "COMPLETED" "100%"
}

# Step 3: Wait for Jenkins to start
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

# Step 4: Configure Jenkins Security
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

# Step 5: Restart Jenkins
{
  add_row "Restarting Jenkins to apply security configuration" "RUNNING" "0%"
  pkill -f jenkins.war
  sleep 5
  nohup java -jar jenkins.war > jenkins.log 2>&1 &
  add_row "Restarting Jenkins to apply security configuration" "COMPLETED" "100%"
}

# Step 6: Install plugins and create admin user
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
updateCenter.updateAllSites()
def pluginList = ['git', 'workflow-aggregator', 'github', 'ssh-slaves', 'matrix-auth', 'email-ext', 'subversion']
pluginList.each { plugin ->
    if (!pluginManager.getPlugin(plugin)) {
        println "Installing plugin: ${plugin}"
        def pluginDeployment = updateCenter.getPlugin(plugin).deploy()
        pluginDeployment.get()
    } else {
        println "Plugin ${plugin} already installed."
    }
}
println("Default suggested plugins installed.")
EOF
  add_row "Creating admin user and configuring plugins" "COMPLETED" "100%"
}

# Step 7: Final restart to apply all settings
{
  add_row "Final restart to apply user and plugin configuration" "RUNNING" "0%"
  pkill -f jenkins.war
  sleep 5
  nohup java -jar jenkins.war > jenkins.log 2>&1 &
  add_row "Final restart to apply user and plugin configuration" "COMPLETED" "100%"
}

# Print table footer
print_table_footer

# Output summary
echo -e "\n\e[1;32mSetup Summary\e[0m"
echo "Access Jenkins at http://localhost:8080"
echo "Admin Username: $ADMIN_USERNAME"
echo "Admin Password: $ADMIN_PASSWORD"
