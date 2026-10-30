include $(TOPDIR)/rules.mk

LUCI_TITLE:=CrossBox dashboard, VPN and zapret2 management
LUCI_MAINTAINER:=CrossBox Project
LUCI_URL:=https://github.com/yhuikzdtguioaert/CrossBox
LUCI_DEPENDS:=+luci-base +luci-mod-admin-full +rpcd-mod-ucode +ucode-mod-fs +ucode-mod-uci +curl +ca-bundle +fwtool +crossbox-mihomo +crossbox-zapret2 +kmod-tun +kmod-nft-queue +luci-theme-crossbox
PKG_LICENSE:=Apache-2.0

define Package/luci-app-crossbox/conffiles
/etc/config/crossbox_update
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
