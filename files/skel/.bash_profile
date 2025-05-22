# ~/.bash_profile: executed by bash(1) for login shells.

# Source user .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# You can add login-specific settings here if needed
# e.g., load SSH keys or display login message

# Custom message
echo "Welcome to the higgs"
