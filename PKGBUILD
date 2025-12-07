pkgname=zep-bin
pkgver=0.6.0
pkgrel=1
pkgdesc="Fast package manager for Zig (binary release)"
arch=('x86_64')
url="https://github.com/XerWoho/zeP"
license=('GPLv3')
provides=('zeP')
conflicts=('zeP')
source=("https://github.com/XerWoho/zeP/releases/download/${pkgver}/zep_x86_64-linux_${pkgver}.tar.xz")
sha256sums=('')

package() {
	mkdir -p "${pkgdir}/.local/zeP/zep/v/${pkgver}"
	install -Dm755 zeP "${pkgdir}/.local/zeP/zep/v/${pkgver}/zeP"
	ln -s "${pkgdir}/.local/zeP/v/${pkgver}/zeP" "${pkgdir}/.local/bin/zeP"
}
