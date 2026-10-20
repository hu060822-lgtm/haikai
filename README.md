# HAIKAI

PS1 畫風的蒸氣龐克恐怖搜打撤遊戲（計畫代號 sodache）。引擎：Godot 4.3。

## 怎麼打開

1. 下載 [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)（標準版，不需要 .NET）。
2. 打開 Godot，按「匯入」，選這個資料夾裡的 `project.godot`。
3. 按右上角的 ▶（或 F5）開始玩。

## 操作

| 按鍵 | 動作 |
|---|---|
| WASD | 移動 |
| 滑鼠 | 看 |
| Shift | 衝刺（消耗體力） |
| Ctrl / C | 蹲下（可以爬進管道） |
| 空白鍵 | 跳；在梯子上按會跳離梯子 |
| W / S（貼著梯子） | 爬上 / 爬下 |
| E | 撿起物品、互動（拉桿、櫃子） |
| G | 丟下最後撿的物品 |
| F | 開關提燈 |
| 左鍵 | 使用武器（撬棍 / 彈弓） |
| Q | 使用強化道具（腎上腺素針） |
| M | 麥克風開 / 靜音（多人時） |
| 左鍵（自己出局後） | 切換觀看的隊友 |
| Esc | 放開滑鼠（點畫面再抓回來） |

## 多人連線（階段 2，最多 4 人）

1. 一個人當主機：在倉庫畫面按「**建立房間**」。
2. 其他人在「加入房間」左邊的框輸入主機的 IP，按「**加入房間**」。
   - 同一個 Wi-Fi / 區網：用主機電腦的區網 IP（例如 `192.168.x.x`）。
   - 不同地方：主機要在路由器開 **UDP 24500** 埠轉發，再給朋友外網 IP；或用 Radmin VPN / ZeroTier / Tailscale 這類虛擬區網軟體，用它給的 IP。
3. 人到齊後主機按「開始」，全員一起進場。

- 每個人帶自己倉庫的道具進場，撤離時各自結算自己背包的東西。
- 物品是共用的：誰先撿到就是誰的。隊友死掉時背包會散落在地上，可以幫他撿回來。
- 任何人拉下鍋爐拉桿，全隊的升降梯都會通電，巨像也會為所有人醒過來。
- **近距離語音**：麥克風會自動開，只有附近的隊友聽得到你，而且**附近的怪物也聽得到**。按 M 靜音。死掉的人說話活人聽不到。
- 自己撤離或死掉後可以看隊友的視角，點左鍵切換；所有人都結束後一起看結算，回到房間可以再開一局。

## 一局怎麼玩

1. **倉庫**：用錢買要帶進場的道具（撬棍、彈弓、腎上腺素針、彈簧鞋）。死掉會全部失去，活著撤離就能帶回來。
2. **搜刮**：黑暗鍋爐工廠裡每局隨機放 14 到 18 件物品（從 30 種裡抽）。上鎖的櫃子要用撬棍撬開，裡面東西比較好。背越重走越慢。
3. **鍋爐巨像**：兩層樓高的蒸氣機械，被抓到就死。
   - 它聽得到腳步聲、落地聲、吵鬧的物品；衝刺最吵，蹲著走最安靜。
   - 開著提燈它在 26 公尺外就看得到你，關燈只剩 8 公尺。
   - 它進不了通風管道、窄門小房間，也上不了高架走道和管線。
   - 每 40 秒左右它必須排氣 5 秒，這時它看不見也聽不到，碰到也不會死。
4. **撤離**：升降梯要先到北邊**重啟主鍋爐**才有電，但拉下拉桿會吵醒整座工廠，巨像會直接衝過去而且變快。站在升降梯裡 4 秒就撤離成功。
5. **時間限制**：12 分鐘後鍋爐爆炸，還在裡面就死了。

物品標籤：**易碎**（從高處摔下來會掉價）、**吵鬧**（拿著會一直發出聲音）。湊齊一雙襪子有額外獎勵。

## 專案結構

```
scenes/main.tscn            進入點
scripts/main.gd             選單流程、低解析 SubViewport、後製、HUD、觀戰
scripts/net/session.gd      連線（主機 / 加入 / 房間名單 / 開局與結束）
scripts/net/run.gd          一局的共用世界：生成玩家、怪物、物品，處理撿取與互動請求
scripts/net/voice_chat.gd   近距離語音
scripts/player.gd           第一人稱玩家（移動、蹲、體力、背包）
scripts/boiler_factory.gd   鍋爐工廠場景（用程式碼生成，含導航網格）
scripts/monsters/           怪物（boiler_colossus.gd = 鍋爐巨像）
scripts/loot_item.gd / loot_table.gd  物品與掉落表
scripts/gear.gd / game_state.gd       進場道具、金錢與存檔
scripts/game_noise.gd       聲音系統（怪物靠它聽到玩家）
scripts/extraction_zone.gd / boiler_lever.gd / locker.gd / ladder.gd  場景互動物件
scripts/hud.gd / ui/        介面、倉庫畫面、結算畫面
shaders/ps1.gdshader        PS1 表面著色器
shaders/ps1_post.gdshader   全畫面後製
textures/                   由 tools/gen_textures.py 產生的 64×64 貼圖
sounds/                     由 tools/gen_sounds.py 合成的低取樣率音效
tests/smoke_test.gd         單人自動測試
tests/net_test.gd           兩個程式互連的多人測試（用 tests/run_net_test.sh 跑）
```

## 測試

```
godot --headless --path . --script res://tests/smoke_test.gd
tests/run_net_test.sh godot
```

想在同一台電腦試多人：開兩個遊戲視窗（Godot 編輯器「除錯 → 執行多個實例」選 2），一個建立房間，另一個用 `127.0.0.1` 加入。

設計文件在專案資料夾的 `design/` 裡。
