#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt for Amlogic s9xxx tv box
# Function: Diy script (After Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

echo "开始 DIY2 配置……"
echo "========================="

function merge_package(){
    repo=`echo $1 | rev | cut -d'/' -f 1 | rev`
    pkg=`echo $2 | rev | cut -d'/' -f 1 | rev`
    # find package/ -follow -name $pkg -not -path "package/custom/*" | xargs -rt rm -rf
    git clone --depth=1 --single-branch $1
    mv $2 package/custom/
    rm -rf $repo
}
function drop_package(){
    find package/ -follow -name $1 -not -path "package/custom/*" | xargs -rt rm -rf
}
function merge_feed(){
    if [ ! -d "feed/$1" ]; then
        echo >> feeds.conf.default
        echo "src-git $1 $2" >> feeds.conf.default
    fi
    ./scripts/feeds update $1
    ./scripts/feeds install -a -p $1
}
rm -rf package/custom; mkdir package/custom

# ------------------------------- Main source started -------------------------------
#
# Modify default theme（FROM uci-theme-bootstrap CHANGE TO luci-theme-material）
# sed -i 's/luci-theme-bootstrap/luci-theme-material/g' ./feeds/luci/collections/luci/Makefile

# Add autocore support for armvirt
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armvirt/g' package/lean/autocore/Makefile

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings
echo "DISTRIB_SOURCECODE='lede'" >>package/base-files/files/etc/openwrt_release

# Fix xfsprogs build error
sed -i 's|TARGET_CFLAGS += -DHAVE_MAP_SYNC.*|TARGET_CFLAGS += -DHAVE_MAP_SYNC $(if $(CONFIG_USE_MUSL),-D_LARGEFILE64_SOURCE)|' feeds/packages/utils/xfsprogs/Makefile

# Modify default IP（FROM 192.168.1.1 CHANGE TO 192.168.31.4）
sed -i 's/192.168.1.1/192.168.7.1/g' package/base-files/files/bin/config_generate

# Replace the default software source
# sed -i 's#openwrt.proxy.ustclug.org#mirrors.bfsu.edu.cn\\/openwrt#' package/lean/default-settings/files/zzz-default-settings
#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
# Add luci-app-amlogic
merge_package https://github.com/ophub/luci-app-amlogic luci-app-amlogic/luci-app-amlogic
sed -i "s|https.*/OpenWrt|https://github.com/happyplum/amlogic-s9xxx-openwrt|g" package/custom/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|opt/kernel|https://github.com/ophub/kernel/tree/main/pub/stable|g" package/custom/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|ARMv8|ARMv8_MINI|g" package/custom/luci-app-amlogic/root/etc/config/amlogic
#
# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------

# openClash
# merge_package https://github.com/vernesong/OpenClash OpenClash/luci-app-openclash
# 编译 po2lmo (如果有po2lmo可跳过,其实我不知道啥用)
# pushd package/custom/luci-app-openclash/tools/po2lmo
# make && sudo make install
# popd

# kenzok8 一些翻墙依赖 2023.3.13 使用feeds直接加载passwall库
# merge_package https://github.com/kenzok8/openwrt-packages openwrt-packages/tcping
# merge_package https://github.com/kenzok8/openwrt-packages openwrt-packages/naiveproxy
# merge_package https://github.com/kenzok8/openwrt-packages openwrt-packages/lua-maxminddb

# hellowold 依赖
# tcping和naiveproxy是通用依赖,基本上大部分翻墙都需要,请注意
# merge_package https://github.com/fw876/helloworld helloworld/tcping
# merge_package https://github.com/fw876/helloworld helloworld/naiveproxy
# merge_package https://github.com/fw876/helloworld helloworld/lua-maxminddb
# merge_package https://github.com/fw876/helloworld helloworld/luci-app-vssr

# passwall依赖 passwall和passwall2通用,请注意
# 2023.3.13 取消passwall2，存在分流不按照表进行的情况，使用回passwall
# 2024.1.26 直接使用feeds的xiaorouji/openwrt-passwall-packages下载依赖,不再需要单独依赖下载

# passwall2
merge_package https://github.com/xiaorouji/openwrt-passwall2 openwrt-passwall2/luci-app-passwall2

# passwall
merge_package https://github.com/xiaorouji/openwrt-passwall openwrt-passwall/luci-app-passwall

# smartDNS
merge_package https://github.com/kenzok8/openwrt-packages openwrt-packages/smartdns
merge_package https://github.com/kenzok8/openwrt-packages openwrt-packages/luci-app-smartdns

# feeds use openwrt 23.05 golang
rm -rf feeds/packages/lang/golang
git clone --depth=1 --single-branch https://github.com/openwrt/packages openwrt-wrt-packages
mv openwrt-wrt-packages/lang/golang feeds/packages/lang/
rm -rf openwrt-wrt-packages

./scripts/feeds update -a
./scripts/feeds install -a

echo "========================="
echo " DIY2 配置完成……"