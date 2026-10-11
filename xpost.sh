#!/bin/bash

REPO="/home/toshi-shimoji/share/x-autopost"
BASE_URL="https://oki098972.github.io/x-autopost"

# 引数チェック
if [ "$#" -ne 2 ] && [ "$#" -ne 3 ] && [ "$#" -ne 6 ]; then
    echo "Usage:"
    echo "  $0 push|nopush \"投稿本文\""
    echo "  $0 push|nopush \"投稿本文\" image.png"
    echo "  $0 push|nopush \"投稿本文\" video.mp4"
    echo "  $0 push|nopush \"投稿本文\" image1.png image2.png image3.png image4.png"
    exit 1
fi

PUSH_MODE="$1"

if [ "$PUSH_MODE" != "push" ] && [ "$PUSH_MODE" != "nopush" ]; then
    echo "第1引数は push または nopush を指定してください"
    exit 1
fi

TEXT="$2"
#引数で渡された文字列に"(cr)"があれば改行コードに置き換える
TEXT="${TEXT//(cr)/$'\n'}"

shift 2

MEDIA_FILES=("$@")

# ファイル存在確認
for MEDIA in "${MEDIA_FILES[@]}"; do
    if [ ! -f "$MEDIA" ]; then
        echo "File not found: $MEDIA"
        exit 1
    fi
done

# 形式確認
if [ "${#MEDIA_FILES[@]}" -eq 4 ]; then
    for MEDIA in "${MEDIA_FILES[@]}"; do
        MIME_TYPE=$(file --mime-type -b "$MEDIA")
        if [ "$MIME_TYPE" != "image/png" ]; then
            echo "4枚指定時はPNGのみ使用できます: $MEDIA"
            exit 1
        fi
    done

elif [ "${#MEDIA_FILES[@]}" -eq 1 ]; then
    MIME_TYPE=$(file --mime-type -b "${MEDIA_FILES[0]}")

    if [ "$MIME_TYPE" != "image/png" ] && [ "$MIME_TYPE" != "video/mp4" ]; then
        echo "対応形式は PNG または MP4 です: $MIME_TYPE"
        exit 1
    fi
fi

cd "$REPO" || exit 1

POST_ID=$(date '+%Y%m%d%H%M%S')

MEDIA_NAMES=()

# メディアをコピー
for MEDIA in "${MEDIA_FILES[@]}"; do
    MEDIA_NAME="${POST_ID}_$(basename "$MEDIA")"
    cp "$MEDIA" "$MEDIA_NAME"
    MEDIA_NAMES+=("$MEDIA_NAME")
done

# XMLエスケープ
ESCAPED_TEXT=$(printf '%s' "$TEXT" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g')

DATE=$(date -R)

# 今回のitemを作成
ITEM_FILE=$(mktemp)

cat > "$ITEM_FILE" <<EOF
<item>
<title>X post</title>
<description>${ESCAPED_TEXT}</description>
<pubDate>${DATE}</pubDate>
<guid isPermaLink="false">${POST_ID}</guid>
EOF

# enclosure生成
for i in "${!MEDIA_FILES[@]}"; do
    MIME_TYPE=$(file --mime-type -b "${MEDIA_FILES[$i]}")

    cat >> "$ITEM_FILE" <<EOF
<enclosure url="${BASE_URL}/${MEDIA_NAMES[$i]}" type="${MIME_TYPE}" />
EOF
done

cat >> "$ITEM_FILE" <<EOF
</item>
EOF

# feed.xmlが無ければ新規作成
if [ ! -f feed.xml ]; then

    cat > feed.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
<title>X Auto Post</title>
<link>${BASE_URL}</link>
<description>X Auto Post Feed</description>
EOF

    cat "$ITEM_FILE" >> feed.xml

    cat >> feed.xml <<EOF
</channel>
</rss>
EOF

else

    # 新しいitemを既存itemより前に追加
    {
        sed '/<item>/,$d' feed.xml
        cat "$ITEM_FILE"
        sed -n '/<item>/,$p' feed.xml
    } > feed.xml.tmp

    #mv feed.xml.tmp feed.xml
    cp feed.xml.tmp feed.xml
    rm -f feed.xml.tmp

fi

rm -f "$ITEM_FILE"

#xmlのitemを一意に区別するguidを時刻（秒まで）で生成してる為、同一guidを生成しない事を保証する為２秒空ける
sleep 2

# GitHubへ反映
git add feed.xml "${MEDIA_NAMES[@]}"

git commit -m "X post ${POST_ID}"

# push指定時だけGitHubへ反映
if [ "$PUSH_MODE" = "push" ]; then

    # git push失敗時は3回までリトライ
    for i in 1 2 3; do
        if git push; then
            break
        fi

        if [ "$i" -eq 3 ]; then
            echo "git push failed after 3 attempts"
            exit 1
        fi

        echo "git push failed. Retry in 5 seconds..."
        sleep 5
    done

fi

echo "Posted text: $TEXT"

if [ "${#MEDIA_NAMES[@]}" -gt 0 ]; then
    echo "Media:"
    for MEDIA_NAME in "${MEDIA_NAMES[@]}"; do
        echo "  ${BASE_URL}/${MEDIA_NAME}"
    done
fi


