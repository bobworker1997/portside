# Portside

macOS 選單列小工具，用來切換 Cloud SQL Auth Proxy 連線，並在 Google 驗證過期時重新登入。

## 需求

- macOS 13 以上、Xcode 15 以上（或對應的 Command Line Tools）
- `gcloud` 與 `cloud-sql-proxy`（v2）

## 執行

```shell
swift run                 # 開發時直接跑
./scripts/build-app.sh    # 包成 build/Portside.app
open build/Portside.app
```

也可以用 Xcode 直接開啟 `Package.swift`。

## 運作方式

- 每個連線是一個獨立的 `cloud-sql-proxy '<連線名稱>?port=<port>'` 子進程，可同時開多個。
- 每 5 分鐘執行 `gcloud auth application-default print-access-token` 檢查驗證，也會監看 proxy 的錯誤輸出。
- 驗證過期時暫停所有連線；重新登入成功後自動恢復。
- 結束 app 時會終止所有 proxy。
- 環境與資料庫類型都可以在設定裡新增、改名、刪除。資料庫類型只影響分組和預設 port。
- 設定檔：`~/Library/Application Support/Portside/config.json`

## 注意

- 修改執行中連線的設定，要關掉再開才會生效。
- 找不到 `gcloud` 或 `cloud-sql-proxy` 時，到「設定 › 一般」填寫完整路徑。
