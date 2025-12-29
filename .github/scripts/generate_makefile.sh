#!/bin/bash
set -e

SDK_PATH="$1"
APFREE_WIFIDOG_SRC="$2"

# 创建主程序的 Makefile
MAIN_MAKEFILE_PATH="$SDK_PATH/package/apfree-wifidog/Makefile"
mkdir -p "$(dirname "$MAIN_MAKEFILE_PATH")"
mkdir -p "$SDK_PATH/package/apfree-wifidog/files"

cat > "$MAIN_MAKEFILE_PATH" << 'EOF'
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
  DEPENDS:=+libubox +libuci +libjson-c +libevent2 +libevent2-openssl +libnftnl +libmnl +libnetfilter-queue +libmosquitto +libopenssl +libcurl +libbpf +apfree-wifidog-ebpf
endef

CMAKE_OPTIONS += \
	-DCMAKE_INCLUDE_PATH="$(STAGING_DIR)/usr/include" \
	-DCMAKE_LIBRARY_PATH="$(STAGING_DIR)/usr/lib" \
	-DUBUS_SUPPORT=ON \
	-DBPF_SUPPORT=ON \
	-DENABLE_XDPI_FEATURE=OFF

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/apfree-wifidog/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/wifidogx $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/wdctlx $(1)/usr/bin/
	$(INSTALL_BIN) ./files/wifidog.init $(1)/etc/init.d/wifidog
	$(CP) $(PKG_BUILD_DIR)/config/wifidog.conf $(1)/etc/config/wifidogx 2>/dev/null || true
endef

$(eval $(call BuildPackage,apfree-wifidog))
EOF

# 创建 eBPF 组件的 Makefile
EBPF_MAKEFILE_PATH="$SDK_PATH/package/apfree-wifidog-ebpf/Makefile"
mkdir -p "$(dirname "$EBPF_MAKEFILE_PATH")"

cat > "$EBPF_MAKEFILE_PATH" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=apfree-wifidog-ebpf
PKG_VERSION:=8.11.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=local
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/apfree-wifidog-ebpf
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Captive Portals
  TITLE:=Apfree Wifidog eBPF Components
  DEPENDS:=+libbpf +libelf +libpthread +libjson-c +libuci
endef

CMAKE_OPTIONS += \
	-DCMAKE_INCLUDE_PATH="$(STAGING_DIR)/usr/include" \
	-DCMAKE_LIBRARY_PATH="$(STAGING_DIR)/usr/lib" \
	-DENABLE_XDPI_FEATURE=ON

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/ebpf/* $(PKG_BUILD_DIR)/
endef

define Package/apfree-wifidog-ebpf/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/aw-bpfctl $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/event_daemon $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/dns-monitor $(1)/usr/bin/
endef

$(eval $(call BuildPackage,apfree-wifidog-ebpf))
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
