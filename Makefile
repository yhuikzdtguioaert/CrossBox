# CrossBox build entry point. Local .scripts tools are optional conveniences.
OPENWRT := $(CURDIR)/third_party/openwrt
JOBS ?= 4

.PHONY: help feeds configure firmware menuconfig
.DEFAULT_GOAL := help

help:
	@printf '%s\n' 'make feeds       Fetch and install the pinned OpenWrt feeds' 'make configure   Register the CrossBox layer and configure AX55 v1' 'make firmware    Build CrossBox (override parallelism with JOBS=4)' 'make menuconfig  Open advanced OpenWrt configuration'

feeds:
	cp configs/feeds.conf "$(OPENWRT)/feeds.conf"
	cd "$(OPENWRT)" && ./scripts/feeds update -a && ./scripts/feeds install -a

configure:
	@test -f "$(OPENWRT)/feeds/luci/luci.mk" || { printf '%s\n' 'Run make feeds first.' >&2; exit 1; }
	@if [ -L "$(OPENWRT)/package/crossbox" ]; then test "$$(readlink "$(OPENWRT)/package/crossbox")" = '../../../firmware/packages'; elif [ ! -e "$(OPENWRT)/package/crossbox" ]; then ln -s ../../../firmware/packages "$(OPENWRT)/package/crossbox"; else printf '%s\n' 'Refusing to replace package/crossbox.' >&2; exit 1; fi
	@if [ -L "$(OPENWRT)/files" ]; then test "$$(readlink "$(OPENWRT)/files")" = '../../firmware/files'; elif [ ! -e "$(OPENWRT)/files" ]; then ln -s ../../firmware/files "$(OPENWRT)/files"; else printf '%s\n' 'Refusing to replace the OpenWrt files overlay.' >&2; exit 1; fi
	@cat configs/archer-ax55-v1.seed >> "$(OPENWRT)/.config"
	$(MAKE) -C "$(OPENWRT)" defconfig

firmware: configure
	@mkdir -p "$(OPENWRT)/tmp/crossbox-previous-metadata"
	@if [ -f "$(OPENWRT)/tmp/.profiles.json" ]; then mv "$(OPENWRT)/tmp/.profiles.json" "$(OPENWRT)/tmp/crossbox-previous-metadata/profiles-tmp.json"; fi
	@if [ -f "$(OPENWRT)/bin/targets/qualcommax/ipq50xx/profiles.json" ]; then mv "$(OPENWRT)/bin/targets/qualcommax/ipq50xx/profiles.json" "$(OPENWRT)/tmp/crossbox-previous-metadata/profiles.json"; fi
	$(MAKE) -C "$(OPENWRT)" -j$(JOBS)

menuconfig: configure
	$(MAKE) -C "$(OPENWRT)" menuconfig
