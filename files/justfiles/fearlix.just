# Fearlix-OS optional setup, replaces the old yafti first-boot wizard.
# Run `ujust fearlix-setup` for everything, or the single recipes below.

# Run the whole Fearlix-OS optional setup
[group('fearlix')]
fearlix-setup: fearlix-apps fearlix-containers fearlix-extras

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

# Create Fearlix dev containers that do not exist yet: no args = choose, or pass names / "all"
[group('fearlix')]
fearlix-containers *NAMES:
    #!/usr/bin/env bash
    set -euo pipefail
    INI=/etc/distrobox/fearlix.ini
    mapfile -t KNOWN < <(sed -nE 's/^\[(.+)\]$/\1/p' "${INI}")
    NAMES=({{ NAMES }})
    if [ "${NAMES[*]:-}" = "all" ]; then
        NAMES=("${KNOWN[@]}")
    elif [ "${#NAMES[@]}" -eq 0 ]; then
        MISSING=()
        for name in "${KNOWN[@]}"; do
            podman container exists "${name}" || MISSING+=("${name}")
        done
        if [ "${#MISSING[@]}" -eq 0 ]; then
            echo "All containers already exist. Use 'ujust fearlix-containers-update' to update them."
            exit 0
        fi
        mapfile -t NAMES < <(gum choose --no-limit \
            --header "Select containers to create (space = select, enter = confirm)" "${MISSING[@]}" || true)
        if [ "${#NAMES[@]}" -eq 0 ]; then
            echo "No containers selected."
            exit 0
        fi
    fi
    for name in "${NAMES[@]}"; do
        if ! printf '%s\n' "${KNOWN[@]}" | grep -qxF -- "${name}"; then
            echo "Unknown container '${name}'. Available: ${KNOWN[*]}" >&2
            exit 1
        fi
    done
    for name in "${NAMES[@]}"; do
        if podman container exists "${name}"; then
            echo "${name}: already exists, skipping."
        else
            distrobox assemble create --file "${INI}" --name "${name}"
        fi
    done

# Pull Fearlix dev container images and replace the containers whose image changed: no args = all existing, or pass names
[group('fearlix')]
fearlix-containers-update *NAMES:
    #!/usr/bin/env bash
    set -euo pipefail
    INI=/etc/distrobox/fearlix.ini
    mapfile -t KNOWN < <(sed -nE 's/^\[(.+)\]$/\1/p' "${INI}")
    NAMES=({{ NAMES }})
    if [ "${#NAMES[@]}" -eq 0 ] || [ "${NAMES[*]}" = "all" ]; then
        NAMES=()
        for name in "${KNOWN[@]}"; do
            if podman container exists "${name}"; then NAMES+=("${name}"); fi
        done
        if [ "${#NAMES[@]}" -eq 0 ]; then
            echo "No Fearlix containers found. Create them with 'ujust fearlix-containers'."
            exit 0
        fi
    fi
    for name in "${NAMES[@]}"; do
        if ! printf '%s\n' "${KNOWN[@]}" | grep -qxF -- "${name}"; then
            echo "Unknown container '${name}'. Available: ${KNOWN[*]}" >&2
            exit 1
        fi
    done
    for name in "${NAMES[@]}"; do
        if ! podman container exists "${name}"; then
            echo "${name}: not found, creating."
            distrobox assemble create --file "${INI}" --name "${name}"
            continue
        fi
        image="$(awk -F= -v s="[${name}]" '$0 == s {f=1; next} /^\[/ {f=0} f && $1 == "image" {print $2; exit}' "${INI}")"
        podman pull "${image}"
        if [ "$(podman container inspect --format '{{{{.Image}}' "${name}")" = "$(podman image inspect --format '{{{{.Id}}' "${image}")" ]; then
            echo "${name}: already up to date."
        else
            echo "${name}: new image, replacing container."
            distrobox assemble create --file "${INI}" --name "${name}" --replace
        fi
    done

# Choose and run optional extras (ct alias, Starship, Livepaper)
[group('fearlix')]
fearlix-extras:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t SELECTED < <(gum choose --no-limit \
        --header "Select extras (space = select, enter = confirm)" \
        "Add 'ct' alias for distrobox enter" \
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
