#!/bin/bash
# Can also be run manually; existing participant files are preserved.
set -eu
. /etc/profile.d/nmap-training.sh

mkdir -p "$HOME/nmap-training-results"
for file in "$NMAP_TRAINING"/handouts/* "$NMAP_TRAINING"/examples/* \
    "$NMAP_TRAINING"/scripts/*.sh "$NMAP_TRAINING"/scripts/*.py; do
    destination="$HOME/nmap-training-results/${file##*/}"
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        cp "$file" "$destination"
    fi
done
for script in http-shop-policy.nse http-php2shell-version.nse; do
    if [ ! -e "$HOME/$script" ] && [ ! -L "$HOME/$script" ]; then
        cp "$NMAP_TRAINING/scripts/$script" "$HOME/$script"
    fi
done
if [ ! -e "$HOME/nmap-sage" ] && [ ! -L "$HOME/nmap-sage" ]; then
    cp "$NMAP_TRAINING/scripts/nmap-sage" "$HOME/nmap-sage"
fi
mkdir -p "$HOME/Desktop"
if [ ! -e "$HOME/Desktop/nmap-visualizer.html" ] && [ ! -L "$HOME/Desktop/nmap-visualizer.html" ]; then
    cp "$NMAP_TRAINING/nmap-visualizer.html" "$HOME/Desktop/nmap-visualizer.html"
fi
printf 'Training ready: %s/nmap-training-results (LAB_IF=%s, SCAN_NETWORK=%s)\n' \
    "$HOME" "$LAB_IF" "$SCAN_NETWORK"
