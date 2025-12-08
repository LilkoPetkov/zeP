pkgname=zep-bin
pkgver=0.6
pkgrel=1
pkgdesc="Fast package manager for Zig (binary release)"
arch=('x86_64')
url="https://github.com/XerWoho/zeP"
license=('MIT')
provides=('zep')
conflicts=('zep')
source=("https://zep.run/releases/${pkgver}/zep_x86_64-linux_${pkgver}.tar.xz")
sha256sums=('29d7ec90c6e6c2f5011428a080ce06d3b7715f1bf8eeac1dde099e196dee7cb9')

package() {
    install -Dm755 "$srcdir/zeP" "$pkgdir/usr/bin/zeP"
}
