include $(TOPDIR)/rules.mk

PKG_NAME:=crossbox-mihomo
PKG_VERSION:=1.19.33
PKG_RELEASE:=1
PKG_SOURCE:=mihomo-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/MetaCubeX/mihomo/tar.gz/refs/tags/v$(PKG_VERSION)?
PKG_HASH:=e7c596b37ff27ec487d19b1920f73e0c97a78067ea35766530ee9659ade72711
PKG_BUILD_DIR:=$(BUILD_DIR)/mihomo-$(PKG_VERSION)
PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16
GO_PKG:=github.com/metacubex/mihomo
GO_PKG_BUILD_PKG:=github.com/metacubex/mihomo
GO_PKG_LDFLAGS_X:=$(GO_PKG)/constant.Version=v$(PKG_VERSION)
# Use the kernel TUN stack on routers. All outbound protocols stay available.
include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/crossbox-mihomo
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CrossBox multi-protocol VPN engine
  URL:=https://github.com/MetaCubeX/mihomo
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle +kmod-tun
endef

define Package/crossbox-mihomo/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/mihomo $(1)/usr/bin/mihomo
endef

$(eval $(call BuildPackage,crossbox-mihomo))
