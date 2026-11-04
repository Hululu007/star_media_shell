# Chaquopy 已写入工程

版本：**17.2.0**（与 AGP 7.3–9.5、minSdk 24+ 兼容）

## 已改文件

| 文件 | 内容 |
|------|------|
| `settings.gradle` | `id "com.chaquo.python" version "17.2.0" apply false` |
| `app/build.gradle` | `id "com.chaquo.python"` + `python { version "3.11" }` + `abiFilters` + `minSdk max(flutter, 24)` |
| `app/.../AndroidManifest.xml` | `android:name=".StarApplication"` |
| `StarApplication.kt` | 启动 `Python.start` |
| `PythonBridge.kt` | 真调用 / 反射 |

## 使用步骤

在工程根目录（若尚未生成完整 Android 工程）：

```bash
cd star_media_shell
flutter create . --project-name star_media_shell --platforms=android
```

**注意：** `flutter create` 可能会覆盖 `android/` 下部分文件。若被覆盖：

1. 保留本仓库的 `settings.gradle`、`app/build.gradle`、`AndroidManifest.xml`、`kotlin/...`  
2. 或把其中的 Chaquopy 段重新合并进 Flutter 生成文件  

然后：

```bash
flutter pub get
flutter run
```

设置页应显示 **「Chaquopy 已就绪（真调用）」**（需成功编译进包）。

长按首页源图标 → **Python演示源**，规则由真 Python 执行。

## pip 包
### 已声明的 pip 包（app/build.gradle）

`requests`、`urllib3`、`certifi`、`charset-normalizer`、`idna`、`beautifulsoup4`、`lxml`、`pycryptodome`

首次 `flutter build`/`run` 会下载并打包进 APK。若 `lxml` 构建失败，可暂时注释该行，仅用 bs4。

## 可选 pip 包（补充）

编辑 `app/build.gradle`：

```gradle
python {
    version "3.11"
    pip {
        install "requests"
    }
}
```

## 体积

加入 Chaquopy 后 APK 明显变大。可按需减少 `abiFilters`（只留 `arm64-v8a` 出正式包）。

## 故障排查

| 现象 | 处理 |
|------|------|
| 插件找不到 | 确认 `settings.gradle` 的 `pluginManagement.repositories` 含 `mavenCentral()` |
| minSdk 报错 | 已用 `Math.max(flutter.minSdkVersion, 24)` |
| 仍显示 Fallback | 清理重建：`flutter clean && flutter run`；看 Logcat `StarApplication` / `PythonBridge` |
