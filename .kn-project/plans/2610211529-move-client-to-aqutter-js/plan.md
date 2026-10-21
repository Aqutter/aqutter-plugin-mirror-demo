<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2610211529 - move-client-to-aqutter-js
- Created: 2026-10-21
- Branch: feature/2610211529-move-client-to-aqutter-js
- Issue: Aqutter/aqutter-plugin-mirror-demo#1
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
讓 `Aqutter/aqutter-plugin-mirror-demo` 的 client 開發依賴改用 `github:Aqutter/aqutter-js#<sha>`，舊的 `&path:/client` 語法不再存在，並重產 `pnpm-lock.yaml`。

## Architecture
`package.json` 的 `devDependencies["@aqutter/aqutter"]` 只在開發時提供型別與 `pnpm typecheck`；`peerDependencies` 維持 `*`（可選）。依賴來源改位置，程式碼不變。

## Cross-Repo Scope
- **共用計畫 ID**: `2610211529-move-client-to-aqutter-js`　**共用分支名**: `feature/2610211529-move-client-to-aqutter-js`
- **參與 repo 與職責**（一 repo 一 issue，尚未建立者寫 `待建立`）:
  - `Aqutter/aqutter`（契約正本；本計畫）— manifest `client.spec` 改新位置、`manifest-check` 改檢查、文件與治理檔改寫、最後移除 `client/`。issue: 待建立
  - `Aqutter/aqutter-js`（新 repo）— 承接 `client/` 內容與 tag `0.0.0`；建立後另有自己的計畫與 issue。issue: 待建立
  - `Aqutter/aqutter-cli`（消費方）— 辨識新格式、`upgrade` 改寫、`plugin create` 與範本、內建 manifest 快照。issue: 待建立
  - `Aqutter/aqutter-nuxt-app`（下游）— `package.json` 的 client 依賴與 lock。issue: 待建立
  - `Aqutter/aqutter-plugin-battery`、`aqutter-plugin-haptics`、`aqutter-plugin-mirror-demo`、`aqutter-plugin-google-maps`（下游，各自一份計畫）— `package.json` 的 client 依賴與 lock。issue: 待建立
- **執行順序相依**: ① 建立 `aqutter-js` 並匯入內容、打 tag → ② `aqutter`（取得 aqutter-js 的 sha 後改 manifest、文件，並移除 `client/`）合併 → ③ `aqutter-cli`（從合併後的 manifest 同步快照）→ ④ `aqutter-nuxt-app` 與四個 plugin（用新 CLI 的 `upgrade` 或手改依賴，重產 lock）。契約提供方先、消費方後。
- **範圍外**: 不改 npm 套件名；不新增 npm 發佈；bun 驗證；跨 repo CI 比對。

- **本計畫所屬 repo**: `Aqutter/aqutter`

- **本計畫所屬 repo**: `Aqutter/aqutter-plugin-mirror-demo`

## Contract / 介面契約
- **契約正本 repo**: `Aqutter/aqutter`　**修訂號**: `rev 1`　**狀態**: `凍結（核准日 2026-10-21）`

### 1. aqutter-js 套件
| 項目 | 值 |
|---|---|
| repo | `Aqutter/aqutter-js`（公開） |
| 內容 | 原 `Aqutter/aqutter` 的 `client/` 目錄內容，放在 repo 根目錄（`package.json`、`src/`、`test/`、`test-types/`、`tsconfig.json`、`README.md`、`pnpm-workspace.yaml`、`pnpm-lock.yaml`） |
| npm 套件名 | `@aqutter/aqutter`（不改名） |
| `exports` | 不變：`.` → `./src/index.ts`、`./contract` → `./src/contract/index.ts`、`./native` → `./src/nativeview/register.ts` |
| `files` | 不變：`src`、`README.md`（以 TypeScript 原始碼發佈，由使用端打包器編譯） |
| 版本標記 | 第一個 commit 打 tag `0.0.0`（開發階段沿用，會隨 `main` 移動） |
| 歷史 | 不保留；新 repo 第一個 commit 為匯入當下的 `client/` 內容 |

### 2. 安裝字串（client 依賴）
| 項目 | 值 |
|---|---|
| 格式 | `github:Aqutter/aqutter-js#<ref>`，不含任何 `&path:` |
| manifest `client.spec` | `ref` 為 40 位 commit sha |
| 手動／plugin 範本 | `ref` 可為 tag（如 `0.0.0`）或 sha |
| 支援的套件管理器 | npm、pnpm、yarn（repo 根目錄安裝，同 `github:Aqutter/aqutter-cli#<ref>`）；bun 尚未驗證 |
| 舊格式 | `github:Aqutter/aqutter#…&path:/client` **不再支援**，不做相容處理（開發階段破壞式移動） |

### 3. manifest（契約 rev 1 的結構不變）
| 項目 | 值 |
|---|---|
| 欄位 | `releases.<版本>.client.spec`（非空字串）；schema 不動 |
| `0.0.0` 的 `client.spec` | 原地改為 `github:Aqutter/aqutter-js#<aqutter-js 初始 commit 的 sha>`（使用者決定原地修改，不新增版本） |
| CI 檢查 | `manifest-check` 驗證 `client.spec` 符合上述格式，且 `Aqutter/aqutter-js` 上存在該 commit |
| `shell`、`core`、`flutter`、`dart`、`cli` | 不變 |

### 4. 錯誤與行為
| 情境 | 行為 |
|---|---|
| 專案的 `@aqutter/aqutter` 不是 `github:Aqutter/aqutter-js#…` 形態 | `aqutter doctor` 與 `aqutter upgrade` 不處理該依賴（視為使用者自管） |
| 專案的 `@aqutter/aqutter` 是 `github:Aqutter/aqutter-js#…` 但與 manifest 不同 | `doctor` 警告；`upgrade` 改寫為 manifest 的 `client.spec` |
| `aqutter plugin create` 取 client ref | 由 manifest `client.spec` 取 `#` 之後整段；`--shell-ref` 明給時沿用 |

### 5. 相容性
- 不保留舊語法的任何相容層；以 commit sha 鎖定舊語法的既有專案仍能安裝（舊 commit 仍在 `Aqutter/aqutter` 的歷史中），但框架不再支援。
- client 與 shell／aqutter_core 的跨語言成對規則（handler／事件名稱、鏡像協定）不變，只是分屬兩個 repo；同步靠 `AGENTS.md` 紅線與 manifest 的版本對應。

### 6. 變更紀錄
- _(尚無)_

## Impact Files
- `package.json:29`（`devDependencies["@aqutter/aqutter"]`）— 改為 `github:Aqutter/aqutter-js#ac7c23b6f8030d97dafa2c798ceb97a90382f6bf`。
- `pnpm-lock.yaml:12-20` — 重新產生（依賴指向 aqutter-js）。
- `AGENTS.md` (new)、`.kn-project/project.md` (new) — 初始化治理結構（使用者選擇）。

## Open Questions / 待確認事項
無（已全部確認，見 Key Decisions）。

## Manual Follow-ups / 人工收尾事項
- 無

## Key Decisions
- **[Phase 0]** 整合主幹 `main`；milestone 不指定，base 為 `main`；初始化治理結構（不含 wiki）與一張 issue、一個 PR（使用者選擇）。
- **[契約]** rev 1 凍結（核准日 2026-10-21），正本 `Aqutter/aqutter`。
- **[破壞式移動]** 開發階段不考慮既有程式，不留舊語法相容（使用者指示 2026-10-21）。
- **[ref]** 以 aqutter-js 的 commit sha 固定（與 manifest 相同），不用會移動的 tag。
- **[完成後]** commit + 開 PR（併回 `main`），由使用者合併。

## Git Completion Policy
- PR 以 `--base main` 顯式指定；commit 與 PR body 含 `Closes #N`。

## References
- `Aqutter/aqutter#7`、`Aqutter/aqutter-js`
