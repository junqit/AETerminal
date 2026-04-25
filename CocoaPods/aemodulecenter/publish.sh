#!/bin/bash

# AEModuleCenter 快速发布脚本
# 使用方法: ./publish.sh [version]
# 示例: ./publish.sh 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 版本号
VERSION=${1:-"1.0.0"}

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  AEModuleCenter 发布脚本 v$VERSION${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# 检查是否在 git 仓库中
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}初始化 Git 仓库...${NC}"
    git init
    git remote add origin git@github.com:junqit/aemodulecenter.git
    echo -e "${GREEN}✓ Git 仓库初始化完成${NC}"
    echo ""
fi

# 检查工作区状态
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}检测到未提交的更改${NC}"
    git status -s
    echo ""
    read -p "是否继续提交? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}✗ 发布已取消${NC}"
        exit 1
    fi
fi

# 提交代码
echo -e "${YELLOW}Step 1/5: 提交代码...${NC}"
git add .
git commit -m "Release version $VERSION" || echo "No changes to commit"
echo -e "${GREEN}✓ 代码已提交${NC}"
echo ""

# 切换到 main 分支
echo -e "${YELLOW}Step 2/5: 切换到 main 分支...${NC}"
git branch -M main
echo -e "${GREEN}✓ 已切换到 main 分支${NC}"
echo ""

# 推送代码
echo -e "${YELLOW}Step 3/5: 推送到远程仓库...${NC}"
git push -u origin main
echo -e "${GREEN}✓ 代码已推送${NC}"
echo ""

# 创建并推送标签
echo -e "${YELLOW}Step 4/5: 创建版本标签 $VERSION...${NC}"
if git rev-parse "$VERSION" >/dev/null 2>&1; then
    echo -e "${RED}✗ 标签 $VERSION 已存在${NC}"
    read -p "是否删除旧标签并重新创建? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git tag -d "$VERSION"
        git push origin --delete "$VERSION"
        git tag -a "$VERSION" -m "Release version $VERSION"
        git push origin "$VERSION"
        echo -e "${GREEN}✓ 标签已更新${NC}"
    else
        echo -e "${RED}✗ 发布已取消${NC}"
        exit 1
    fi
else
    git tag -a "$VERSION" -m "Release version $VERSION"
    git push origin "$VERSION"
    echo -e "${GREEN}✓ 标签已创建并推送${NC}"
fi
echo ""

# 验证 Podspec
echo -e "${YELLOW}Step 5/5: 验证 Podspec...${NC}"
echo -e "${BLUE}注意: 如果验证失败，请检查是否需要等待 GitHub 同步${NC}"
echo ""

pod spec lint AEModuleCenter.podspec --allow-warnings --verbose || {
    echo -e "${RED}✗ Podspec 验证失败${NC}"
    echo -e "${YELLOW}可能的原因:${NC}"
    echo "  1. GitHub 仓库还未同步（请等待 1-2 分钟后重试）"
    echo "  2. 网络连接问题"
    echo "  3. podspec 配置错误"
    echo ""
    echo -e "${YELLOW}手动验证命令:${NC}"
    echo "  pod spec lint AEModuleCenter.podspec --allow-warnings"
    exit 1
}

echo -e "${GREEN}✓ Podspec 验证通过${NC}"
echo ""

# 完成
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  ✓ 发布完成!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}使用方式:${NC}"
echo ""
echo "1. 在 Podfile 中添加:"
echo "   ${YELLOW}pod 'AEModuleCenter', :git => 'git@github.com:junqit/aemodulecenter.git', :tag => '$VERSION'${NC}"
echo ""
echo "2. 或使用 HTTPS:"
echo "   ${YELLOW}pod 'AEModuleCenter', :git => 'https://github.com/junqit/aemodulecenter.git', :tag => '$VERSION'${NC}"
echo ""
echo "3. 然后运行:"
echo "   ${YELLOW}pod install${NC}"
echo ""
echo -e "${BLUE}发布到 CocoaPods Trunk (可选):${NC}"
echo "   ${YELLOW}pod trunk push AEModuleCenter.podspec${NC}"
echo ""
echo -e "${GREEN}🎉 祝使用愉快!${NC}"
