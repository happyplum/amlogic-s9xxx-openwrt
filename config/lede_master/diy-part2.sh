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
# Set default IP address
default_ip="192.168.7.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
# Modify default IP if an argument is provided and it matches the IP format
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# Modify default theme（FROM uci-theme-bootstrap CHANGE TO luci-theme-material）
# sed -i 's/luci-theme-bootstrap/luci-theme-material/g' ./feeds/luci/collections/luci/Makefile

# Add autocore support for armsr-armv8
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armsr/g' package/lean/autocore/Makefile

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings
echo "DISTRIB_SOURCEREPO='github.com/coolsnowwolf/lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='master'" >>package/base-files/files/etc/openwrt_release

# Set ccache
# Remove existing ccache settings
sed -i '/CONFIG_DEVEL/d' .config
sed -i '/CONFIG_CCACHE/d' .config
# Apply new ccache configuration
if [[ "${2}" == "true" ]]; then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo "# CONFIG_CCACHE is not set" >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi

# 优化
rm -rf package/base-files/files/etc/sysctl.d/base.conf
wget -P package/base-files/files/etc/sysctl.d https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/base.conf
rm -rf package/base-files/files/etc/sysctl.d/pro.conf
wget -P package/base-files/files/etc/sysctl.d https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/pro.conf
rm -rf package/base-files/files/etc/sysctl.d/99-custom.conf
wget -P package/base-files/files/etc/sysctl.d https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/99-custom.conf
rm -rf package/base-files/files/etc/balance_irq
wget -P package/base-files/files/etc  https://raw.githubusercontent.com/happyplum/OpenWrt/main/R68S/config/balance_irq
rm -rf package/base-files/files/usr/sbin/balethirq.pl
wget -P package/base-files/files/usr/sbin https://raw.githubusercontent.com/unifreq/openwrt_packit/master/files/balethirq.pl
rm -rf package/base-files/files/usr/sbin/fixcpufreq.pl
wget -P package/base-files/files/usr/sbin https://raw.githubusercontent.com/unifreq/openwrt_packit/master/files/fixcpufreq.pl
sed -i 's/schedutil/performance/g'  package/base-files/files/usr/sbin/fixcpufreq.pl

# 添加自启动
chmod 755 -R package/base-files/files/usr/sbin
sed -i '/exit 0/i\/usr/sbin/balethirq.pl' package/base-files/files/etc/rc.local
sed -i '/exit 0/i\/usr/sbin/fixcpufreq.pl' package/base-files/files/etc/rc.local

#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
#
# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------


# passwall2
# merge_package https://github.com/xiaorouji/openwrt-passwall2 openwrt-passwall2/luci-app-passwall2

# passwall
merge_package https://github.com/xiaorouji/openwrt-passwall openwrt-passwall/luci-app-passwall

# smartDNS
merge_package https://github.com/pymumu/luci-app-smartdns luci-app-smartdns

./scripts/feeds update -a

# smartDNS 必须update后，防止覆盖
merge_package https://github.com/pymumu/openwrt-smartdns openwrt-smartdns
rm -rf feeds/packages/net/smartdns
mv package/custom/openwrt-smartdns feeds/packages/net/smartdns

./scripts/feeds install -a

echo "========================="
echo " DIY2 配置完成……"
