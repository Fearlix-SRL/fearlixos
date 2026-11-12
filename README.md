# Fearlix-OS &nbsp; [![bluebuild build badge](https://github.com/Fearlix-SRL/fearlixOS/actions/workflows/build.yml/badge.svg)](https://github.com/Fearlix-SRL/fearlixOS/actions/workflows/build.yml)

Custom Fedora Silverblue image by Fearlix SRL, built with [BlueBuild](https://blue-build.org/) on top of `ghcr.io/ublue-os/silverblue-main`.

It adds, among other things:

- GNOME extensions (Pop Shell, GSConnect, Blur my Shell, Caffeine, Color Picker, User Themes, Dash to Dock)
- Distrobox, Starship, Neovim, Alacritty, Btrfs Assistant, Vorta
- virtualization tools (libvirt, QEMU/KVM, virt-manager)
- FiraMono Nerd Font
- [Livepaper](https://github.com/lucapatarca/livepaper) (disabled by default)
- the [acer-wmi-battery](https://github.com/frederik-h/acer-wmi-battery) kernel module for the battery health mode on Acer laptops
- a first-boot setup wizard (yafti) for Flatpaks and optional tweaks

The image configuration lives in [`recipes/recipe.yml`](recipes/recipe.yml).

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/fearlix-srl/fearlixos:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/fearlix-srl/fearlixos:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/fearlix-srl/fearlixos
```
