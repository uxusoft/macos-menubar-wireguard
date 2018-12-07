SHELL=/bin/bash

brew_bin=$(shell brew --prefix)/bin
convert=${brew_bin}/convert
xcpretty=${HOME}/.gem/ruby/2.3.0/bin/xcpretty

all: WireGuardStatusbar.dmg

# Location where xcodebuild puts .app when archiving
archive=${TMPDIR}/WireGuardStatusbar.xcarchive/
build_dest=${TMPDIR}/WireGuardStatusbar.xcarchive/Products/Applications/

# Create just the .app in the current working directory
WireGuardStatusbar.app: ${build_dest}/WireGuardStatusbar.app
	rm -rf "$@" && cp -r "${<}" "$@"

# Create distributable .dmg in current working directory
WireGuardStatusbar.dmg: ${TMPDIR}/WireGuardStatusbar/WireGuardStatusbar.app
	hdiutil create "$@" -srcfolder "${<D}" -ov
# Generate contents for distributable .dmg
${TMPDIR}/WireGuardStatusbar/WireGuardStatusbar.app: ${build_dest}/WireGuardStatusbar.app
	mkdir -p "${@D}/"
	ln -sf /Applications "${@D}/Applications"
	rm -rf "$@" && cp -r "$<" "$@"

# Generate archive build (this excludes debug symbols (dSYM) which are in a release build)
sources=$(shell find "WireGuardStatusbar" Shared HelperTool *.swift|sed 's/ /\\ /')
${build_dest}/WireGuardStatusbar.app: ${sources} | icons ${xcpretty}
	xcodebuild -scheme WireGuardStatusbar -archivePath "${archive}" archive | ${xcpretty}

# Generate icons from WireGuard banner
.PHONY: icons
icons: \
	WireGuardStatusbar/Assets.xcassets/connected.imageset/silhouette-18.png \
	WireGuardStatusbar/Assets.xcassets/connected.imageset/silhouette-36.png \
	WireGuardStatusbar/Assets.xcassets/disconnected.imageset/silhouette-18-dim.png \
	WireGuardStatusbar/Assets.xcassets/disconnected.imageset/silhouette-36-dim.png \
	WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-16.png \
	WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-32.png \
	WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-64.png \
	WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-128.png \
	WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-256.png \
	WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-512.png \
	WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-1024.png

WireGuardStatusbar/Assets.xcassets/disconnected.imageset/%: ${TMPDIR}/%
	cp "$<" "$@"

WireGuardStatusbar/Assets.xcassets/connected.imageset/%: ${TMPDIR}/%
	cp "$<" "$@"

WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/%: ${TMPDIR}/%
	cp "$<" "$@"

# Create a 'dimmed' version of the silhouette
%-dim.png: %.png | ${convert}
	${convert} $< -strip -channel A -evaluate Multiply 0.50 +channel $@

# Create multiple targets to resize .pngs to specific sizes required
define resize
%-${1}.png: %.png
	$${convert} $$< -strip -scale ${1}x${1} $$@
endef
$(foreach size,1024 512 256 128 64 36 32 18 16,$(eval $(call resize,${size})))

# Extract the logo part from the banner, color it black and white
${TMPDIR}/logo.png: ${TMPDIR}/wireguard.png | ${convert}
	${convert} $< -strip -crop 1251x1251+0+0 -colorspace gray +dither -colors 2 \
		-floodfill +600+200 white -floodfill +600+400 white -floodfill +350+900 white \
		-floodfill +400+200 black -floodfill +777+117 black\
		$@

# Extract the logo part from the banner, but keep the dragon transparent
${TMPDIR}/silhouette.png: ${TMPDIR}/wireguard.png | ${convert}
	${convert} $< -strip -colorspace gray +dither -colors 2 -crop 1251x1251+0+0 \
		-floodfill +400+200 black -floodfill +777+117 black\
		$@

# Convert SVG wireguard banner to png
${TMPDIR}/%.png: Misc/%.svg | ${convert}
	${convert} -strip -background transparent -density 400 $< $@

Misc/wireguard.svg:
	curl -s https://www.wireguard.com/img/wireguard.svg > $@

${convert}:
	brew install imagemagick

${xcpretty}:
	gem install --user xcpretty

.PHONY: clean
# cleanup build artifacts
clean:
	rm -rf \
		${build_dest}/WireGuardStatusbar.app \
		WireGuardStatusbar.{dmg,app} \
		DerivedData/

# cleanup most artifacts that could be generated by the Makefile
mrproper: clean
	rm -rf \
		${TMPDIR}/logo*.png \
		${TMPDIR}/wireguard.png WireGuardStatusbar/Assets.xcassets/connected.imageset/logo-*.png \
		WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-*.png