#!/bin/bash
# preprocess-vitepress.sh - 扫描 novels/ 下所有小说，提取正文，生成 VitePress 所需的 docs/ 结构和动态配置
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NOVELS_DIR="$PROJECT_DIR/novels"
DOCS_DIR="$PROJECT_DIR/docs"

echo "开始预处理小说..."

# 收集所有小说信息
novel_count=0
sidebar_json="{"
nav_items=""
index_cards=""

for novel_dir in "$NOVELS_DIR"/*/; do
    [ -d "$novel_dir" ] || continue
    novel_name=$(basename "$novel_dir")

    # 检查是否有章节文件
    has_chapters=false
    for f in "$novel_dir"/第*章-*.md; do
        [ -f "$f" ] && has_chapters=true && break
    done
    $has_chapters || continue

    novel_count=$((novel_count + 1))

    # 使用小说名称作为 URL 路径（中文友好）
    novel_slug="$novel_name"
    novel_path="/$novel_slug/"

    # 从大纲提取简介
    description=""
    if [ -f "$novel_dir/00-大纲.md" ]; then
        description=$(awk '/^- \*\*题材\*\*/{gsub(/^- \*\*题材\*\*：/, ""); print; exit}' "$novel_dir/00-大纲.md")
    fi

    # 统计字符数
    total_chars=0
    for f in "$novel_dir"/第*章-*.md; do
        [ -f "$f" ] || continue
        chars=$(wc -m < "$f")
        total_chars=$((total_chars + chars))
    done
    word_est=$(( total_chars * 2 / 3 / 10000 ))

    # 创建小说目录
    mkdir -p "$DOCS_DIR/$novel_slug"

    # 处理章节文件，构建 sidebar items
    chapter_count=0
    sidebar_items=""
    first_chapter_link=""

    for file in "$novel_dir"/第*章-*.md; do
        [ -f "$file" ] || continue

        filename=$(basename "$file")
        chapter_count=$((chapter_count + 1))

        # 提取章节编号
        chapter_num=$(echo "$filename" | sed -n 's/第\([0-9]*\)章-.*/\1/p')

        # 提取完整标题
        full_title=$(head -n 1 "$file" | sed 's/^# *//')

        target_file="chapter-${chapter_num}.md"
        target_link="${novel_path}chapter-${chapter_num}"

        # 记录第一章
        if [ -z "$first_chapter_link" ]; then
            first_chapter_link="$target_link"
        fi

        # 提取正文（## 正文 到 ## 章节备注 之间）
        {
            echo "---"
            echo "title: \"${full_title}\""
            echo "---"
            echo ""
            echo "# ${full_title}"
            echo ""
            awk '/^## 正文/{found=1; next} /^## 章节备注/{found=0} found{print}' "$file"
        } > "$DOCS_DIR/$novel_slug/$target_file"

        # 构建 sidebar item JSON
        if [ -n "$sidebar_items" ]; then
            sidebar_items="$sidebar_items,"
        fi
        sidebar_items="$sidebar_items{\"text\":\"${full_title}\",\"link\":\"${target_link}\"}"
    done

    # 生成小说首页
    {
        echo "---"
        echo "title: \"${novel_name}\""
        echo "---"
        echo ""
        echo "<div class=\"novel-intro\">"
        echo ""
        echo "# ${novel_name}"
        echo ""
        if [ -n "$description" ]; then
            echo "> ${description}"
            echo ""
        fi
        echo "📖 共 **${chapter_count}** 章 | 约 **${word_est}** 万字"
        echo ""
        echo "<a class=\"start-btn\" href=\"${first_chapter_link}\">▶ 开始阅读第一章</a>"
        echo ""
        echo "</div>"
    } > "$DOCS_DIR/$novel_slug/index.md"

    # 构建该小说的 sidebar JSON
    if [ "$novel_count" -gt 1 ]; then
        sidebar_json="$sidebar_json,"
    fi
    sidebar_json="$sidebar_json\"${novel_path}\":[{\"text\":\"${novel_name}\",\"collapsed\":false,\"items\":[{\"text\":\"简介\",\"link\":\"${novel_path}\"},${sidebar_items}]}]"

    # 构建 nav 项
    if [ -n "$nav_items" ]; then
        nav_items="$nav_items,"
    fi
    nav_items="$nav_items{\"text\":\"${novel_name}\",\"link\":\"${novel_path}\"}"

    # 构建首页卡片 HTML
    index_cards="$index_cards
<div class=\"novel-card\">
<h2><a href=\"${novel_path}\">${novel_name}</a></h2>"
    if [ -n "$description" ]; then
        index_cards="$index_cards
<p class=\"novel-desc\">${description}</p>"
    fi
    index_cards="$index_cards
<p class=\"novel-meta\">📖 共 ${chapter_count} 章 | 约 ${word_est} 万字</p>
<a class=\"novel-btn\" href=\"${novel_path}\">进入阅读 →</a>
</div>"

    echo "  [${novel_name}] 处理完成：${chapter_count} 个章节"
done

sidebar_json="$sidebar_json}"

# 生成首页 index.md
cat > "$DOCS_DIR/index.md" << HEREDOC
---
layout: home
title: 小说书架
hero:
  name: "📚 小说书架"
  text: "用心写好每一个故事"
  tagline: "在线阅读 · 手机适配 · 深色模式"
---

<div style="max-width: 680px; margin: 40px auto; padding: 0 20px;">

${index_cards}

</div>
HEREDOC

# 生成动态 VitePress 配置
cat > "$DOCS_DIR/.vitepress/config.mts" << CONFIGEOF
import { defineConfig } from 'vitepress'

export default defineConfig({
  base: '/novel-book/',
  lang: 'zh-CN',
  title: '小说书架',
  description: 'lxbeyond 的原创小说合集',

  head: [
    ['meta', { name: 'viewport', content: 'width=device-width, initial-scale=1.0, maximum-scale=3.0' }],
    ['meta', { name: 'apple-mobile-web-app-capable', content: 'yes' }],
    ['meta', { name: 'theme-color', content: '#ffffff' }],
  ],

  themeConfig: {
    nav: [
      { text: '首页', link: '/' },
      ${nav_items}
    ],
    sidebar: ${sidebar_json},
    outline: false,
    aside: false,
    footer: {
      message: '用心写好每一个故事',
      copyright: '© 2024-2026 lxbeyond'
    },
    docFooter: {
      prev: '上一章',
      next: '下一章'
    },
    returnToTopLabel: '回到顶部',
    sidebarMenuLabel: '目录',
    darkModeSwitchLabel: '深色模式',
  }
})
CONFIGEOF

echo "预处理完成：共处理 ${novel_count} 本小说"
