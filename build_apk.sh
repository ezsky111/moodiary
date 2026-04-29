#!/bin/bash
# Moodiary APK 构建脚本
# 生成按规范命名的APK文件: moodiary-{version}-{abi}-release.apk

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Moodiary APK 构建脚本${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# 尝试设置 swap 空间（非关键步骤，失败不影响构建）
if command -v swapon &>/dev/null && [ ! -f /swapfile ]; then
  SWAP_SIZE_MB=$(free -m | awk '/Swap:/{print $2}')
  if [ "${SWAP_SIZE_MB:-0}" -lt 2048 ] 2>/dev/null; then
    echo -e "${YELLOW}尝试设置 swap 空间...${NC}"
    fallocate -l 4G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096 2>/dev/null || true
    chmod 600 /swapfile 2>/dev/null || true
    mkswap /swapfile 2>/dev/null || true
    swapon /swapfile 2>/dev/null || echo -e "${YELLOW}  (swap 设置跳过，非关键)${NC}"
  fi
fi
echo ""

# 获取版本号
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
echo -e "${YELLOW}版本号: ${VERSION}${NC}"
echo ""

# 限制 Rust 并行编译任务数以控制内存使用
export CARGO_BUILD_JOBS=4

echo -e "${YELLOW}[1/3] 构建APK（分架构）...${NC}"
CARGO_BUILD_JOBS=4 flutter build apk --release --split-per-abi --android-skip-build-dependency-validation
echo ""

# 重命名APK
echo -e "${YELLOW}[2/3] 重命名APK文件...${NC}"
APK_DIR="build/app/outputs/flutter-apk"
for apk in "$APK_DIR"/app-*-release.apk; do
  [ -f "$apk" ] || continue
  abi=$(echo "$apk" | sed -n 's/.*app-\(.*\)-release\.apk/\1/p')
  new_name="$APK_DIR/moodiary-${VERSION}-${abi}-release.apk"
  mv "$apk" "$new_name"
  echo "  $new_name"
done
echo ""

# 显示构建结果
echo -e "${YELLOW}[3/3] 构建完成！${NC}"
echo ""
echo -e "${GREEN}生成的APK文件:${NC}"
ls -lh "$APK_DIR"/moodiary-*-release.apk | awk '{print "  " $9 " (" $5 ")"}'
echo ""

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   构建成功！APK位于 build/app/outputs/flutter-apk/${NC}"
echo -e "${GREEN}======================================${NC}"
