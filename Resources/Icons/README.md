# App Icon 占位目录

## 如何替换 App 图标

把准备好的 PNG 文件放到 `../Assets.xcassets/AppIcon.appiconset/` 目录下，覆盖以下文件：

| 文件名           | 尺寸 (像素) | 用途                   |
|-----------------|------------|-----------------------|
| `icon_16.png`   | 16×16      | 小尺寸 (1x)           |
| `icon_32.png`   | 32×32      | 小尺寸 (2x) / 中 (1x) |
| `icon_64.png`   | 64×64      | 中等尺寸 (2x)         |
| `icon_128.png`  | 128×128    | 中等尺寸 (1x)         |
| `icon_256.png`  | 256×256    | 大尺寸 (1x/2x)        |
| `icon_512.png`  | 512×512    | 超大尺寸 (1x/2x)      |

覆盖后重新打包即可：

```bash
cd <项目根目录>
bash scripts/package-app.sh
cp -R .build/ClaudeNotifier.app /Applications/
```

## 菜单栏图标

菜单栏图标使用 SF Symbol `bell.badge.fill`，无需替换。
如需自定义，在 `AppDelegate.swift` 中修改：

```swift
let image = NSImage(systemSymbolName: "bell.badge.fill", ...)
```
