#!/bin/bash
# tor-rotate.sh - A pure bash script for Tor identity rotation and shell
# 
# This script provides:
# 1. A way to get a new Tor identity using the Tor control protocol
# 2. An interactive shell where each command runs with a new Tor identity
#
# Usage:
#   ./tor-rotate.sh                # Start the Tor shell
#   ./tor-rotate.sh newid          # Just get a new identity
#   ./tor-rotate.sh cmd "command"  # Run a single command with new identity

# Configuration
TOR_CONTROL_PORT=9051
TOR_SOCKS_PORT=9050
TOR_CONTROL_PASSWORD="cegQlnjtzWhtTaNO"
TOR_HASHED_PASSWORD=""
HISTORY_FILE="$HOME/.tor_shell_history"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Banner
function show_banner() {
    echo -e "${CYAN}=============================================${RESET}"
    echo -e "${CYAN}          TOR IDENTITY ROTATOR             ${RESET}"
    echo -e "${CYAN}=============================================${RESET}"
    echo -e "${GREEN}[+]${RESET} Each command runs with a ${YELLOW}NEW${RESET} Tor identity"
    echo -e "${GREEN}[+]${RESET} Type ${YELLOW}exit${RESET} to quit"
    echo -e "${GREEN}[+]${RESET} Type ${YELLOW}newid${RESET} to get a new identity"
    echo -e "${GREEN}[+]${RESET} Type ${YELLOW}myip${RESET} to check your current IP"
    echo -e "${CYAN}=============================================${RESET}"
}

# Check dependencies
function check_dependencies() {
    local missing_deps=()
    
    # Check for required tools
    for cmd in tor nc torsocks curl grep; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    # If there are missing dependencies, inform and install them
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}[!]${RESET} Missing dependencies: ${missing_deps[*]}"
        echo -e "${YELLOW}[!]${RESET} Installing missing dependencies..."
        
        sudo apt-get update
        sudo apt-get install -y ${missing_deps[*]}
        
        # Check if installation succeeded
        for cmd in "${missing_deps[@]}"; do
            if ! command -v $cmd &> /dev/null; then
                echo -e "${RED}[!]${RESET} Failed to install $cmd. Please install it manually."
                exit 1
            fi
        done
    fi
}

# Configure Tor
function configure_tor() {
    echo -e "${GREEN}[+]${RESET} Checking Tor configuration..."
    
    # Check if torrc file exists
    if [ ! -f /etc/tor/torrc ]; then
        echo -e "${RED}[!]${RESET} Tor configuration file not found. Is Tor installed?"
        exit 1
    fi
    
    # Generate hashed password if not provided
    if [ -z "$TOR_HASHED_PASSWORD" ]; then
        TOR_HASHED_PASSWORD=$(tor --hash-password "$TOR_CONTROL_PASSWORD" | tail -n 1)
    fi
    
    # Check if Tor control port is enabled
    if ! grep -q "^ControlPort $TOR_CONTROL_PORT" /etc/tor/torrc; then
        echo -e "${YELLOW}[!]${RESET} ControlPort not configured in torrc"
        echo -e "${GREEN}[+]${RESET} Adding ControlPort to Tor configuration..."
        
        # Backup existing torrc
        sudo cp /etc/tor/torrc /etc/tor/torrc.backup.$(date +%Y%m%d%H%M%S)
        
        # Add configuration
        echo "ControlPort $TOR_CONTROL_PORT" | sudo tee -a /etc/tor/torrc > /dev/null
    fi
    
    # Check if control port password is configured
    if ! grep -q "^HashedControlPassword" /etc/tor/torrc; then
        echo -e "${YELLOW}[!]${RESET} HashedControlPassword not configured in torrc"
        echo -e "${GREEN}[+]${RESET} Adding HashedControlPassword to Tor configuration..."
        
        # Add configuration
        echo "HashedControlPassword $TOR_HASHED_PASSWORD" | sudo tee -a /etc/tor/torrc > /dev/null
    elif ! grep -q "^HashedControlPassword $TOR_HASHED_PASSWORD" /etc/tor/torrc; then
        echo -e "${YELLOW}[!]${RESET} Updating HashedControlPassword in torrc"
        
        # Update password
        sudo sed -i "s/^HashedControlPassword .*$/HashedControlPassword $TOR_HASHED_PASSWORD/" /etc/tor/torrc
    fi
    
    # Restart Tor service if we made changes
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+]${RESET} Restarting Tor service..."
        sudo systemctl restart tor
        
        # Wait for Tor to start up
        sleep 3
        
        # Check if Tor is running
        if ! systemctl is-active --quiet tor; then
            echo -e "${RED}[!]${RESET} Tor service failed to start. Check logs with 'sudo journalctl -u tor'"
            exit 1
        fi
    fi
}

# Get a new Tor identity
function new_identity() {
    local debug=$1
    
    echo -e "${GREEN}[+]${RESET} Requesting new Tor identity..."
    
    # Connect to Tor control port and send commands
    (
        echo "AUTHENTICATE \"$TOR_CONTROL_PASSWORD\""
        echo "SIGNAL NEWNYM"
        echo "QUIT"
    ) | nc 127.0.0.1 $TOR_CONTROL_PORT > /tmp/tor_response.txt
    
    # Check if authentication was successful
    if grep -q "250 OK" /tmp/tor_response.txt; then
        # Wait for circuits to be rebuilt (randomize wait time for better anonymity)
        local wait_time=$(( RANDOM % 5 + 3 ))
        echo -e "${GREEN}[+]${RESET} Waiting ${wait_time}s for circuits to rebuild..."
        sleep $wait_time
        
        # Verify identity change if debug is enabled
        if [ "$debug" = "true" ]; then
            check_ip
        fi
        
        return 0
    else
        echo -e "${RED}[!]${RESET} Failed to get new identity. Response:"
        cat /tmp/tor_response.txt
        return 1
    fi
}

# Check current Tor IP
function check_ip() {
    echo -e "${GREEN}[+]${RESET} Checking current Tor exit IP..."
    
    # Use torsocks with curl to get IP
    local ip_info=$(torsocks curl -s https://httpbin.org/ip)
    
    # Extract IP address
    local ip=$(echo $ip_info | grep -oP '(?<="origin": ")[^"]*')
    
    if [ -n "$ip" ]; then
        echo -e "${GREEN}[+]${RESET} Current Tor exit IP: ${YELLOW}$ip${RESET}"
    else
        echo -e "${RED}[!]${RESET} Failed to get current IP"
        echo "$ip_info"
    fi
}

# Run a command through Tor with a new identity
function run_command() {
    local command="$1"
    local debug="$2"
    
    # Skip empty commands
    if [ -z "$command" ]; then
        return 0
    fi
    
    # Handle special commands
    if [ "$command" = "newid" ]; then
        new_identity "true"
        return 0
    elif [ "$command" = "myip" ]; then
        check_ip
        return 0
    elif [ "$command" = "clear" ]; then
        clear
        return 0
    elif [ "$command" = "exit" ] || [ "$command" = "quit" ]; then
        exit 0
    fi
    
    # Get a new identity before running command
    new_identity "$debug"
    
    # Set environment variables for torsocks
    export TORSOCKS_ISOLATE_CLIENT=1
    export TOR_SOCKS_PORT=$TOR_SOCKS_PORT
    
    # Generate a random user ID for better isolation
    local random_id=$RANDOM
    export TORSOCKS_USERNAME="user$random_id"
    
    # Run the command through torsocks
    echo -e "${GREEN}[+]${RESET} Running command: ${YELLOW}$command${RESET}"
    torsocks $command
    
    # Get the exit status
    local status=$?
    
    if [ $status -ne 0 ]; then
        echo -e "${RED}[!]${RESET} Command exited with status $status"
    fi
    
    return $status
}

# Start an interactive shell with Tor identity rotation
function start_shell() {
    # Show banner
    show_banner
    
    # Get initial identity
    new_identity "true"
    
    # Setup command history
    if [ -f "$HISTORY_FILE" ]; then
        history -r "$HISTORY_FILE"
    fi
    
    # Main shell loop
    while true; do
        # Custom prompt with indicator that we're in the Tor shell
        echo -en "${GREEN}tor-rotate${RESET}$ "
        read -r command
        
        # Skip empty commands
        if [ -z "$command" ]; then
            continue
        fi
        
        # Add to history
        history -s "$command"
        history -w "$HISTORY_FILE"
        
        # Run the command
        run_command "$command" "false"
    done
}

# Main function
function main() {
    # Check dependencies
    check_dependencies
    
    # Configure Tor
    configure_tor
    
    # Handle arguments
    case "$1" in
        newid)
            new_identity "true"
            ;;
        cmd)
            if [ -z "$2" ]; then
                echo -e "${RED}[!]${RESET} No command specified"
                echo -e "Usage: $0 cmd \"command\""
                exit 1
            fi
            run_command "$2" "true"
            ;;
        *)
            start_shell
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${GREEN}[+]${RESET} Exiting Tor shell..."; exit 0' INT

# Run main function
main "$@"
