name: Build apfree-wifidog with local source

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        submodules: recursive
        
    - name: Setup OpenWrt SDK
      run: |
        # 下载 OpenWrt SDK
        SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
        wget -q $SDK_URL
        tar -xf openwrt-sdk-*.tar.xz
        rm openwrt-sdk-*.tar.xz
        mv openwrt-sdk-* openwrt-sdk
        
    - name: Generate package files
      run: |
        chmod +x generate-package.sh
        ./generate-package.sh ./openwrt-sdk "$(pwd)"
        
    - name: Build package
      run: |
        cd openwrt-sdk
        # 更新 feeds
        ./scripts/feeds update -a
        ./scripts/feeds install -a
        
        # 配置 SDK
        echo "CONFIG_TARGET_x86_64=y" > .config
        echo "CONFIG_TARGET_x86_64_DEVICE_generic=y" >> .config
        echo "CONFIG_PACKAGE_apfree-wifidog=m" >> .config
        
        # 编译
        make defconfig
        make package/apfree-wifidog/compile V=s -j$(nproc)
        
    - name: Find and upload IPK
      run: |
        cd openwrt-sdk
        find . -name "apfree-wifidog_*.ipk" -type f
        
    - name: Upload artifact
      uses: actions/upload-artifact@v4
      with:
        name: apfree-wifidog-ipk
        path: openwrt-sdk/bin/packages/x86_64/base/apfree-wifidog_*.ipk
        if-no-files-found: error
