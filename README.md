# Portside

macOS 選單列小工具，用來切換 Cloud SQL Auth Proxy 連線，並在 Google 驗證過期時重新登入。

## 安裝

1. 到這個 repo 的 Releases 頁面下載最新的 `Portside.zip`。
2. 解壓縮後把 `Portside.app` 拖到「應用程式」資料夾。
3. 第一次開啟時 macOS 會擋下來，因為這個 app 沒有經過 Apple 公證。到「系統設定 › 隱私權與安全性」，在下方找到 Portside 的提示並按「仍要打開」。同一個版本只需要做一次。

啟動後不會有視窗，圖示在螢幕右上角的選單列。

另外需要先安裝 `gcloud` 與 `cloud-sql-proxy`（v2），安裝方式請參考 Google Cloud 官方文件。

目前發佈的版本只支援 Apple Silicon 的 Mac。

## 更新到新版

Portside 不會自動更新，請到 Releases 頁面查看是否有新版本，各版本的修改內容請見 [CHANGELOG.zh-TW.md](CHANGELOG.zh-TW.md)。

1. 從選單列結束 Portside。結束時會一併關閉所有連線。
2. 下載新版的 `Portside.zip` 並解壓縮。
3. 把 `Portside.app` 拖到「應用程式」資料夾，出現提示時選「取代」。
4. 開啟新版。新下載的版本第一次開啟時 macOS 可能會再擋一次，照「安裝」第 3 步到「系統設定 › 隱私權與安全性」按「仍要打開」即可。

更新不會清除設定。設定存在 `~/Library/Application Support/Portside/config.json`，不在 app 裡面，換掉 app 不會動到它。想保險的話，更新前可以先備份這個檔案。

## 從原始碼編譯

### 需求

- macOS 13 以上、Xcode 15 以上（或對應的 Command Line Tools）
- `gcloud` 與 `cloud-sql-proxy`（v2）

### 執行

```shell
swift run                 # 開發時直接跑
./scripts/build-app.sh    # 包成 build/Portside.app
open build/Portside.app
```

也可以用 Xcode 直接開啟 `Package.swift`。

## 發佈新版本

```shell
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions 會自動編譯並建立 Release。

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
