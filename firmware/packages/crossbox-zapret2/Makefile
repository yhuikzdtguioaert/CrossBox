include $(TOPDIR)/rules.mk

PKG_NAME:=crossbox-zapret2
PKG_VERSION:=2026.10.24
PKG_RELEASE:=1
PKG_SOURCE:=zapret2-4a33055448ce5f4e7acc704e1fbe0d8a8a6aa08d.tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/bol-van/zapret2/tar.gz/4a33055448ce5f4e7acc704e1fbe0d8a8a6aa08d?
PKG_HASH:=f4268bc612ee3ee31176bc3b5cb5c8bd6b9e1c2a5bd3b89783161b24b95bf620
PKG_BUILD_DIR:=$(BUILD_DIR)/zapret2-4a33055448ce5f4e7acc704e1fbe0d8a8a6aa08d
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=docs/LICENSE.txt
PKG_BUILD_PARALLEL:=1
include $(INCLUDE_DIR)/package.mk

define Package/crossbox-zapret2
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CrossBox zapret2 NFQUEUE engine
  URL:=https://github.com/bol-van/zapret2
  DEPENDS:=+libnetfilter-queue +libnfnetlink +libmnl +libcap +zlib +liblua +kmod-nft-queue
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/nfq2 \
		CC="$(TARGET_CC)" STRIPP= LUA_JIT=0 \
		LUA_CFLAGS="-I$(STAGING_DIR)/usr/include" LUA_LIB="-llua" \
		CFLAGS="$(TARGET_CFLAGS) -std=gnu99 -ffunction-sections -fdata-sections" \
		LDFLAGS="$(TARGET_LDFLAGS) -Wl,--gc-sections"
endef

define Package/crossbox-zapret2/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/share/zapret2/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/nfq2/nfqws2 $(1)/usr/bin/nfqws2
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/lua/zapret-lib.lua $(PKG_BUILD_DIR)/lua/zapret-antidpi.lua $(1)/usr/share/zapret2/lua/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/fake/quic_initial_www_google_com.bin $(1)/usr/share/zapret2/quic.bin
endef

$(eval $(call BuildPackage,crossbox-zapret2))
