#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

# PLOAM debug: dump 0x01/0x04 raw for preassigned-delay analysis (G.987.3)
PON_PLOAM=$(find ../feeds/pon_drivers/ -maxdepth 4 -type f -wholename "*/airoha-xpon/src/airoha-xpon-ploam.c" 2>/dev/null | head -n 1)
if [ -f "$PON_PLOAM" ]; then
  echo "patching $PON_PLOAM"
  python3 - "$PON_PLOAM" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
old1 = "\tu32 preamble_reg, delimiter_reg;\n\tint ret;\n\n\tif (line_rate || delimiter_len > 8 || preamble_len > 8)"
new1 = "\tu32 preamble_reg, delimiter_reg;\n\tint ret;\n\n\tdev_info(xpon->dev, \"PLOAM-DBG 0x01 raw: %*phN\\n\", AIROHA_XGPON_PLOAMD_BYTES, message);\n\tdev_info(xpon->dev, \"PLOAM-DBG 0x01 overhead: byte7=0x%02x (bit5 preassign_en=%u) bytes8-9=0x%02x%02x (%u)\\n\", message[7], !!(message[7] & BIT(5)), message[8], message[9], (unsigned int)((message[8] << 8) | message[9]));\n\n\tif (line_rate || delimiter_len > 8 || preamble_len > 8)"
assert src.count(old1) == 1, f"loc1={src.count(old1)}"
src = src.replace(old1, new1)
old2 = "\tbool positive = !(message[4] & BIT(1));\n\n\tif (xpon->onu_state == AIROHA_XGPON_O4) {"
new2 = "\tbool positive = !(message[4] & BIT(1));\n\n\tdev_info(xpon->dev, \"PLOAM-DBG 0x04 raw: %*phN (dest=%u absolute=%u positive=%u eqd=0x%08x state=%d)\\n\", AIROHA_XGPON_PLOAMD_BYTES, message, dest, absolute, positive, eqd, xpon->onu_state);\n\n\tif (xpon->onu_state == AIROHA_XGPON_O4) {"
assert src.count(old2) == 1, f"loc2={src.count(old2)}"
src = src.replace(old2, new2)
open(path, "w").write(src)
print("ploam debug injected")
PY
fi
