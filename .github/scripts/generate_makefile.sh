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

# --- 生成 Makefile（修复版）---
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
  DEPENDS:=+libubox +libuci +libjson-c +libevent2 +libnftnl +libmnl +libnetfilter-queue +libmosquitto +libopenssl +libcurl +libbpf +iptables +kmod-ipt-nat
endef

define Package/apfree-wifidog/description
  apfree_wifidog is a free implementation of the wifidog captive portal.
endef

define Build/Prepare
	$(CP) ./src/. $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(call Build/Compile/Default)
endef

define Build/Configure
	# 让 OpenWrt 调用我们的编译脚本
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

# --- 创建编译脚本 ---
COMPILE_SCRIPT="$SDK_PATH/package/apfree-wifidog/compile.sh"
cat > "$COMPILE_SCRIPT" << 'EOF'
#!/bin/bash
set -e

cd $(dirname "$0")/src
echo "Building in: $(pwd)"

# 创建构建目录
mkdir -p build
cd build

# 设置环境变量
export STAGING_DIR="$STAGING_DIR"
export PKG_CONFIG_PATH="$STAGING_DIR/usr/lib/pkgconfig:$STAGING_DIR/host/lib/pkgconfig"

echo "=== 环境信息 ==="
echo "TARGET_CC: $TARGET_CC"
echo "TARGET_CFLAGS: $TARGET_CFLAGS"
echo "STAGING_DIR: $STAGING_DIR"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

# 查找头文件
UCI_INC=$(find "$STAGING_DIR" -name "uci.h" -type f | head -1 | xargs dirname 2>/dev/null || echo "")
JSON_C_INC=$(find "$STAGING_DIR" -name "json.h" -type f | head -1 | xargs dirname 2>/dev/null || echo "")

echo "UCI include dir: $UCI_INC"
echo "JSON-C include dir: $JSON_C_INC"

# 构建 CMake 参数
CMAKE_ARGS=(
  -DCMAKE_SYSTEM_NAME=Linux
  -DCMAKE_SYSTEM_PROCESSOR=x86_64
  -DCMAKE_C_COMPILER="$TARGET_CC"
  -DCMAKE_CXX_COMPILER="$TARGET_CXX"
  -DCMAKE_C_FLAGS="$TARGET_CFLAGS -I$STAGING_DIR/usr/include"
  -DCMAKE_EXE_LINKER_FLAGS="$TARGET_LDFLAGS -L$STAGING_DIR/usr/lib"
  -DCMAKE_INSTALL_PREFIX=/usr
  -DCMAKE_FIND_ROOT_PATH="$STAGING_DIR"
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
)

# 添加头文件路径
if [ -n "$UCI_INC" ]; then
  CMAKE_ARGS+=(-DUCI_INCLUDE_DIRS="$UCI_INC")
fi

if [ -n "$JSON_C_INC" ]; then
  CMAKE_ARGS+=(-DJSON-C_INCLUDE_DIR="$JSON_C_INC")
fi

echo "=== 运行 CMake ==="
cmake .. "${CMAKE_ARGS[@]}"

echo "=== 开始编译 ==="
make -j$(nproc)

echo "=== 编译完成 ==="
ls -lh wifidogx wdctlx 2>/dev/null || true
EOF

chmod +x "$COMPILE_SCRIPT"

# 修改 Makefile 使用编译脚本
echo '
define Build/Compile
	cd $(PKG_BUILD_DIR) && sh $(CURDIR)/compile.sh
endef
' >> "$MAKEFILE_PATH"

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
