# 🛡️ Tor Rotate

## 🔍 Overview
`tor-rotate.sh` is a pure Bash script for Tor identity rotation and interactive shell usage. It allows you to obtain a new Tor identity and execute commands with a fresh identity each time.

<p align="center">
  <img src="https://github.com/pentestfunctions/tor-rotate.sh/blob/main/torstuff.gif?raw=true">
</p>

## ✨ Features
✅ Obtain a new Tor identity using the Tor control protocol  
✅ Run individual commands with a new Tor identity  
✅ Interactive shell mode where each command is executed with a different Tor identity  
✅ Built-in dependency checks and automatic installation (for supported systems)  
✅ Displays the current Tor exit IP  

## 🚀 Usage
```bash
./tor-rotate.sh                # Start the interactive Tor shell
./tor-rotate.sh newid          # Get a new Tor identity
./tor-rotate.sh cmd "command"  # Run a single command with a new identity
```

### 🖥️ Interactive Shell Commands
Once inside the shell, you can use the following commands:
- 🆕 `newid` - Request a new Tor identity
- 🌎 `myip` - Display your current Tor exit IP
- 🧹 `clear` - Clear the terminal screen
- 🚪 `exit` - Exit the interactive shell

## 🔧 Installation
### 📌 Prerequisites
Ensure the following dependencies are installed:
- `tor`
- `nc` (netcat)
- `torsocks`
- `curl`
- `grep`

If any dependencies are missing, the script will attempt to install them automatically. ⚙️

### 🔑 Setting Up Tor Control Access
Before using the script, you need to configure Tor to allow control access:

1. Edit your Tor configuration file (`/etc/tor/torrc`):
   ```bash
   sudo nano /etc/tor/torrc
   ```
2. Add the following lines if they are not already present:
   ```
   ControlPort 9051
   HashedControlPassword <hashed_password>
   ```
   (Replace `<hashed_password>` with the output of `tor --hash-password YOUR_PASSWORD`)

3. Restart the Tor service:
   ```bash
   sudo systemctl restart tor
   ```

## 📌 Example
```bash
$ ./tor-rotate.sh cmd "curl https://check.torproject.org/api/ip"
[+] Requesting new Tor identity...
[+] Running command: curl https://check.torproject.org/api/ip
{"IP": "185.220.101.10"}
```

## ⚠️ Notes
- If the script fails to authenticate with the Tor control port, check the control password settings in `/etc/tor/torrc`. 🔍
- For better anonymity, it introduces a random delay when switching identities. 🕵️‍♂️
