# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/app-emulation/open-vm-tools-kmod/open-vm-tools-kmod-2012.05.21.724730.ebuild,v 1.1 2012/06/02 14:45:23 vadimk Exp $

EAPI="4"

inherit bsdmk eutils linux-info linux-mod versionator

MY_PN="${PN/-kmod}"
MY_PV="$(replace_version_separator 3 '-')"
MY_P="${MY_PN}-${MY_PV}"

DESCRIPTION="Opensourced tools for VMware guests"
HOMEPAGE="http://open-vm-tools.sourceforge.net/"
SRC_URI="mirror://sourceforge/${MY_PN}/${MY_P}.tar.gz"

LICENSE="LGPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~amd64-fbsd"
IUSE="kernel_FreeBSD kernel_linux"
RESTRICT="strip"

RDEPEND=""

DEPEND="${RDEPEND}
	kernel_linux? ( virtual/linux-sources )
	kernel_FreeBSD? ( sys-freebsd/freebsd-sources )
	"

CONFIG_CHECK="
	~DRM_VMWGFX
	~VMWARE_BALLOON
	~VMWARE_PVSCSI
	~VMXNET3
	"

S="${WORKDIR}/${MY_P}"

pkg_setup() {
	if use kernel_linux
	then
		linux-mod_pkg_setup

		VMWARE_MOD_DIR="modules/linux"
		VMWARE_MODULE_LIST="vmblock vmci vmhgfs vmsync vmxnet vsock"

		MODULE_NAMES=""
		BUILD_TARGETS="auto-build HEADER_DIR=${KERNEL_DIR}/include BUILD_DIR=${KV_OUT_DIR} OVT_SOURCE_DIR=${S}"

		for mod in ${VMWARE_MODULE_LIST};
		do
			if [ "${mod}" == "vmxnet" ];
			then
				MODTARGET="net"
			else
				MODTARGET="openvmtools"
			fi
			MODULE_NAMES="${MODULE_NAMES} ${mod}(${MODTARGET}:${S}/${VMWARE_MOD_DIR}/${mod})"
		done
	fi
}

src_prepare() {
	sed -i.bak -e '/\smake\s/s/make/$(MAKE)/g' modules/linux/{vmblock,vmci,vmhgfs,vmsync,vmxnet,vsock}/Makefile\
		|| die "Sed failed."
	epatch "$FILESDIR/$P-fbsd8-support.patch"
	epatch "$FILESDIR/$P-fbsd-modules-makefile.patch"
	epatch "$FILESDIR/$P-fbsd-vmhgfs-makefile.patch"
	epatch "$FILESDIR/$P-fbsd-vmhgfs-debug.patch"
	epatch "$FILESDIR/$P-fbsd-vmhgfs-vnopscommon.patch"
	epatch "$FILESDIR/$P-fbsd-vmhgfs-state.patch"
	epatch "$FILESDIR/$P-fbsd-vmhgfs-kernel-stubs.patch"
	epatch "$FILESDIR/$P-fbsd-hgfscloseint-return.patch"
	epatch_user
}

src_configure() {
	if use kernel_FreeBSD
	then
		econf --without-root-privileges \
			--without-x \
			--disable-docs \
			--without-dnet \
			--without-icu 
	fi
}

src_compile() {
	if use kernel_linux
	then
		linux-mod_src_compile
	elif use kernel_FreeBSD
	then
		strip-flags
		export DEBUG_FLAGS="-g"
		cd "${S}/modules"
		mkmake SYSDIR="/usr/src/sys" LDFLAGS="$(raw-ldflags)" || die "mkmake $i failed"
	fi
}

src_install() {
	if use kernel_linux
	then
		linux-mod_src_install

		local udevrules="${T}/60-vmware.rules"
		cat > "${udevrules}" <<-EOF
			KERNEL=="vsock", GROUP="vmware", MODE=660
		EOF
		insinto /lib/udev/rules.d/
		doins "${udevrules}"
	elif use kernel_FreeBSD
	then
		dodir /boot/modules
		cp "${S}"/modules/freebsd/*.ko{,.symbols} "${ED}/boot/modules"
	fi
}

pkg_postinst()
{
	if use kernel_linux
	then
		linux-mod_pkg_postinst
	elif use kernel_FreeBSD
	then
		# Update linker.hints file
		/usr/sbin/kldxref "${EPREFIX}/boot/modules"
	fi

}

pkg_postrm() {
	if use kernel_linux
	then
		linux-mod_pkg_postrm
	elif use kernel_FreeBSD
	then
		# Update linker.hints file
		/usr/sbin/kldxref "${EPREFIX}/boot/modules"
	fi
}
