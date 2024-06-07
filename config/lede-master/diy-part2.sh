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
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' ./feeds/luci/collections/luci/Makefile

# Add autocore support for armvirt
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armvirt/g' package/lean/autocore/Makefile

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings
echo "DISTRIB_SOURCECODE='lede'" >>package/base-files/files/etc/openwrt_release

# Fix xfsprogs build error
# 2024年6月6日 尝试关闭该修复，看看官方修复了没
# sed -i 's|TARGET_CFLAGS += -DHAVE_MAP_SYNC.*|TARGET_CFLAGS += -DHAVE_MAP_SYNC $(if $(CONFIG_USE_MUSL),-D_LARGEFILE64_SOURCE)|' feeds/packages/utils/xfsprogs/Makefile

# Modify default IP（FROM 192.168.1.1 CHANGE TO 192.168.31.4）
sed -i 's/192.168.1.1/192.168.7.1/g' package/base-files/files/bin/config_generate

# Replace the default software source
# sed -i 's#openwrt.proxy.ustclug.org#mirrors.bfsu.edu.cn\\/openwrt#' package/lean/default-settings/files/zzz-default-settings

# readd cpufreq for aarch64
sed -i 's/LUCI_DEPENDS.*/LUCI_DEPENDS:=\@\(arm\|\|aarch64\)/g' feeds/luci/applications/luci-app-cpufreq/Makefile
sed -i 's/services/system/g'  feeds/luci/applications/luci-app-cpufreq/luasrc/controller/cpufreq.lua

# 优化
rm -rf package/base-files/files/etc/sysctl.d/base.conf
wget -P package/base-files/files/etc/sysctl.d https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/base.conf
rm -rf package/base-files/files/etc/sysctl.d/pro.conf
wget -P package/base-files/files/etc/sysctl.d https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/pro.conf
rm -rf package/base-files/files/etc/sysctl.d/99-custom.conf
wget -P package/base-files/files/etc/sysctl.d https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/99-custom.conf
# rm -rf package/base-files/files/etc/balance_irq
# wget -P package/base-files/files/etc  https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/balance_irq
# rm -rf package/base-files/files/usr/sbin/balethirq.pl
# wget -P package/base-files/files/usr/sbin https://raw.githubusercontent.com/unifreq/openwrt_packit/master/files/balethirq.pl
# rm -rf package/base-files/files/usr/sbin/fixcpufreq.pl
# wget -P package/base-files/files/usr/sbin https://raw.githubusercontent.com/unifreq/openwrt_packit/master/files/fixcpufreq.pl

# 添加自启动
# chmod 755 -R package/base-files/files/usr/sbin
# sed -i '/exit 0/i\/usr/sbin/balethirq.pl' package/base-files/files/etc/rc.local
# sed -i '/exit 0/i\/usr/sbin/fixcpufreq.pl' package/base-files/files/etc/rc.local

# 下载singbox的db数据
rm -rf package/base-files/files/usr/share/singbox/geoip.db
wget -P package/base-files/files/usr/share/singbox https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.db
rm -rf package/base-files/files/usr/share/singbox/geosite.db
wget -P package/base-files/files/usr/share/singbox https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.db

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
# 2024年6月6日 passwall也有不按照分流的情况，再试试passwall2

# passwall2
merge_package https://github.com/xiaorouji/openwrt-passwall2 openwrt-passwall2/luci-app-passwall2

# passwall
merge_package https://github.com/xiaorouji/openwrt-passwall openwrt-passwall/luci-app-passwall

# smartDNS
merge_package https://github.com/pymumu/openwrt-smartdns openwrt-smartdns
merge_package https://github.com/pymumu/luci-app-smartdns luci-app-smartdns

# feeds use openwrt 23.05 golang
# rm -rf feeds/packages/lang/golang
# git clone --depth=1 --single-branch https://github.com/openwrt/packages openwrt-wrt-packages
# mv openwrt-wrt-packages/lang/golang feeds/packages/lang/
# rm -rf openwrt-wrt-packages

# 2024年2月28日 由于Xray更新1.8.8需要使用1.22golang,openwrt官方源为1.21.5未更新，使用第三方
# 2024年6月6日 时间差不多了，取消go的替换
# rm -rf feeds/packages/lang/golang
# git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 22.x feeds/packages/lang/golang

# qca-nss-sfe(shortcut-fe)
# 2024年3月2日 lede 无法编译,放弃了
# rm -rf package/qca/shortcut-fe
# git clone --depth=1 --single-branch https://github.com/happyplum/qca-nss-sfe qca-nss-sfe
# mv qca-nss-sfe package/qca/shortcut-fe

./scripts/feeds update -a
./scripts/feeds install -a

echo "========================="
echo " DIY2 配置完成……"
