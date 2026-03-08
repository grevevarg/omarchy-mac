#!/usr/bin/bash

set -euo pipefail

DROPIN_FOLDER="/etc/default/grub.d"
DROPIN_FILE="$DROPIN_FOLDER/enable_notch.cfg"

# dont run this if the file already exists, aka if someone reruns install we should respect their previous settings instead of overwriting
if [ -f "$DROPIN_FILE" ]; then
  exit 0
fi

# this includes models all the way up to M4, i guess we can pray that the kernel parameter is stable
models=(
  "MacBookPro18,3"
  "MacBookPro18,1"
  "MacBookPro18,2"
  "Mac14,5"
  "Mac14,9"
  "Mac14,6"
  "Mac14,10"
  "Mac15,3"
  "Mac15,6"
  "Mac15,8"
  "Mac15,10"
  "Mac15,7"
  "Mac15,9"
  "Mac15,11"
  "Mac16,1"
  "Mac16,6"
  "Mac16,8"
  "Mac16,5"
  "Mac16,7"
  "Mac17,2"
)

get_id_model() {
  udevadm info -q property -n /dev/disk0 2>/dev/null | grep -i '^ID_MODEL=' | head -n1 | cut -d= -f2- \
  || udevadm info -e 2>/dev/null | grep -i '^ID_MODEL=' | head -n1 | cut -d= -f2- || true
}

current_model="$(get_id_model)"

# don't run this if no model id at all
if [[ -z "$current_model" ]]; then
  exit 0
fi

# whitespace normalization
current_model="${current_model%\"}"
current_model="${current_model#\"}"
current_model="${current_model#"${current_model%%[![:space:]]*}"}"
current_model="${current_model%"${current_model##*[![:space:]]}"}"

# dont run if no model matches

matched=false
for m in "${models[@]}"; do
  if [[ "$current_model" == "$m" ]]; then
    matched=true
    break
  fi
done

if ! $matched; then
  exit 0
fi

add_hyprland_notch_workarounds() {
  local conf="$HOME/.config/hypr/hyprland.conf"
  local begin="# BEGIN omarchy-mac-toggle-notch"
  local end="# END omarchy-mac-toggle-notch"

  grep -qF "$begin" "$conf" && return 0

  cat >> "$conf" <<EOF
$begin
# Notch-specific workarounds added by omarchy-mac-toggle-notch
# First applied: $(date +%F)
debug:disable_scale_checks = true
debug:error_position = 1
$end
EOF
  }

if [ ! -d "$DROPIN_FOLDER" ]; then
  sudo mkdir -p "$DROPIN_FOLDER"
fi

CURRENT_LINE=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d= -f2- | tr -d '"')
NEW_LINE="$CURRENT_LINE apple_dcp.show_notch=1"
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_LINE\"" | sudo tee "$DROPIN_FILE" > /dev/null

mv ~/.local/share/omarchy/config/waybar/config_notch.jsonc ~/.config/waybar/config.jsonc
add_hyprland_notch_workarounds

sudo grub-mkconfig -o /boot/grub/grub.cfg
