#!/bin/zsh
# DM Re:Vault デプロイスクリプト
set -e

REPO=~/moon
DL=~/Downloads
PUBLIC_URL="https://roaring-sun-va.github.io/moon/"
API_RUNS="https://api.github.com/repos/roaring-sun-va/moon/actions/runs"

version_of() {
  grep -o 'APP_VER="[^"]*"' "$1" 2>/dev/null | head -1 | sed 's/APP_VER="//;s/"$//'
}

public_version() {
  curl -fsSL -H 'Cache-Control: no-cache' "${PUBLIC_URL}?deploy_check=$(date +%s)" 2>/dev/null \
    | grep -o 'APP_VER="[^"]*"' | head -1 | sed 's/APP_VER="//;s/"$//'
}

wait_pages_action() {
  local sha="$1" json action_status conclusion action_url
  echo "⏳ GitHub Pagesの公開処理を確認中…"
  for i in {1..18}; do
    json=$(curl -fsSL "${API_RUNS}?head_sha=${sha}&per_page=5" 2>/dev/null || true)
    if [ -n "$json" ]; then
      read action_status conclusion action_url <<< "$(printf '%s' "$json" | python3 -c '
import json,sys
try:
 d=json.load(sys.stdin); r=(d.get("workflow_runs") or [{}])[0]
 print(r.get("status", ""), r.get("conclusion") or "-", r.get("html_url", ""))
except Exception: print("", "-", "")
')"
      if [ "$action_status" = "completed" ]; then
        if [ "$conclusion" = "success" ]; then
          echo "✅ GitHub Actions: success"
          return 0
        fi
        echo "❌ GitHub Pagesの公開処理が失敗しました（${conclusion}）"
        [ -n "$action_url" ] && echo "   確認・再実行: $action_url"
        echo "   git pushは済んでいますが、公開サイトは更新されていません。"
        return 1
      fi
      printf "   %s（%s/18）\n" "${action_status:-Actions待ち}" "$i"
    else
      printf "   Actions登録待ち（%s/18）\n" "$i"
    fi
    sleep 10
  done
  echo "❌ 3分以内にGitHub Pagesの完了を確認できませんでした。"
  echo "   https://github.com/roaring-sun-va/moon/actions"
  return 1
}

wait_public_version() {
  local want="$1" got
  echo "⏳ 公開URLのバージョンを照合中…"
  for i in {1..12}; do
    got=$(public_version || true)
    if [ "$got" = "$want" ]; then
      echo "✅ 公開URL: APP_VER=\"$got\""
      return 0
    fi
    echo "   現在: ${got:-取得失敗} / 期待: $want（$i/12）"
    sleep 5
  done
  echo "❌ Actionsは成功しましたが、公開URLは APP_VER=\"$want\" に切り替わっていません。"
  return 1
}

SRC=$(ls -t "$DL"/index*.html 2>/dev/null | head -1)
if [ -z "$SRC" ]; then
  echo "❌ $DL に index*.html が見つかりません。先にチャットから index.html を保存してください。"
  exit 1
fi

SRC_VER=$(version_of "$SRC")
if [ -z "$SRC_VER" ]; then
  echo "❌ $SRC から APP_VER を読み取れません。別のHTMLの可能性があるため中止します。"
  exit 1
fi
echo "📦 使用ファイル: $SRC"
echo "🏷  コピー元バージョン: APP_VER=\"$SRC_VER\""

cp "$SRC" "$REPO/index.html"
cd "$REPO"
REPO_VER=$(version_of "$REPO/index.html")
if [ "$REPO_VER" != "$SRC_VER" ]; then
  echo "❌ コピー後の照合に失敗しました（元=$SRC_VER / 配置先=$REPO_VER）"
  exit 1
fi
git add -A
if git diff --cached --quiet; then
  GOT=$(public_version || true)
  if [ "$GOT" = "$SRC_VER" ]; then
    echo "ℹ️ Gitの変更なし。公開先も APP_VER=\"$GOT\" で一致しています。"
    exit 0
  fi
  echo "❌ Gitに変更はありませんが、公開先は APP_VER=\"${GOT:-取得失敗}\" です（期待: $SRC_VER）。"
  echo "   GitHub Actionsから最新のPages処理を再実行してください。"
  echo "   https://github.com/roaring-sun-va/moon/actions"
  exit 1
fi
git commit -m "update $(date +%F_%H%M)"
git push
SHA=$(git rev-parse HEAD)
wait_pages_action "$SHA"
wait_public_version "$SRC_VER"
echo "✅ 反映完了 → $PUBLIC_URL"
echo "   （使った元ファイル: $SRC / APP_VER=\"$SRC_VER\"）"
