#!/usr/bin/env bash
set -Eeuo pipefail

sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install --system --noninteractive --assumeyes flathub it.mijorus.smile
