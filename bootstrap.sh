#!/bin/bash

# 確保腳本以 root 權限執行
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this script as root (use sudo)."
    exit 1
fi

echo "Updating package lists..."
apt update

# 安裝標準套件與工具
echo "Installing zsh, tmux, fzf, fd-find, and ncdu..."
apt install -y zsh tmux fzf fd-find ncdu curl git

# 為 fdfind 建立軟連結 (Symlink)，方便直接輸入 fd
if command -v fdfind >/dev/null 2>&1 && [ ! -e /usr/local/bin/fd ]; then
    ln -s $(which fdfind) /usr/local/bin/fd
    echo "Created symlink for fdfind -> /usr/local/bin/fd"
fi

# 下載並安裝 ripgrep 14.1.1 (.deb)
echo "Downloading and installing ripgrep 14.1.1..."
curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep_14.1.1-1_amd64.deb
dpkg -i ripgrep_14.1.1-1_amd64.deb

# 安裝成功後自動刪除 .deb 檔案
if [ $? -eq 0 ]; then
    rm -f ripgrep_14.1.1-1_amd64.deb
    echo "ripgrep installed and .deb file removed."
else
    echo "Warning: ripgrep installation failed. .deb file was kept for debugging."
fi

# 全域安裝 Oh My Zsh 到 /opt
echo "Setting up Oh My Zsh in /opt/oh-my-zsh..."
if [ ! -d "/opt/oh-my-zsh" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh
    chmod -R 755 /opt/oh-my-zsh
    echo "Oh My Zsh successfully installed to /opt/oh-my-zsh."
else
    echo "Oh My Zsh is already installed in /opt/oh-my-zsh."
fi

# 核心步驟：自動部署使用者的骨架設定檔 (/etc/skel)
echo "Deploying skel dotfiles from GitHub..."
if [ ! -d "/root/.skel-dotfiles.git" ]; then
    # 直接從 GitHub Clone 一個裸儲存庫到 root 家目錄
    git clone --bare https://github.com/adez360/skeldotfiles.git /root/.skel-dotfiles.git
    
    # 將設定檔強制釋放到 /etc/skel，覆蓋預設檔案
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel checkout -f
    
    # 設定忽略未追蹤檔案，保持 Git 狀態乾淨
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel config --local status.showUntrackedFiles no
    
    echo "Dotfiles successfully deployed to /etc/skel."
else
    # 如果已經部署過，則自動拉取 (Pull) 最新版本
    echo "Skel dotfiles already exist. Updating to latest version..."
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel fetch origin main
    git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel reset --hard origin/main
fi

# 設定 /etc/skel 的權限，確保未來的新使用者能正確複製
chown -R root:root /etc/skel
chmod -R 755 /etc/skel

# 更改新使用者的預設終端機
echo "Configuring default shell for new users..."
if grep -q "^DSHELL=" /etc/adduser.conf; then
    sed -i 's|^DSHELL=.*|DSHELL=/usr/bin/zsh|' /etc/adduser.conf
else
    echo "DSHELL=/usr/bin/zsh" >> /etc/adduser.conf
fi
echo "Set DSHELL=/usr/bin/zsh in /etc/adduser.conf."

# 為 root 自己建立 alias 方便未來管理
if ! grep -q "alias skelgit=" /root/.zshrc 2>/dev/null; then
    echo "alias skelgit='/usr/bin/git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel'" >> /root/.zshrc
    echo "alias skelgit='/usr/bin/git --git-dir=/root/.skel-dotfiles.git --work-tree=/etc/skel'" >> /root/.bashrc
fi

echo "========================================"
echo "Installation and configuration complete!"
echo "========================================"
