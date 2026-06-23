# Maintainer: Volk <realvolk@github.com>

pkgname=artixforge
pkgver=9.1.1.4
pkgrel=1
pkgdesc="Modular TUI/GUI installer framework for Artix Linux"
arch=('any')
url="https://github.com/realvolk/ArtixForge"
license=('custom:Forge Attribution License 1.0')
depends=('bash' 'gum' 'git' 'curl' 'openssl' 'rsync' 'coreutils')
optdepends=(
    'pacman-contrib: mirror ranking support'
    'artools: ISO build support'
    'gtk4: GUI installer'
    'libadwaita: GUI installer'
    'python-gobject: GUI installer'
    'python-virtualenv: GUI installer'
    'python-jsonschema: GUI installer'
)
makedepends=('git')
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/realvolk/ArtixForge/archive/refs/tags/v${pkgver}.tar.gz"
        "forge-gui-0.4.0.tar.gz::https://github.com/realvolk/forge-gui/archive/refs/tags/v0.4.0.tar.gz")
sha256sums=('ff6bc2c0e6f245e8ca651995055daa48c549b1f0bdb75492c8cb86ccfa1a51a7'
            '181c3f132a36eb5cbfbec5d7417ba02f48c1651bcf80cb8d72683fc08db6a2e9')

package() {
    install -dm755 "${pkgdir}/usr/share/artixforge"
    cp -a "${srcdir}/ArtixForge-${pkgver}"/* "${pkgdir}/usr/share/artixforge/"

    install -dm755 "${pkgdir}/usr/share/artixforge/forge-gui"
    cp -a "${srcdir}/forge-gui-0.4.0"/* "${pkgdir}/usr/share/artixforge/forge-gui/"

    install -dm755 "${pkgdir}/usr/bin"
    ln -sf "/usr/share/artixforge/install" "${pkgdir}/usr/bin/artixforge"
    chmod +x "${pkgdir}/usr/share/artixforge/install"

    install -dm755 "${pkgdir}/usr/share/doc/artixforge"
    cp -a "${srcdir}/ArtixForge-${pkgver}/DOCUMENTS"/* "${pkgdir}/usr/share/doc/artixforge/"

    install -Dm644 "${srcdir}/ArtixForge-${pkgver}/DOCUMENTS/LICENSE" \
        "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}