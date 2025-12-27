#!/bin/bash
set -e # 遇到错误立即退出

# 检查必要的参数
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <path_to_sdk> <path_to_apfree_wifidog_src>"
    exit 1
fi

SDK_PATH="$1"
APFREE_WIFIDOG_SRC="$2"

# 定义输出路径
MAKEFILE_PATH="$SDK_PATH/package/apfree-wifidog/Makefile"
INIT_PATH="$SDK_PATH/package/apfree-wifidog/files/wifidog.init"

# 创建必要的目录
mkdir -p "$(dirname "$MAKEFILE_PATH")"
mkdir -p "$(dirname "$INIT_PATH")"

# --- 生成 Makefile ---
cat > "$MAKEFILE_PATH" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=apfree-wifidog
PKG_VERSION:=1.3.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=GitHub Actions

include $(INCLUDE_DIR)/package.mk

define Package/apfree-wifidog
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Captive Portals
  TITLE:=A free wifidog implementation
  DEPENDS:=+libubox +libuci +libjson-c +libevent2 +libnftnl +libmnl +libnetfilter-queue +libmosquitto +libopenssl +libcurl +libbpf +iptables +kmod-ipt-nat +cmake
endef

define Package/apfree-wifidog/description
  apfree_wifidog is a free implementation of the wifidog captive portal.
endef

define Build/Prepare
	$(CP) ./src/. $(PKG_BUILD_DIR)/
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/build && \\
	cd $(PKG_BUILD_DIR)/build && \\
	export PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/host/lib/pkgconfig" && \\
	if cmake .. \\\\
		-DCMAKE_SYSTEM_NAME=Linux \\\\
		-DCMAKE_SYSTEM_PROCESSOR=x86_64 \\\\
		-DCMAKE_C_COMPILER=$(TARGET_CC) \\\\
		-DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include" \\\\
		-DCMAKE_EXE_LINKER_FLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib" \\\\
		-DCMAKE_INSTALL_PREFIX=/usr \\\\
		-DCMAKE_FIND_ROOT_PATH=$(STAGING_DIR) \\\\
		-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \\\\
		-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \\\\
		-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \\\\
		-DCMAKE_PREFIX_PATH=$(STAGING_DIR)/usr; then \\\\
		echo "CMake configuration succeeded with PKG_CONFIG_PATH." && \\
		make -j$(NUM_JOBS); \\
	else \\
		echo "CMake configuration failed with PKG_CONFIG_PATH. Attempting fallback method..." && \\
		UCI_HEADER_PATH=$$(find $(STAGING_DIR) -name "uci.h" -type f -print -quit | xargs dirname) && \\
		if [ -n "$$UCI_HEADER_PATH" ]; then \\
			echo "Found uci.h in: $$UCI_HEADER_PATH" && \\
			rm -rf * && \\
			if cmake .. \\\\
				-DCMAKE_SYSTEM_NAME=Linux \\\\
				-DCMAKE_SYSTEM_PROCESSOR=x86_64 \\\\
				-DCMAKE_C_COMPILER=$(TARGET_CC) \\\\
				-DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -I$$UCI_HEADER_PATH" \\\\
				-DCMAKE_EXE_LINKER_FLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib" \\\\
				-DCMAKE_INSTALL_PREFIX=/usr \\\\
				-DCMAKE_FIND_ROOT_PATH=$(STAGING_DIR) \\\\
				-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \\\\
				-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \\\\
				-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \\\\
				-DCMAKE_PREFIX_PATH=$(STAGING_DIR)/usr \\\\
				-DUCI_INCLUDE_DIRS="$$UCI_HEADER_PATH"; then \\\\
				echo "CMake configuration succeeded with explicit UCI_INCLUDE_DIRS." && \\
				make -j$(NUM_JOBS); \\
			else \\
				echo "CMake configuration failed with explicit UCI_INCLUDE_DIRS. Build failed." >&2 && \\
				exit 1; \\
			fi; \\
		else \\
			echo "ERROR: Could not find uci.h for fallback method." >&2 && \\
			exit 1; \\
		fi; \\
	fi
endef

define Package/apfree-wifidog/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/wifidogx $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/wdctlx $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/wifidog.init $(1)/etc/init.d/wifidog
endef

$(eval $(call BuildPackage,apfree-wifidog))
EOF

# --- 生成 Init Script ---
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

stop_service() {
    killall wifidogx 2>/dev/null
}
EOF

echo "Makefile and init script generated successfully at $MAKEFILE_PATH and $INIT_PATH"
