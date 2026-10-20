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
| 空白鍵 | 跳 |
| E | 撿起物品 |
| G | 丟下最後撿的物品 |
| F | 開關提燈 |
| Esc | 放開滑鼠（點畫面再抓回來） |

## 目前內容（階段 0）

- 鍋爐工廠的灰盒測試場景：中央鍋爐、兩側高架走道、可以在上面走的大管線、只能蹲著爬的通風管道
- PS1 畫面：240p 低解析渲染、頂點抖動、仿射貼圖扭曲、色彩量化與抖色、霧
- 搜刮：每局隨機 9 件物品，背越重走越慢（上限 30kg）
- 撤離：站在綠燈升降梯裡 4 秒，結算後自動重開一局

## 專案結構

```
scenes/main.tscn            進入點
scripts/main.gd             低解析 SubViewport、後製、HUD 組裝
scripts/player.gd           第一人稱玩家（移動、蹲、體力、背包）
scripts/boiler_factory_test.gd  鍋爐工廠灰盒場景（用程式碼生成）
scripts/loot_item.gd / loot_table.gd  物品與掉落表
scripts/extraction_zone.gd  撤離點
scripts/hud.gd              介面
shaders/ps1.gdshader        PS1 表面著色器
shaders/ps1_post.gdshader   全畫面後製
textures/                   由 tools/gen_textures.py 產生的 64×64 貼圖
tests/smoke_test.gd         自動測試
```

## 測試

```
godot --headless --path . --script res://tests/smoke_test.gd
```

設計文件在專案資料夾的 `design/` 裡。
