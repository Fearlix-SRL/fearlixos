#!/usr/bin/env bash
# Compila e installa il modulo out-of-tree acer-wmi-battery
# (https://github.com/frederik-h/acer-wmi-battery), che permette di attivare
# la "modalità salute batteria" (carica limitata all'80%) sui portatili Acer.
#
# Sicurezza per le altre macchine:
#  - il modulo si carica in automatico solo se il firmware espone il GUID WMI
#    della batteria Acer (MODULE_ALIAS wmi:...); altrove non viene mai caricato
#    e, se caricato a mano, termina con -ENODEV senza fare nulla;
#  - il modulo non cambia alcuna impostazione da solo: la modalità si attiva a
#    mano con `echo 1 > /sys/bus/wmi/drivers/acer-wmi-battery/health_mode`
#    e resta salvata nel firmware;
#  - se la compilazione fallisce (es. kernel nuovo incompatibile) l'immagine
#    viene comunque prodotta, solo senza il modulo.

set -uo pipefail

# Commit fissato per build riproducibili; aggiornare a mano se necessario.
COMMIT="9f90d75cc9237aeed7964622d10dbdf4d2c7b518"
SRC_URL="https://github.com/frederik-h/acer-wmi-battery/archive/${COMMIT}.tar.gz"

build() {
    local kver
    kver="$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n1)"
    echo "acer-wmi-battery: compilazione per il kernel ${kver}"

    local workdir
    workdir="$(mktemp -d)"
    trap 'rm -rf "${workdir}"' RETURN

    # kernel-devel deve corrispondere esattamente al kernel dell'immagine:
    # prima dai repo, altrimenti da Koji.
    local -a devel
    if ! dnf -y download --destdir "${workdir}" "kernel-devel-${kver}" >/dev/null 2>&1; then
        local ver="${kver%%-*}" rel_arch="${kver#*-}"
        local rel="${rel_arch%.*}" arch="${rel_arch##*.}"
        curl -fsSL -o "${workdir}/kernel-devel.rpm" \
            "https://kojipkgs.fedoraproject.org/packages/kernel/${ver}/${rel}/${arch}/kernel-devel-${kver}.rpm"
    fi
    devel=("${workdir}"/kernel-devel*.rpm)

    dnf -y install --setopt=install_weak_deps=False "${devel[@]}" gcc make elfutils-libelf-devel

    curl -fsSL "${SRC_URL}" | tar -xz -C "${workdir}"
    local src="${workdir}/acer-wmi-battery-${COMMIT}"
    make -C "/usr/lib/modules/${kver}/build" M="${src}" modules

    install -D -m 0644 "${src}/acer-wmi-battery.ko" \
        "/usr/lib/modules/${kver}/extra/acer-wmi-battery/acer-wmi-battery.ko"
    depmod -a "${kver}"

    # Rimuove solo ciò che è servito per compilare
    dnf -y remove "kernel-devel-${kver}" gcc make elfutils-libelf-devel || true
    echo "acer-wmi-battery: installato"
}

# Subshell fuori da un contesto condizionale, così "set -e" resta attivo
( set -e; build )
if [ $? -ne 0 ]; then
    echo "ATTENZIONE: acer-wmi-battery non compilato, l'immagine prosegue senza il modulo" >&2
fi
exit 0
