#!/bin/bash
set -e

SDK_PATH="$1"
APFREE_WIFIDOG_SRC="$2"
MAKEFILE_PATH="$SDK_PATH/package/apfree-wifidog/Makefile"

mkdir -p "$(dirname "$MAKEFILE_PATH")"
mkdir -p "$SDK_PATH/package/apfree-wifidog/files"

cat > "$MAKEFILE_PATH" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=apfree-wifidog
PKG_VERSION:=8.11.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=local
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/apfree-wifidog
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Captive Portals
  TITLE:=Apfree Wifidog
  # 必须列出所有依赖，触发 SDK 的自动链接
  DEPENDS:=+libubox +libuci +libjson-c +libevent2 +libevent2-openssl +libnftnl +libmnl +libnetfilter-queue +libmosquitto +libopenssl +libcurl +libbpf
endef

# 关键：强制告诉 CMake 到 Staging Dir 寻找头文件和库
CMAKE_OPTIONS += \
	-DCMAKE_INCLUDE_PATH="$(STAGING_DIR)/usr/include" \
	-DCMAKE_LIBRARY_PATH="$(STAGING_DIR)/usr/lib" \
	-DUBUS_SUPPORT=ON \
	-DBPF_SUPPORT=ON

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/apfree-wifidog/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/lib/bpf $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/wifidogx $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/wdctlx $(1)/usr/bin/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/bpf/*.o $(1)/lib/bpf/ 2>/dev/null || true
	$(INSTALL_BIN) ./files/wifidog.init $(1)/etc/init.d/wifidog
	$(CP) $(PKG_BUILD_DIR)/config/wifidog.conf $(1)/etc/config/wifidog 2>/dev/null || true
endef

$(eval $(call BuildPackage,apfree-wifidog))
EOF

# 生成默认的 init 脚本
cat > "$SDK_PATH/package/apfree-wifidog/files/wifidog.init" << 'EOF'
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
