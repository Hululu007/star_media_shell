# 星辰影音 (Star Media Shell)

## Chaquopy 插件（已配置）

- 版本 **17.2.0**，写入 `android/settings.gradle` + `android/app/build.gradle`
- `StarApplication` + `PythonBridge` 真调用
- 详见 `android/CHAQUOPY.md`

```bash
cd star_media_shell
flutter create . --project-name star_media_shell --platforms=android
# 若 create 覆盖了 gradle，请按 CHAQUOPY.md 恢复 Chaquopy 段
flutter pub get
flutter run
```

## Python / Chaquopy 真调用

- `PythonBridge.kt`：反射调用 Chaquopy，脚本落入 `filesDir/py_modules`
- `StarApplication`：启动时 `Python.start`
- 未集成插件 → Dart Fallback；集成后 → 真执行 TVBox 风格函数
- 配置见 `android/CHAQUOPY.md`

# 星辰影音 (Star Media Shell)

对标 **BieCuiLe（催壳）** 的高颜值多运行时 Flutter 影视壳。

## 源订阅仓库

路径：`源管理 → 仓库` 或 `设置 → 源订阅仓库`

| 能力 | 说明 |
|------|------|
| **添加仓库** | 名称 + URL（http / `demo://repo`） |
| **同步** | 拉取并合并到本地源（按 key 更新） |
| **全部同步** | 一键同步所有订阅 |
| **演示仓库** | FAB 一键加入并同步演示源 |

### 支持的仓库 JSON

**TVBox 风格**
```json
{
  "urls": [
    { "name": "某某源", "url": "https://api.example.com" }
  ]
}
```

**源数组**
```json
[
  { "key": "a", "name": "A源", "api": "https://...", "type": "json" },
  { "key": "b", "name": "Drpy", "api": "drpy://demo", "type": "drpy" }
]
```

**演示**
```
demo://repo
```

## 快速开始

```bash
cd star_media_shell
flutter create . --project-name star_media_shell
flutter pub get
flutter run
```


### 已声明的 pip 包（app/build.gradle）

`requests`、`urllib3`、`certifi`、`charset-normalizer`、`idna`、`beautifulsoup4`、`lxml`、`pycryptodome`

首次 `flutter build`/`run` 会下载并打包进 APK。若 `lxml` 构建失败，可暂时注释该行，仅用 bs4。
