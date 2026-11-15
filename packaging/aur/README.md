# Arch Linux / AUR

`hwsvideo-dkms/` contains the AUR submission files for version 1.3.0. The
source is pinned to a public commit of Scyllinice's fork, rather than a moving
branch. Update `_commit`, `pkgver`, and `.SRCINFO` together for a new release.

To build the **current checkout**, including local edits, run from the repository
root as a regular user with `base-devel` and `dkms` installed:

```sh
packaging/build-package.sh dist
sudo pacman -U dist/hwsvideo-dkms-1.3.0-1-x86_64.pkg.tar.zst
```

This works on Arch Linux and CachyOS, uses the AUR recipe's packaging and DKMS
configuration, and needs no source download. It does not apply the AUR patch,
which is already present in the checkout. Kernel headers are needed when
installing the package, rather than when creating it.

Build as a regular user on Arch Linux (with `base-devel` installed):

```sh
cd packaging/aur/hwsvideo-dkms
makepkg -s
```

Install the headers matching each kernel you use (`linux-headers`,
`linux-lts-headers`, or the appropriate CachyOS/custom kernel headers), then
install the resulting package:

```sh
sudo pacman -U hwsvideo-dkms-1.3.0-1-x86_64.pkg.tar.zst
```

Pacman's DKMS hooks build and install `hwsvideo` for kernels with headers and
rebuild it on kernel updates. The package does not load or unload modules.
Reboot after installation to use it. The included modprobe configuration
blacklists the competing in-kernel `hws` module. Remove any separately installed
vendor drivers that claim the same capture card before rebooting.

The package prints a Secure Boot notice on install and upgrade when Secure Boot
is enabled or its state cannot be determined. The notice runs before DKMS's
post-transaction build hook, so check the build results before rebooting.
DKMS normally signs the module automatically, but your kernel must trust the
signing certificate. DKMS prints its actual certificate path during the build;
the default is `/var/lib/dkms/mok.pub`. With a shim/MOK setup, install `mokutil`,
run `sudo mokutil --import <certificate-path>`, choose a password, reboot, and
complete enrollment in MOK Manager. Once that certificate is trusted, subsequent
rebuilds use it without repeating enrollment.

MOK enrollment requires shim support. With other Secure Boot arrangements,
configure `/etc/dkms/framework.conf` to use a key your kernel trusts; signing a
bootloader or kernel with `sbctl` alone does not establish module trust. The
package never enrolls keys or changes bootloader settings. A build or trust
failure can leave the capture card unavailable because the package blacklists
`hws`. To return to the in-kernel driver, remove `hwsvideo-dkms` and reboot.

Do not run `install.sh` alongside the package; pacman owns the installed sources.

Prepare an AUR submission:

```sh
makepkg --printsrcinfo > .SRCINFO
makepkg --source
```

Commit `PKGBUILD`, `.SRCINFO`, `hwsvideo-dkms.install`, and `clang-timings.patch` to an AUR Git repository named
`hwsvideo-dkms`. Publication requires an AUR account and its SSH key; building
the package locally does not publish it. Set the maintainer contact in PKGBUILD
before submission.

The install script only prints guidance; the `dkms` dependency provides both
build/install and removal hooks. The DKMS make command explicitly uses
the target kernel's headers, so updates also work for kernels not running.
Clang-built kernels automatically use `LLVM=1`; install `clang`, `llvm`, and
`lld` for those kernels. The included patch replaces a GCC-specific timings
initializer macro with a direct initializer so the driver also builds with Clang.
