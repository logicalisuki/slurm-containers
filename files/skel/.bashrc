# ~/.bashrc: executed by bash(1) for non-login interactive shells.

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Enable user-specific module environment
#if command -v module >/dev/null 2>&1; then
#    module use /cm/shared/modulefiles
#    module load slurm
#fi

export PATH=/usr/local/slurm/bin:$PATH

# Set useful cluster environment variables
export PATH="/opt/venv/bin:/usr/local/slurm/bin:/usr/local/slurm/bin:/usr/local/slurm/sbin:$PATH"
export EDITOR=vim
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=10000
export HISTFILESIZE=20000

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias squeue='squeue -u $USER'
alias sinfo='sinfo -o "%P %.8D %.6t %.6m %.8z %.10l %.6a %20N"'
