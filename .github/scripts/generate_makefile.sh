#!/bin/bash
set -e

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

# --- 生成 Makefile（显式阻止下载）---
cat > "$MAKEFILE_PATH" << 'EOF'
include $(TOPDIR)/rules.mk

# --- 显式定义源码相关变量，阻止下载 ---
# 设置一个非标准的协议，让 package.mk 无法处理，从而跳过下载
PKG_SOURCE_PROTO:=local
# 或者显式设置为空
# PKG_SOURCE:=
# PKG_SOURCE_URL:=

# --- 定义包信息 ---
PKG_NAME:=apfree-wifidog # <--- 改回 apfree-wifidog
# 确保这个版本号用于最终的 .ipk 文件名
PKG_VERSION:=8.11.0
PKG_RELEASE:=8

PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=GitHub Actions

# --- 包含 OpenWrt 标准包定义 ---
include $(INCLUDE_DIR)/package.mk

define Package/apfree-wifidog # <--- 包名也要改回
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Captive Portals
  TITLE:=A free wifidog implementation
  DEPENDS:=+libubox +libuci +libjson-c +libevent2 +libevent_openssl +libnftnl +libmnl +libnetfilter-queue +libmosquitto +libopenssl +libcurl +libbpf +iptables +kmod-ipt-nat
endef

define Package/apfree-wifidog/description # <--- 包名也要改回
  apfree_wifidog is a free implementation of the wifidog captive portal.
endef

# --- 准备构建目录 ---
define Build/Prepare
	# 清空构建目录，确保只使用本地源码
	rm -rf $(PKG_BUILD_DIR)/.[^.]* $(PKG_BUILD_DIR)/*
	# 复制本地源码到构建目录
	$(CP) ./src/. $(PKG_BUILD_DIR)/
endef

# --- 编译步骤 ---
define Build/Compile
	# 创建构建目录
	mkdir -p $(PKG_BUILD_DIR)/build
	cd $(PKG_BUILD_DIR)/build
	
	# 设置环境变量
	export PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/host/lib/pkgconfig"
	
	# 配置CMake（启用优化，禁用调试）
	cmake .. \
		-DCMAKE_SYSTEM_NAME=Linux \
		-DCMAKE_SYSTEM_PROCESSOR=x86_64 \
		-DCMAKE_C_COMPILER=$(TARGET_CC) \
		-DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include -Os -DNDEBUG -ffunction-sections -fdata-sections" \
		-DCMAKE_EXE_LINKER_FLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib -Wl,--gc-sections" \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_FIND_ROOT_PATH=$(STAGING_DIR) \
		-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
		-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY || { \
		# 如果失败，尝试备用配置
		echo "=== CMake failed, trying fallback ==="; \
		UCI_INC=$$(find $(STAGING_DIR) -name "uci.h" -type f -print -quit | xargs dirname); \
		if [ -n "$$UCI_INC" ]; then \
			echo "Found uci.h in: $$UCI_INC"; \
			cmake .. \
				-DCMAKE_SYSTEM_NAME=Linux \
				-DCMAKE_SYSTEM_PROCESSOR=x86_64 \
				-DCMAKE_C_COMPILER=$(TARGET_CC) \
				-DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -I$$UCI_INC -Os -DNDEBUG -ffunction-sections -fdata-sections" \
				-DCMAKE_EXE_LINKER_FLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib -Wl,--gc-sections" \
				-DCMAKE_INSTALL_PREFIX=/usr \
				-DCMAKE_BUILD_TYPE=Release \
				-DCMAKE_FIND_ROOT_PATH=$(STAGING_DIR) \
				-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
				-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
				-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
				-DUCI_INCLUDE_DIRS="$$UCI_INC"; \
		else \
			echo "ERROR: Could not find uci.h"; \
			exit 1; \
		fi; \
	}
	
	# 编译
	make -j$(NUM_JOBS) || make
	
	# 剥离调试符号
	if [ -f $(PKG_BUILD_DIR)/build/src/wifidogx ]; then \
		$(TARGET_CROSS)strip --strip-debug --strip-unneeded $(PKG_BUILD_DIR)/build/src/wifidogx; \
		ls -la $(PKG_BUILD_DIR)/build/src/wifidogx; \
	fi
	if [ -f $(PKG_BUILD_DIR)/build/src/wdctlx ]; then \
		$(TARGET_CROSS)strip --strip-debug --strip-unneeded $(PKG_BUILD_DIR)/build/src/wdctlx; \
		ls -la $(PKG_BUILD_DIR)/build/src/wdctlx; \
	fi
	if [ -f $(PKG_BUILD_DIR)/build/wifidogx ]; then \
		$(TARGET_CROSS)strip --strip-debug --strip-unneeded $(PKG_BUILD_DIR)/build/wifidogx; \
		ls -la $(PKG_BUILD_DIR)/build/wifidogx; \
	fi
	if [ -f $(PKG_BUILD_DIR)/build/wdctlx ]; then \
		$(TARGET_CROSS)strip --strip-debug --strip-unneeded $(PKG_BUILD_DIR)/build/wdctlx; \
		ls -la $(PKG_BUILD_DIR)/build/wdctlx; \
	fi
endef

# --- 安装步骤 ---
define Package/apfree-wifidog/install # <--- 包名也要改回
	$(INSTALL_DIR) $(1)/usr/bin
	
	# 只安装剥离后的二进制文件，不包含构建目录
	if [ -f $(PKG_BUILD_DIR)/build/src/wifidogx ]; then \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/src/wifidogx $(1)/usr/bin/; \
	elif [ -f $(PKG_BUILD_DIR)/build/wifidogx ]; then \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/wifidogx $(1)/usr/bin/; \
	else \
		echo "ERROR: wifidogx not found in expected locations!"; \
		find $(PKG_BUILD_DIR) -name "*wifidog*" -type f; \
		exit 1; \
	fi
	
	if [ -f $(PKG_BUILD_DIR)/build/src/wdctlx ]; then \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/src/wdctlx $(1)/usr/bin/; \
	elif [ -f $(PKG_BUILD_DIR)/build/wdctlx ]; then \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/wdctlx $(1)/usr/bin/; \
	else \
		echo "ERROR: wdctlx not found in expected locations!"; \
		find $(PKG_BUILD_DIR) -name "*wdctl*" -type f; \
		exit 1; \
	fi
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/wifidog.init $(1)/etc/init.d/wifidog
endef

# 确保不安装开发文件
define Build/InstallDev
endef

# 清理构建目录中的大文件
define Package/apfree-wifidog/postinst # <--- 包名也要改回
#!/bin/sh
# 配置脚本
echo "apfree-wifidog installed successfully"
endef

$(eval $(call BuildPackage,apfree-wifidog)) # <--- 包名也要改回
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
