# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/llvm/llvm-3.1.ebuild,v 1.6 2012/06/14 16:22:07 voyageur Exp $

EAPI="4"

RESTRICT_PYTHON_ABIS="3.*"
SUPPORT_PYTHON_ABIS="1"
inherit eutils flag-o-matic multilib toolchain-funcs python

DESCRIPTION="Low Level Virtual Machine"
HOMEPAGE="http://llvm.org/"
SRC_URI="clang? ( http://llvm.org/releases/${PV}/clang-${PV}.src.tar.gz )
	clang? ( http://llvm.org/releases/${PV}/compiler-rt-${PV}.src.tar.gz )
	http://llvm.org/releases/${PV}/${P}.src.tar.gz"

LICENSE="UoI-NCSA"
SLOT="0"
KEYWORDS="~amd64 ~arm ~ppc ~x86 ~amd64-fbsd ~x86-fbsd ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos"
IUSE="debug kernel_FreeBSD +clang gold +libffi multitarget ocaml +static-analyzer test udis86 vim-syntax"

DEPEND="dev-lang/perl
	>=sys-devel/make-3.79
	>=sys-devel/flex-2.5.4
	>=sys-devel/bison-1.875d
	|| ( >=sys-devel/gcc-3.0 >=sys-devel/gcc-apple-4.2.1 )
	|| ( >=sys-devel/binutils-2.18 >=sys-devel/binutils-apple-3.2.3 )
	gold? ( >=sys-devel/binutils-2.22[cxx] )
	libffi? ( virtual/pkgconfig
		virtual/libffi )
	ocaml? ( dev-lang/ocaml )
	udis86? ( amd64? ( dev-libs/udis86[pic] )
		!amd64? ( dev-libs/udis86 ) )"
RDEPEND="dev-lang/perl
	libffi? ( virtual/libffi )
	vim-syntax? ( || ( app-editors/vim app-editors/gvim ) )"

S=${WORKDIR}/${P}.src

pkg_setup() {
	# Required for test and build
	#python_set_active_version 2
	python_pkg_setup

	# need to check if the active compiler is ok

	broken_gcc=" 3.2.2 3.2.3 3.3.2 4.1.1 "
	broken_gcc_x86=" 3.4.0 3.4.2 "
	broken_gcc_amd64=" 3.4.6 "

	gcc_vers=$(gcc-fullversion)

	if [[ ${broken_gcc} == *" ${version} "* ]] ; then
		elog "Your version of gcc is known to miscompile llvm."
		elog "Check http://www.llvm.org/docs/GettingStarted.html for"
		elog "possible solutions."
		die "Your currently active version of gcc is known to miscompile llvm"
	fi

	if [[ ${CHOST} == i*86-* && ${broken_gcc_x86} == *" ${version} "* ]] ; then
		elog "Your version of gcc is known to miscompile llvm on x86"
		elog "architectures.  Check"
		elog "http://www.llvm.org/docs/GettingStarted.html for possible"
		elog "solutions."
		die "Your currently active version of gcc is known to miscompile llvm"
	fi

	if [[ ${CHOST} == x86_64-* && ${broken_gcc_amd64} == *" ${version} "* ]];
	then
		 elog "Your version of gcc is known to miscompile llvm in amd64"
		 elog "architectures.  Check"
		 elog "http://www.llvm.org/docs/GettingStarted.html for possible"
		 elog "solutions."
		die "Your currently active version of gcc is known to miscompile llvm"
	 fi
}

src_prepare() {
	mv "${WORKDIR}"/clang-${PV}.src "${S}"/tools/clang \
		|| die "clang source directory move failed"
	mv "${WORKDIR}"/compiler-rt-${PV}.src "${S}"/projects/compiler-rt \
		|| die "compiler-rt source directory move failed"

	# Specify python version
	python_convert_shebangs -r 2 test/Scripts
	if use clang; then
		python_convert_shebangs 2 tools/clang/tools/scan-view/scan-view
		python_convert_shebangs 2 projects/compiler-rt/lib/asan/scripts/asan_symbolize.py
	fi

	# unfortunately ./configure won't listen to --mandir and the-like, so take
	# care of this.
	einfo "Fixing install dirs"
	sed -e 's,^PROJ_docsdir.*,PROJ_docsdir := $(PROJ_prefix)/share/doc/'${PF}, \
		-e 's,^PROJ_etcdir.*,PROJ_etcdir := '"${EPREFIX}"'/etc/llvm,' \
		-e 's,^PROJ_libdir.*,PROJ_libdir := $(PROJ_prefix)/'$(get_libdir)/${PN}, \
		-i Makefile.config.in || die "Makefile.config sed failed"
	sed -e "/ActiveLibDir = ActivePrefix/s/lib/$(get_libdir)\/${PN}/" \
		-i tools/llvm-config/llvm-config.cpp || die "llvm-config sed failed"

	einfo "Fixing rpath and CFLAGS"
	sed -e 's,\$(RPATH) -Wl\,\$(\(ToolDir\|LibDir\)),$(RPATH) -Wl\,'"${EPREFIX}"/usr/$(get_libdir)/${PN}, \
		-e '/OmitFramePointer/s/-fomit-frame-pointer//' \
		-i Makefile.rules || die "rpath sed failed"
	if use gold; then
		sed -e 's,\$(SharedLibDir),'"${EPREFIX}"/usr/$(get_libdir)/${PN}, \
			-i tools/gold/Makefile || die "gold rpath sed failed"
	fi

	epatch "${FILESDIR}"/${PN}-2.6-commandguide-nops.patch
	epatch "${FILESDIR}"/${PN}-2.9-nodoctargz.patch
	epatch "${FILESDIR}"/${PN}-3.0-PPC_macro.patch
	epatch "${FILESDIR}"/${P}-ivybridge_support.patch

	if use clang; then
		# multilib-strict
		sed -e "/PROJ_headers/s#lib/clang#$(get_libdir)/clang#" \
			-i tools/clang/lib/Headers/Makefile \
			|| die "clang Makefile failed"
		sed -e "/PROJ_resources/s#lib/clang#$(get_libdir)/clang#" \
			-i tools/clang/runtime/compiler-rt/Makefile \
			|| die "compiler-rt Makefile failed"
		# fix the static analyzer for in-tree install
		sed -e 's/import ScanView/from clang \0/'  \
			-i tools/clang/tools/scan-view/scan-view \
			|| die "scan-view sed failed"
		sed -e "/scanview.css\|sorttable.js/s#\$RealBin#${EPREFIX}/usr/share/${PN}#" \
			-i tools/clang/tools/scan-build/scan-build \
			|| die "scan-build sed failed"
		# Set correct path for gold plugin
		sed -e "/LLVMgold.so/s#lib/#$(get_libdir)/llvm/#" \
			-i  tools/clang/lib/Driver/Tools.cpp \
			|| die "gold plugin path sed failed"

		# Same as llvm doc patches
		epatch "${FILESDIR}"/clang-2.7-fixdoc.patch

		# Automatically select active system GCC's libraries, bugs #406163 and #417913
		epatch "${FILESDIR}"/clang-${PV}-gentoo-runtime-gcc-detection-v3.patch

		# Fix search paths on FreeBSD, bug #409269
		epatch "${FILESDIR}"/clang-${PV}-gentoo-freebsd-fix-lib-path.patch

		# Fix regression caused by removal of USE=system-cxx-headers, bug #417541
		epatch "${FILESDIR}"/clang-${PV}-gentoo-freebsd-fix-cxx-paths-v2.patch

		# Increase recursion limit, bug #417545, upstream r155737
		epatch "${FILESDIR}"/clang-${PV}-increase-parser-recursion-limit.patch
	fi

	# User patches
	epatch_user
}

src_configure() {
	local CONF_FLAGS="--enable-shared
		--with-optimize-option=
		$(use_enable !debug optimized)
		$(use_enable debug assertions)
		$(use_enable debug expensive-checks)"

	# Setup the search path to include the Prefix includes
	if use prefix ; then
		CONF_FLAGS="${CONF_FLAGS} \
			--with-c-include-dirs=${EPREFIX}/usr/include:/usr/include"
	fi

	if use multitarget; then
		CONF_FLAGS="${CONF_FLAGS} --enable-targets=all"
	else
		CONF_FLAGS="${CONF_FLAGS} --enable-targets=host-only"
	fi

	if use amd64; then
		CONF_FLAGS="${CONF_FLAGS} --enable-pic"
	fi

	if use gold; then
		CONF_FLAGS="${CONF_FLAGS} --with-binutils-include=${EPREFIX}/usr/include/"
	fi
	if use ocaml; then
		CONF_FLAGS="${CONF_FLAGS} --enable-bindings=ocaml"
	else
		CONF_FLAGS="${CONF_FLAGS} --enable-bindings=none"
	fi

	if use udis86; then
		CONF_FLAGS="${CONF_FLAGS} --with-udis86"
	fi

	if use libffi; then
		append-cppflags "$(pkg-config --cflags libffi)"
	fi
	CONF_FLAGS="${CONF_FLAGS} $(use_enable libffi)"
	econf ${CONF_FLAGS}
}

src_compile() {
	emake VERBOSE=1 KEEP_SYMBOLS=1 REQUIRES_RTTI=1
}

src_test() {
	if use clang; then
		cd "${S}"/test || die "cd failed"
		emake site.exp

		cd "${S}"/tools/clang || die "cd clang failed"

		echo ">>> Test phase [test]: ${CATEGORY}/${PF}"

		testing() {
			if ! emake -j1 VERBOSE=1 test; then
				has test $FEATURES && die "Make test failed. See above for details."
				has test $FEATURES || eerror "Make test failed. See above for details."
			fi
		}
		python_execute_function testing
	fi
}

src_install() {
	emake KEEP_SYMBOLS=1 DESTDIR="${D}"
	if use clang; then
		#cd "${S}"/projects/compiler-rt || die "cd compiler-rt failed"
		#emake KEEP_SYMBOLS=1 DESTDIR="${D}" install
		cd "${S}"/tools/clang || die "cd clang failed"
		emake KEEP_SYMBOLS=1 DESTDIR="${D}" install
	fi

	if use vim-syntax; then
		insinto /usr/share/vim/vimfiles/syntax
		doins utils/vim/*.vim
	fi

	if use clang && use static-analyzer ; then
		dobin tools/scan-build/ccc-analyzer
		dosym ccc-analyzer /usr/bin/c++-analyzer
		dobin tools/scan-build/scan-build

		insinto /usr/share/${PN}
		doins tools/scan-build/scanview.css
		doins tools/scan-build/sorttable.js

		cd tools/scan-view || die "cd scan-view failed"
		dobin scan-view
		install-scan-view() {
			insinto "$(python_get_sitedir)"/clang
			doins Reporter.py Resources ScanView.py startfile.py
			touch "${ED}"/"$(python_get_sitedir)"/clang/__init__.py
		}
		python_execute_function install-scan-view
	fi

	# Fix install_names on Darwin.  The build system is too complicated
	# to just fix this, so we correct it post-install
	local lib= f= odylib=
	if [[ ${CHOST} == *-darwin* ]] ; then
		for lib in lib{EnhancedDisassembly,LLVM-${PV},LTO,profile_rt}.dylib {BugpointPasses,LLVMHello}.dylib ; do
			# libEnhancedDisassembly is Darwin10 only, so non-fatal
			[[ -f ${ED}/usr/lib/${PN}/${lib} ]] || continue
			ebegin "fixing install_name of $lib"
			install_name_tool \
				-id "${EPREFIX}"/usr/lib/${PN}/${lib} \
				"${ED}"/usr/lib/${PN}/${lib}
			eend $?
		done
		for f in "${ED}"/usr/bin/* "${ED}"/usr/lib/${PN}/libLTO.dylib ; do
			odylib=$(scanmacho -BF'%n#f' "${f}" | tr ',' '\n' | grep libLLVM-${PV}.dylib)
			ebegin "fixing install_name reference to ${odylib} of ${f##*/}"
			install_name_tool \
				-change "${odylib}" \
					"${EPREFIX}"/usr/lib/${PN}/libLLVM-${PV}.dylib \
				"${f}"
			eend $?
		done
	fi

	# Remove unnecessary headers on FreeBSD, bug #417171
	use kernel_FreeBSD && rm "${ED}"usr/$(get_libdir)/clang/${PV}/include/{arm_neon,std,float,iso,limits,tgmath,varargs}*.h
}

pkg_postinst() {
	use clang && python_mod_optimize clang
}

pkg_postrm() {
	use clang && python_mod_cleanup clang
}
