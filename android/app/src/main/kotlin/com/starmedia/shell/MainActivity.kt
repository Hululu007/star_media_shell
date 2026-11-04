package com.starmedia.shell

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 多图标切换（对标 BieCuiLe activity-alias 方案）
 *
 * Flutter 侧调用：
 *   MethodChannel('com.starmedia.shell/icon').invokeMethod('setIcon', 'blob_blue')
 *   MethodChannel('com.starmedia.shell/icon').invokeMethod('getIcon')
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.starmedia.shell/icon"

    /** 所有可切换的 alias 后缀（与 AndroidManifest 中 android:name 对应） */
    private val iconAliases = listOf(
        "default_star",
        "blob_blue",
        "blob_mint",
        "blob_coral",
        "painter_cat",
        "painter_penguin",
        "line_minimal",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.starmedia.shell/python")
            .setMethodCallHandler(PythonBridge(applicationContext))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.starmedia.shell/cast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        result.success(
                            android.os.Build.VERSION.SDK_INT >= 26
                        )
                    }
                    "enterPip" -> {
                        if (android.os.Build.VERSION.SDK_INT >= 26) {
                            try {
                                val params = android.app.PictureInPictureParams.Builder().build()
                                val ok = enterPictureInPictureMode(params)
                                result.success(ok)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "cast" -> result.success("unsupported")
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val key = call.arguments as? String
                        if (key == null || !iconAliases.contains(key)) {
                            result.error("INVALID", "Unknown icon key: $key", null)
                            return@setMethodCallHandler
                        }
                        try {
                            setAppIcon(key)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    "getIcon" -> {
                        result.success(getCurrentIconKey())
                    }
                    "listIcons" -> {
                        result.success(iconAliases)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setAppIcon(enabledKey: String) {
        val pm = packageManager
        val pkg = packageName

        for (key in iconAliases) {
            val component = ComponentName(pkg, "$pkg.icon.$key")
            val newState = if (key == enabledKey) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(
                component,
                newState,
                PackageManager.DONT_KILL_APP,
            )
        }

        // 可选：同时禁用主 Activity 上的 LAUNCHER（若 Manifest 里主 Activity 也带了 LAUNCHER）
        // 多数情况下只靠 alias 互斥即可。
    }

    private fun getCurrentIconKey(): String {
        val pm = packageManager
        val pkg = packageName
        for (key in iconAliases) {
            val component = ComponentName(pkg, "$pkg.icon.$key")
            val state = pm.getComponentEnabledSetting(component)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && key == "default_star")
            ) {
                // DEFAULT 时 default_star 在 Manifest 里 enabled=true
                if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                    return key
                }
            }
        }
        return "default_star"
    }
}
