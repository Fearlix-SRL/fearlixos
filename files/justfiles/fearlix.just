# Fearlix-OS optional setup, replaces the old yafti first-boot wizard.
# Run `ujust fearlix-setup` for everything, or the single recipes below.

# Run the whole Fearlix-OS optional setup
[group('fearlix')]
fearlix-setup: fearlix-apps fearlix-extras

# Choose and install optional Flatpak apps from Flathub
[group('fearlix')]
fearlix-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    # "Group | Name | Flatpak ID"
    APPS="
    Browsers | Brave | com.brave.Browser
    Browsers | Google Chrome | com.google.Chrome
    Browsers | Opera | com.opera.Opera
    Office | LibreOffice | org.libreoffice.LibreOffice
    Office | OnlyOffice | org.onlyoffice.desktopeditors
    Office | Obsidian | md.obsidian.Obsidian
    Office | Slack | com.slack.Slack
    Office | Telegram | org.telegram.desktop
    Office | Standard Notes | org.standardnotes.standardnotes
    Office | Thunderbird | org.mozilla.thunderbird
    Media | GIMP | org.gimp.GIMP
    Media | Inkscape | org.inkscape.Inkscape
    Media | Kdenlive | org.kde.kdenlive
    Media | Spotify | com.spotify.Client
    Media | VLC | org.videolan.VLC
    Development | Postman | com.getpostman.Postman
    Development | MongoDB Compass | com.mongodb.Compass
    Development | GitHub Desktop | io.github.shiftey.Desktop
    Development | Podman Desktop | io.podman_desktop.PodmanDesktop
    Other | PrusaSlicer | com.prusa3d.PrusaSlicer
    Other | FreeCAD | org.freecad.FreeCAD
    Other | Transmission Remote | io.github.TransmissionRemoteGtk
    Other | KiCad | org.kicad.KiCad
    Other | PuTTY | uk.org.greenend.chiark.sgtatham.putty
    "
    mapfile -t CHOICES < <(sed -e '/^[[:space:]]*$/d' -e 's/^[[:space:]]*//' -e 's/ | [^|]*$//' <<<"${APPS}")
    mapfile -t SELECTED < <(gum choose --no-limit --height 20 \
        --header "Select apps to install (space = select, enter = confirm)" "${CHOICES[@]}" || true)
    if [ "${#SELECTED[@]}" -eq 0 ]; then
        echo "No apps selected."
        exit 0
    fi
    IDS=()
    for choice in "${SELECTED[@]}"; do
        IDS+=("$(sed -e 's/^[[:space:]]*//' <<<"${APPS}" | grep -F "${choice} | " | head -n1 | sed 's/.* | //')")
    done
    flatpak install --system --noninteractive flathub "${IDS[@]}"

# Choose and run optional extras (containers, Starship, Livepaper)
[group('fearlix')]
fearlix-extras:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t SELECTED < <(gum choose --no-limit \
        --header "Select extras (space = select, enter = confirm)" \
        "Add 'ct' alias for distrobox enter" \
        "Container: base" \
        "Container: flutter" \
        "Container: database" \
        "Container: node" \
        "Container: go" \
        "Enable Starship prompt" \
        "Enable Livepaper" || true)
    if [ "${#SELECTED[@]}" -eq 0 ]; then
        echo "Nothing selected."
        exit 0
    fi
    for choice in "${SELECTED[@]}"; do
        case "${choice}" in
            "Add 'ct' alias"*)
                grep -qs "alias ct=" ~/.bashrc || echo "alias ct='distrobox enter'" >> ~/.bashrc
                ;;
            "Container: "*)
                /usr/bin/mkct "${choice#Container: }"
                ;;
            "Enable Starship prompt")
                grep -qs "starship init" ~/.bashrc || echo 'eval "$(starship init bash)"' >> ~/.bashrc
                ;;
            "Enable Livepaper")
                mkdir -p ~/.config/livepaper
                [ -f ~/.config/livepaper/config.toml ] || cp /etc/livepaper/config.toml ~/.config/livepaper/config.toml
                systemctl --user enable --now livepaper.service
                ;;
        esac
    done
    echo "Done. Open a new terminal to load .bashrc changes."
