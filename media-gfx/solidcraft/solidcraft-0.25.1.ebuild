# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
	accesskit@0.24.1
	accesskit_atspi_common@0.18.1
	accesskit_consumer@0.38.0
	accesskit_consumer@0.35.0
	accesskit_consumer@0.36.0
	accesskit_macos@0.26.3
	accesskit_unix@0.21.1
	accesskit_windows@0.32.1
	accesskit_winit@0.32.2
	adler2@2.0.1
	aes@0.8.4
	ahash@0.8.12
	allocator-api2@0.2.21
	android-activity@0.6.1
	android-properties@0.2.2
	android_system_properties@0.1.6
	approx@0.4.0
	arboard@3.6.1
	array-macro@2.1.8
	arrayref@0.3.9
	arrayvec@0.7.8
	as-raw-xcb-connection@1.0.1
	ash@0.38.0+1.3.281
	async-broadcast@0.7.2
	async-channel@2.5.0
	async-executor@1.14.0
	async-fs@2.2.0
	async-io@2.6.0
	async-lock@3.4.2
	async-process@2.5.0
	async-recursion@1.2.0
	async-signal@0.2.14
	async-task@4.7.1
	async-trait@0.1.92
	atomic-waker@1.1.2
	atspi@0.29.0
	atspi-common@0.13.0
	atspi-proxies@0.13.0
	autocfg@1.5.1
	base64@0.23.1
	bit-set@0.10.0
	bit-vec@0.9.1
	bitflags@2.13.2
	bitflags@1.3.2
	block-buffer@0.12.1
	block-buffer@0.10.4
	block-padding@0.3.3
	block2@0.6.2
	block2@0.5.1
	blocking@1.7.0
	branches@0.3.0
	bumpalo@3.20.3
	bytemuck@1.25.2
	bytemuck_derive@1.12.1
	byteorder@1.5.0
	byteorder-lite@0.1.0
	bytes@1.12.1
	cadmpeg-codec-freecad@0.6.3
	cadmpeg-codec-rhino@0.6.3
	cadmpeg-codec-step@0.6.3
	cadmpeg-container@0.6.3
	cadmpeg-core@0.6.3
	cadmpeg-ir@0.6.3
	cadmpeg-registry@0.6.3
	calloop@0.14.5
	calloop@0.13.0
	calloop-wayland-source@0.4.1
	calloop-wayland-source@0.3.0
	cbc@0.1.2
	cc@1.6.0
	cfg-if@1.0.5
	cfg_aliases@0.2.2
	cgl@0.3.2
	cgmath@0.18.0
	chacha20@0.10.2
	chardetng@0.1.17
	chrono@0.4.45
	cipher@0.4.4
	clipboard-win@5.4.1
	codespan-reporting@0.13.1
	color@0.3.3
	color_quant@1.1.0
	combine@4.6.8
	concurrent-queue@2.5.0
	const-oid@0.10.2
	convert_case@0.4.0
	core-foundation@0.10.1
	core-foundation@0.9.4
	core-foundation-sys@0.8.7
	core-graphics@0.23.2
	core-graphics-types@0.1.3
	core_detect@1.0.0
	cpufeatures@0.3.1
	cpufeatures@0.2.17
	crc32fast@1.5.2
	crossbeam-channel@0.5.17
	crossbeam-deque@0.8.8
	crossbeam-epoch@0.9.21
	crossbeam-utils@0.8.23
	crunchy@0.2.4
	crypto-common@0.2.2
	crypto-common@0.1.7
	cursor-icon@1.2.0
	dbus@0.9.12
	dbus-secret-service@4.1.0
	derive_more@0.99.20
	digest@0.11.3
	digest@0.10.7
	dispatch@0.2.0
	dispatch2@0.3.1
	displaydoc@0.2.7
	dlib@0.5.3
	document-features@0.2.12
	downcast-rs@1.2.1
	dpi@0.1.2
	dyn-clone@1.0.20
	ecolor@0.36.2
	eframe@0.36.2
	egui@0.36.2
	egui-winit@0.36.2
	egui_glow@0.36.2
	either@1.19.0
	emath@0.36.2
	embed-resource@3.0.12
	encoding_rs@0.8.42
	endi@1.1.1
	enumflags2@0.7.12
	enumflags2_derive@0.7.12
	enumn@0.1.14
	epaint@0.36.2
	epaint_default_fonts@0.36.2
	equivalent@1.0.2
	errno@0.3.14
	error-code@3.4.0
	euclid@0.22.14
	event-listener@5.4.2
	event-listener-strategy@0.5.4
	fastrand@2.5.0
	fax@0.2.7
	fdeflate@0.3.7
	fearless_simd@0.4.1
	find-msvc-tools@0.1.14
	flate2@1.1.10
	foldhash@0.2.0
	font-types@0.12.6
	foreign-types@0.5.0
	foreign-types-macros@0.2.4
	foreign-types-shared@0.3.1
	form_urlencoded@1.2.2
	futures-core@0.3.34
	futures-io@0.3.34
	futures-lite@2.6.1
	futures-macro@0.3.34
	futures-sink@0.3.34
	futures-task@0.3.34
	futures-util@0.3.34
	generic-array@0.14.7
	gethostname@1.1.0
	getrandom@0.4.3
	getrandom@0.2.17
	getrandom@0.3.4
	gif@0.14.2
	gl_generator@0.14.0
	glifo@0.2.0
	glow@0.17.0
	gltf@1.4.1
	gltf-derive@1.4.1
	gltf-json@1.4.1
	glutin@0.32.3
	glutin-winit@0.5.0
	glutin_egl_sys@0.7.1
	glutin_glx_sys@0.6.1
	glutin_wgl_sys@0.6.1
	gpu-allocator@0.28.0
	guillotiere@0.7.0
	half@2.7.1
	harfrust@0.12.0
	hashbrown@0.17.1
	hashbrown@0.16.1
	hermit-abi@0.5.3
	hex@0.4.3
	hidapi@2.6.7
	hkdf@0.12.4
	hmac@0.12.1
	http@1.5.0
	httparse@1.10.1
	hybrid-array@0.4.15
	iana-time-zone@0.1.65
	iana-time-zone-haiku@0.1.2
	icu_collections@2.3.0
	icu_locale_core@2.3.0
	icu_normalizer@2.3.0
	icu_normalizer_data@2.3.0
	icu_properties@2.3.0
	icu_properties_data@2.3.0
	icu_provider@2.3.1
	idna@1.1.0
	idna_adapter@1.2.2
	image@0.25.10
	image-webp@0.2.4
	indexmap@2.14.2
	inflections@1.1.1
	inout@0.1.4
	itertools@0.15.0
	itertools@0.13.0
	itoa@1.0.18
	jni@0.22.4
	jni-macros@0.22.4
	jni-sys@0.4.1
	jni-sys@0.3.1
	jni-sys-macros@0.4.1
	jobserver@0.1.35
	js-sys@0.3.106
	katexit@0.1.5
	keyboard-types@0.8.3
	keyring@3.6.3
	khronos-egl@6.0.0
	khronos_api@3.1.0
	kurbo@0.13.1
	lazy_static@1.5.1
	libc@0.2.190
	libdbus-sys@0.2.7
	libloading@0.8.9
	libm@0.2.16
	libredox@0.1.25
	linebender_resource_handle@0.1.1
	linux-raw-sys@0.12.1
	linux-raw-sys@0.4.15
	litemap@0.8.3
	litrs@1.0.0
	lock_api@0.4.14
	log@0.4.34
	memchr@2.8.3
	memmap2@0.9.11
	memoffset@0.9.1
	minisign-verify@0.3.0
	miniz_oxide@0.9.1
	miniz_oxide@0.8.9
	moxcms@0.8.1
	muda@0.21.2
	multiversion_no_op@1.0.0
	naga@30.0.1
	naga-types@30.0.1
	ndk@0.9.0
	ndk-context@0.1.1
	ndk-sys@0.6.0+11769913
	nix@0.31.3
	nix@0.29.0
	nohash-hasher@0.2.0
	num@0.4.3
	num-bigint@0.4.8
	num-complex@0.4.6
	num-integer@0.1.47
	num-iter@0.1.46
	num-rational@0.4.2
	num-traits@0.2.19
	num_enum@0.7.6
	num_enum_derive@0.7.6
	objc-sys@0.3.5
	objc2@0.6.5
	objc2@0.5.3
	objc2-app-kit@0.3.2
	objc2-app-kit@0.2.2
	objc2-cloud-kit@0.2.2
	objc2-contacts@0.2.2
	objc2-core-data@0.2.2
	objc2-core-foundation@0.3.2
	objc2-core-graphics@0.3.2
	objc2-core-image@0.2.2
	objc2-core-location@0.2.2
	objc2-encode@4.1.0
	objc2-foundation@0.3.2
	objc2-foundation@0.2.2
	objc2-io-surface@0.3.2
	objc2-link-presentation@0.2.2
	objc2-metal@0.3.2
	objc2-metal@0.2.2
	objc2-quartz-core@0.3.2
	objc2-quartz-core@0.2.2
	objc2-symbols@0.2.2
	objc2-ui-kit@0.3.2
	objc2-ui-kit@0.2.2
	objc2-uniform-type-identifiers@0.2.2
	objc2-user-notifications@0.2.2
	once_cell@1.21.4
	openssl-probe@0.2.1
	orbclient@0.3.55
	ordered-float@5.5.0
	ordered-float@2.10.1
	ordered-stream@0.2.0
	parking@2.2.1
	parking_lot@0.12.5
	parking_lot_core@0.9.12
	peniko@0.6.1
	percent-encoding@2.3.2
	phf@0.13.1
	phf_generator@0.13.1
	phf_macros@0.13.1
	phf_shared@0.13.1
	pin-project@1.1.13
	pin-project-internal@1.1.13
	pin-project-lite@0.2.17
	piper@0.2.5
	pkg-config@0.3.34
	plain@0.2.3
	png@0.18.1
	polling@3.11.0
	pollster@1.0.1
	pollster@0.4.0
	polycool@0.4.0
	portable-atomic@1.15.0
	portable-atomic-util@0.2.8
	potential_utf@0.1.6
	ppv-lite86@0.2.21
	presser@0.3.1
	proc-macro-crate@3.5.0
	proc-macro-error@1.0.4
	proc-macro-error-attr@1.0.4
	proc-macro2@1.0.107
	profiling@1.0.18
	proptest@1.12.0
	pxfm@0.1.30
	quick-error@2.0.1
	quick-xml@0.41.0
	quote@1.0.47
	r-efi@6.0.0
	r-efi@5.3.0
	rand@0.10.3
	rand@0.8.8
	rand_chacha@0.3.1
	rand_core@0.10.1
	rand_core@0.6.4
	rand_xorshift@0.5.0
	range-alloc@0.1.5
	raw-window-handle@0.6.2
	raw-window-metal@1.1.0
	rayon@1.12.0
	rayon-core@1.13.0
	rclite@0.2.8
	read-fonts@0.41.0
	redox_syscall@0.9.4
	redox_syscall@0.4.1
	redox_syscall@0.5.18
	ref-cast@1.0.27
	ref-cast-impl@1.0.27
	regex-syntax@0.8.11
	renderdoc-sys@1.1.0
	rfd@0.17.2
	ring@0.17.14
	robust@1.2.0
	ron@0.12.2
	roxmltree@0.21.1
	rustc-hash@2.1.3
	rustc-hash@1.1.0
	rustc_version@0.4.1
	rustix@1.1.5
	rustix@0.38.44
	rustls@0.23.46
	rustls-native-certs@0.8.5
	rustls-pki-types@1.15.1
	rustls-platform-verifier@0.7.1
	rustls-platform-verifier-android@0.2.0
	rustls-webpki@0.103.15
	rustversion@1.0.23
	ruzstd@0.9.1
	same-file@1.0.6
	schannel@0.1.29
	schemars@1.2.3
	schemars_derive@1.2.3
	scoped-tls@1.0.1
	scopeguard@1.2.0
	secret-service@4.0.0
	security-framework@3.7.0
	security-framework@2.11.1
	security-framework-sys@2.17.0
	self_cell@1.3.0
	semver@1.0.28
	serde@1.0.229
	serde-value@0.7.0
	serde_core@1.0.229
	serde_derive@1.0.229
	serde_derive_internals@0.30.0
	serde_json@1.0.151
	serde_path_to_error@0.1.20
	serde_repr@0.1.21
	serde_spanned@1.1.2
	sha1@0.11.0
	sha1@0.10.7
	sha2@0.11.1
	sha2@0.10.9
	shlex@2.0.1
	signal-hook-registry@1.4.8
	simd-adler32@0.3.10
	simd_cesu8@1.2.0
	simdutf8@0.1.5
	siphasher@1.0.4
	skrifa@0.44.0
	slab@0.4.12
	slotmap@1.1.1
	smallvec@1.16.2
	smithay-client-toolkit@0.20.0
	smithay-client-toolkit@0.19.2
	smithay-clipboard@0.7.3
	smol_str@0.2.2
	spade@2.15.1
	spirv@0.4.0+sdk-1.4.341.0
	stable_deref_trait@1.2.1
	static_assertions@1.1.0
	strict-num@0.1.1
	subtle@2.6.1
	syn@3.0.6
	syn@1.0.109
	syn@2.0.119
	synstructure@0.13.2
	tempfile@3.27.0
	termcolor@1.4.1
	thiserror@2.0.21
	thiserror@1.0.69
	thiserror-impl@2.0.21
	thiserror-impl@1.0.69
	tiff@0.11.3
	tiny-skia@0.12.0
	tiny-skia-path@0.12.0
	tinystr@0.8.4
	tokio@1.53.2
	toml@1.1.8+spec-1.1.0
	toml_datetime@1.1.2+spec-1.1.0
	toml_edit@0.25.15+spec-1.1.0
	toml_parser@1.1.5+spec-1.1.0
	toml_writer@1.1.3+spec-1.1.0
	tracing@0.1.44
	tracing-attributes@0.1.31
	tracing-core@0.1.36
	truck-base@0.5.0
	truck-derivers@0.1.0
	truck-geotrait@0.4.0
	truck-modeling@0.6.0
	truck-polymesh@0.6.0
	truck-topology@0.6.0
	ttf-parser@0.25.1
	twox-hash@2.1.5
	type-map@0.5.1
	typed-path@0.12.3
	typeid@1.0.3
	typenum@1.20.1
	uds_windows@1.2.1
	unarray@0.1.4
	unicode-bidi@0.3.18
	unicode-general-category@1.1.0
	unicode-ident@1.0.26
	unicode-segmentation@1.13.3
	unicode-width@0.2.2
	untrusted@0.9.0
	ureq@3.4.2
	ureq-proto@0.6.4
	url@2.5.8
	utf8-zero@0.8.1
	utf8_iter@1.0.4
	uuid@1.27.0
	vello_common@0.1.0
	vello_cpu@0.1.0
	version_check@0.9.5
	vswhom@0.1.0
	vswhom-sys@0.1.3
	walkdir@2.5.0
	wasi@0.11.1+wasi-snapshot-preview1
	wasip2@1.0.4+wasi-0.2.12
	wasm-bindgen@0.2.129
	wasm-bindgen-futures@0.4.79
	wasm-bindgen-macro@0.2.129
	wasm-bindgen-macro-support@0.2.129
	wasm-bindgen-shared@0.2.129
	wayland-backend@0.3.17
	wayland-client@0.31.15
	wayland-csd-frame@0.3.0
	wayland-cursor@0.31.14
	wayland-protocols@0.32.13
	wayland-protocols-experimental@20250721.0.1
	wayland-protocols-misc@0.3.12
	wayland-protocols-plasma@0.3.12
	wayland-protocols-wlr@0.3.12
	wayland-scanner@0.31.11
	wayland-sys@0.31.11
	web-sys@0.3.106
	web-time@1.1.0
	webbrowser@1.2.4
	webpki-root-certs@1.0.9
	weezl@0.1.12
	wgpu@30.0.1
	wgpu-core@30.0.1
	wgpu-core-deps-apple@30.0.1
	wgpu-core-deps-emscripten@30.0.1
	wgpu-core-deps-wasm@30.0.1
	wgpu-core-deps-windows-linux-android@30.0.1
	wgpu-hal@30.0.1
	wgpu-naga-bridge@30.0.1
	wgpu-types@30.0.1
	winapi-util@0.1.11
	windows@0.62.2
	windows-collections@0.3.2
	windows-core@0.62.2
	windows-future@0.3.2
	windows-implement@0.60.2
	windows-interface@0.59.3
	windows-link@0.2.1
	windows-numerics@0.3.1
	windows-result@0.4.1
	windows-strings@0.5.1
	windows-sys@0.61.2
	windows-sys@0.52.0
	windows-sys@0.59.0
	windows-sys@0.60.2
	windows-targets@0.53.5
	windows-targets@0.52.6
	windows-threading@0.2.1
	windows_aarch64_gnullvm@0.53.1
	windows_aarch64_gnullvm@0.52.6
	windows_aarch64_msvc@0.53.1
	windows_aarch64_msvc@0.52.6
	windows_i686_gnu@0.53.1
	windows_i686_gnu@0.52.6
	windows_i686_gnullvm@0.53.1
	windows_i686_gnullvm@0.52.6
	windows_i686_msvc@0.53.1
	windows_i686_msvc@0.52.6
	windows_x86_64_gnu@0.53.1
	windows_x86_64_gnu@0.52.6
	windows_x86_64_gnullvm@0.53.1
	windows_x86_64_gnullvm@0.52.6
	windows_x86_64_msvc@0.53.1
	windows_x86_64_msvc@0.52.6
	winit@0.30.13
	winnow@1.0.4
	winreg@0.56.0
	wit-bindgen@0.57.1
	writeable@0.6.4
	x11-dl@2.21.0
	x11rb@0.13.2
	x11rb-protocol@0.13.2
	xcursor@0.3.11
	xdg-home@1.3.0
	xkbcommon-dl@0.4.2
	xkeysym@0.2.1
	xml-rs@0.8.29
	yoke@0.8.3
	yoke-derive@0.8.2
	zbus@5.19.0
	zbus@4.4.0
	zbus-lockstep@0.5.2
	zbus-lockstep-macros@0.5.2
	zbus_macros@5.19.0
	zbus_macros@4.4.0
	zbus_names@4.3.4
	zbus_names@3.0.0
	zbus_xml@5.2.1
	zcheapstr@1.1.0
	zerocopy@0.8.61
	zerocopy-derive@0.8.61
	zerofrom@0.1.8
	zerofrom-derive@0.1.7
	zeroize@1.9.1
	zeroize_derive@1.5.0
	zerotrie@0.2.5
	zerovec@0.11.8
	zerovec-derive@0.11.6
	zip@9.0.4
	zlib-rs@0.6.8
	zmij@1.0.23
	zopfli@0.8.3
	zune-core@0.5.3
	zune-jpeg@0.5.15
	zvariant@5.15.0
	zvariant@4.2.0
	zvariant_derive@5.15.0
	zvariant_derive@4.2.0
	zvariant_utils@4.2.0
	zvariant_utils@2.1.0
"

# The workspace's rust-version (Cargo.toml [workspace.package], edition 2024,
# resolver 3). rust.eclass turns this into the BDEPEND on dev-lang/rust OR
# dev-lang/rust-bin; see the note at BDEPEND.
RUST_MIN_VER="1.95"

inherit cargo

DESCRIPTION="Open-source parametric 3D CAD in pure Rust"
HOMEPAGE="https://github.com/tangency-labs/solidcraft"
SRC_URI="
    ${CARGO_CRATE_URIS}
    https://github.com/tangency-labs/solidcraft/archive/refs/tags/v${PV}.tar.gz -> solidcraft-${PV}.tar.gz
"


LICENSE="MIT Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

# Tests replay the geometry kernel through a GPU path tracer and a wasm target
# (cargo xtask ci); neither belongs in a build phase.
RESTRICT="test"

# The binaries link only glibc and libgcc_s directly. Windowing (X11/Wayland,
# xkbcommon) and the GPU (Vulkan, EGL/GL) are dlopen'd at runtime, so they are not
# ELF NEEDED entries and portage's scanner cannot find them: list them by hand.
# The list is upstream's own — packaging/linux/nfpm.yaml (deb Depends) plus the
# runtimeLibs set in flake.nix (which adds the RandR/Render/Ext pair that nfpm
# leaves to transitive x11 dependencies).
CDEPEND="
	dev-libs/wayland
	x11-libs/libxkbcommon[X]
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcursor
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXext
	sys-apps/dbus
	|| ( media-libs/vulkan-loader media-libs/libglvnd[X] )
"
# The block on the prebuilt package: both install the same paths, so they are
# alternatives, not co-installables (see media-gfx/solidcraft-bin).
RDEPEND="
	!media-gfx/solidcraft-bin:0
	${CDEPEND}
"

# libdbus-sys (keyring -> dbus-secret-service -> dbus -> libdbus-sys) needs dbus.pc.
# virtual/pkgconfig: the -sys crates in the tree locate their libraries with it.
# sys-apps/dbus: libdbus-sys links real libdbus, so the library must be present.
#
# The rust dependency is NOT written here on purpose: cargo.eclass inherits
# rust.eclass, which composes RUST_DEPEND from RUST_MIN_VER (set above, before
# inherit) and appends it to BDEPEND itself. That generated dep is
# || ( dev-lang/rust:* dev-lang/rust-bin:* ) — a hand-written
# ">=dev-lang/rust-1.95" would exclude the binary toolchain and force a
# multi-hour source build of rust on a box that already has rust-bin.
BDEPEND="
	virtual/pkgconfig
	sys-apps/dbus
"

src_configure() {
	# Only the desktop app and the CLI. apps/solidcraft-web is a wasm target built
	# by trunk, not by a host `cargo build`, so it must stay out of the workspace
	# selection. The CLI package carries both solidcraft-cli and the alias binary.
	cargo_src_configure -p solidcraft -p solidcraft-cli
}

src_install() {
	local app_id=io.tangencylabs.solidcraft

	# Three binaries: the desktop app, the headless CLI / MCP server, and
	# solvecraft-cli — the compatibility alias for the CLI's pre-rename name
	# (apps/solidcraft-cli/src/alias.rs), shipped by upstream in every package for
	# at least one release (docs/compatibility.md).
	exeinto /opt/solidcraft/bin
	doexe target/release/solidcraft
	doexe target/release/solidcraft-cli
	doexe target/release/solvecraft-cli

	# The prefix is /opt/solidcraft; the names on PATH are symlinks, which is what
	# the desktop file's Exec=/TryExec=solidcraft resolves against. The link target
	# must be ABSOLUTE: /usr/bin/x -> ../solidcraft/bin/x would resolve to
	# /usr/solidcraft/bin/x, not to the /opt prefix.
	dosym /opt/solidcraft/bin/solidcraft /usr/bin/solidcraft
	dosym /opt/solidcraft/bin/solidcraft-cli /usr/bin/solidcraft-cli
	dosym /opt/solidcraft/bin/solvecraft-cli /usr/bin/solvecraft-cli

	# Nothing from assets/ is installed: the fonts, the UI icons and the locale
	# tables are compiled into the binary (include_bytes!/include_str! in
	# crates/ui-egui/src/fonts.rs and icons.rs). CJK and Arabic fallbacks are found
	# in the system font dirs, or through SOLIDCRAFT_FONT_DIRS / CRAFT_FONTS_DIR.
	# Docs: the same five files packaging/env.sh:copy_docs puts in /usr/share/doc.
	dodoc README.md LICENSE-MIT LICENSE-APACHE NOTICE THIRD-PARTY-LICENSES.txt

	# domenu() is a desktop.eclass helper, not a portage builtin; this ebuild
	# installs one already-correct file, so plain doins is the honest tool.
	insinto /usr/share/applications
	doins "${S}/assets/platforms/linux/${app_id}.desktop"

	# Upstream renames the xml on install (package.sh: mime.xml -> ${APP_ID}.xml).
	insinto /usr/share/mime/packages
	newins "${S}/assets/platforms/linux/${app_id}.mime.xml" "${app_id}.xml"

	# AppStream: the template carries @VERSION@ and @DATE@ placeholders
	# (package.sh substitutes them the same way).
	sed -e "s/@VERSION@/${PV}/g" \
		-e "s/@DATE@/$(date -u +%Y-%m-%d)/g" \
		"${S}/assets/platforms/linux/${app_id}.metainfo.xml.in" \
		> "${T}/${app_id}.metainfo.xml" || die "sed metainfo failed"
	insinto /usr/share/metainfo
	newins "${T}/${app_id}.metainfo.xml" "${app_id}.metainfo.xml"

	# The eight committed hicolor sizes (make_icons copies exactly these exports).
	insinto /usr/share/icons
	doins -r "${S}/assets/icons/app/linux/exports/hicolor"
}

# Refresh the three XDG caches (desktop / mime / icons). Upstream runs ONE
# script for BOTH install and remove (packaging/linux/postinst.sh, wired as
# postinstall AND postremove in nfpm.yaml), so both pkg phases here call the
# same helper. Inline rather than inheriting xdg-utils.eclass: this ebuild
# inherits cargo, and the refresh is three guarded one-liners.
_solidcraft_cache_update() {
	if type -P update-desktop-database >/dev/null; then
		update-desktop-database -q /usr/share/applications
	fi
	if type -P update-mime-database >/dev/null; then
		update-mime-database /usr/share/mime
	fi
	if type -P gtk-update-icon-cache >/dev/null; then
		gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor
	fi
}

pkg_postinst() {
	# Same three caches packaging/linux/postinst.sh refreshes.
	_solidcraft_cache_update

	elog "SolidCraft stores agent-chat API keys in the system keychain. On Linux that"
	elog "is the Secret Service over D-Bus, so a provider must be running"
	elog "(gnome-base/gnome-keyring or kde-frameworks/kwallet). Without one the"
	elog "feature stays unavailable; the app still starts."
	elog
	elog "CJK and Arabic UI text falls back to fonts found in the system font"
	elog "directories. Point SOLIDCRAFT_FONT_DIRS (colon separated) or CRAFT_FONTS_DIR"
	elog "at a font pack to override, e.g. media-fonts/noto-cjk for Japanese/Chinese."
}

pkg_postrm() {
	_solidcraft_cache_update
}
