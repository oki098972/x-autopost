#!/bin/bash

# エラーが発生したら即座に停止する設定
set -e

# 1. 設定項目（日付とターゲットブランチ）
TARGET_DATE="2026-10-07"
TARGET_BRANCH="master"

# 2. 確実に指定ブランチ（master）に切り替える
echo "ブランチを ${TARGET_BRANCH} に切り替えています..."
git checkout "$TARGET_BRANCH"

# リモートの最新状態を一度取り込む（コンフリクト防止）
echo "リモートリポジトリの最新状態を同期中..."
git pull origin "$TARGET_BRANCH" --rebase || true

echo "GitHubの記録から、最終更新日が ${TARGET_DATE} のファイルを検索中..."

# 3. リポジトリ内のすべてのファイルをループ処理
git ls-files -z | while mapfile -d '' -t files && ((${#files[@]})); do
    for file in "${files[@]}"; do
        # そのファイルの「最新のコミット日付」を取得
        LAST_COMMIT_DATE=$(git log -1 --format="%cd" --date=format:"%Y-%m-%d" -- "$file" 2>/dev/null || true)

        # 最終更新日が、指定したターゲット日付と一致するか判定
        if [ "$LAST_COMMIT_DATE" = "$TARGET_DATE" ]; then
            echo "削除対象 (最終更新日が一致): $file"
            git rm "$file"
        fi
    done
done

# 4. 変更をコミットしてGitHubのmasterにプッシュ
if ! git diff --cached --quiet; then
    echo "該当ファイルをコミット中..."
    git commit -m "Automation: Delete files whose last update was ${TARGET_DATE}"
    
    echo "GitHubの ${TARGET_BRANCH} ブランチへ反映中..."
    git push origin "$TARGET_BRANCH"
    
    echo "該当ファイルを削除し、GitHubの ${TARGET_BRANCH} へ反映しました。"
else
    echo "指定された日付（${TARGET_DATE}）が最終更新日のファイルは見つかりませんでした。"
fi
