#!/bin/bash
set -e

SDK_PATH="$1"
APFREE_WIFIDOG_SRC="$2"

MAKEFILE_PATH="$SDK_PATH/package/apfree-wifidog/Makefile"
INIT_PATH="$SDK_PATH/package/apfree-wifidog/files/wifidog.init"

mkdir -p "$(dirname "$MAKEFILE_PATH")"
mkdir -p "$(dirname "$INIT_PATH")"

# --- 生成 Makefile ---
cat > "$MAKEFILE_PATH" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=apfree-wifidog
PKG_VERSION:=8.11.2712
PKG_RELEASE:=1


PKG_SOURCE_PROTO:=local
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=
PKG_HASH:=skip

PKG_MAINTAINER:=GitHub Actions
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/apfree-wifidog
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Captive Portals
  TITLE:=Apfree Wifidog (Local Build)
  DEPENDS:=+libubox +libuci +libjson-c +libevent2 +libevent2-openssl +libnftnl +libmnl +libnetfilter-queue +libmosquitto +libopenssl +libcurl +libbpf
endef

# 重点：覆盖 Prepare 步骤，直接使用 SDK 内的 src 目录
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

# CMake 参数优化
CMAKE_OPTIONS += \
	-DCMAKE_BUILD_TYPE=Release \
	-DUBUS_SUPPORT=ON

define Package/apfree-wifidog/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/wifidogx $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/wdctlx $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/lib/bpf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/bpf/*.o $(1)/lib/bpf/ 2>/dev/null || true
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/wifidog.init $(1)/etc/init.d/wifidogx

	
endef

$(eval $(call BuildPackage,apfree-wifidog))
EOF

# --- 生成 Init 脚本 ---
cat > "$INIT_PATH" << 'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/wifidogx
    procd_set_param respawn
    procd_close_instance
}
EOF

echo "Done: Local Makefile generated."
