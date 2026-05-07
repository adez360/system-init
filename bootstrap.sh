#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this script as root (use sudo)."
    exit 1
fi

echo "Updating package lists..."
apt update

# Install package
echo "Installing zsh, tmux, fzf, fd-find, and ncdu..."
apt install -y zsh tmux fzf fd-find ncdu curl git

# Create symlink
if command -v fdfind >/dev/null 2>&1 && [ ! -e /usr/local/bin/fd ]; then
    ln -s $(which fdfind) /usr/local/bin/fd
    echo "Created symlink for fdfind -> /usr/local/bin/fd"
fi

# Install ripgrep
echo "Downloading and installing ripgrep 14.1.1..."
curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep_14.1.1-1_amd64.deb
dpkg -i ripgrep_14.1.1-1_amd64.deb

# Delete ripgrep.deb
if [ $? -eq 0 ]; then
    rm -f ripgrep_14.1.1-1_amd64.deb
    echo "ripgrep installed and .deb file removed."
else
    echo "Warning: ripgrep installation failed. .deb file was kept for debugging."
fi

# Instal omz to /opt
echo "Setting up Oh My Zsh in /opt/oh-my-zsh..."
if [ ! -d "/opt/oh-my-zsh" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh
    chmod -R 755 /opt/oh-my-zsh
    echo "Oh My Zsh successfully installed to /opt/oh-my-zsh."
else
    echo "Oh My Zsh is already installed in /opt/oh-my-zsh."
fi

# Deploy skel dotfiles from GitHub
echo "Deploying skel dotfiles from GitHub..."
if [ ! -d "/root/.skel-dotfiles.git" ]; then
    git clone --bare https://github.com/adez360/skeldotfiles.git /root/.skel-dotfiles.git
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel checkout -f
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel config --local status.showUntrackedFiles no
    
    echo "Dotfiles successfully deployed to /etc/skel."
else
    # If existk, Update it.
    echo "Skel dotfiles already exist. Updating to latest version..."
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel fetch origin main
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel reset --hard FETCH_HEAD
fi

# Setup 
chown -R root:root /etc/skel
chmod -R 755 /etc/skel

# Change adduser commnad config
echo "Configuring default shell for new users..."
if grep -q "^DSHELL=" /etc/adduser.conf; then
    sed -i 's|^DSHELL=.*|DSHELL=/usr/bin/zsh|' /etc/adduser.conf
else
    echo "DSHELL=/usr/bin/zsh" >> /etc/adduser.conf
fi
echo "Set DSHELL=/usr/bin/zsh in /etc/adduser.conf."

# Define users to exclude
CONFIG_FILE=/etc/bootstrap.conf
if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
else
	EXCLUDE_USERS=()
	echo "Warning: No config file found"
	echo '# Add username you want to skip' > "$CONFIG_FILE"
	echo 'EXCLUDE_USERS=("example" "user")' >> "$CONFIG_FILE"
fi

# Update dotfiles for root and existing users
echo "Updating dotfiles for root and existing users..."

deploy_to() {
    local target_dir=$1
    local user_name=$2
    
    echo "Updating dotfiles for user: $user_name ($target_dir)"
    git --git-dir=/root/.skel-dotfiles.git --work-tree="$target_dir" checkout -f
    chown -R "$user_name":"$user_name" "$target_dir"
}

# 1. Update root
deploy_to "/root" "root"

# 2. Update existing users in /home
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        user_name=$(basename "$user_home")
        
        # Check if user is in the exclude list
        should_skip=false
        for exclude in "${EXCLUDE_USERS[@]}"; do
            if [ "$user_name" == "$exclude" ]; then
                should_skip=true
                break
            fi
        done

        if [ "$should_skip" = true ]; then
            echo "Skipping excluded user: $user_name"
            continue
        fi

        if [ "$user_name" != "lost+found" ]; then
            deploy_to "$user_home" "$user_name"
        fi
    fi
done

# Add alias for root
if ! grep -q "alias skelgit=" /root/.zshrc 2>/dev/null; then
    echo "alias skelgit='/usr/bin/git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel'" >> /root/.zshrc
    echo "alias skelgit='/usr/bin/git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel'" >> /root/.bashrc
fi

echo "========================================"
echo "Installation and configuration complete!"
echo "========================================"
