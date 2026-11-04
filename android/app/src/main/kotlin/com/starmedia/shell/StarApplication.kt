package com.starmedia.shell

import android.app.Application
import android.util.Log

/**
 * 尽早启动 Chaquopy（若 classpath 中存在）
 */
class StarApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            val pythonCls = Class.forName("com.chaquo.python.Python")
            val started = pythonCls.getMethod("isStarted").invoke(null) as Boolean
            if (!started) {
                val platformCls = Class.forName("com.chaquo.python.android.AndroidPlatform")
                val platform = platformCls
                    .getConstructor(android.content.Context::class.java)
                    .newInstance(this)
                val platformBase = Class.forName("com.chaquo.python.Python\$Platform")
                pythonCls.getMethod("start", platformBase).invoke(null, platform)
                Log.i("StarApplication", "Chaquopy Python started")
            }
        } catch (e: ClassNotFoundException) {
            Log.i("StarApplication", "Chaquopy not present, Python fallback on Dart side")
        } catch (e: Exception) {
            Log.e("StarApplication", "Python start error", e)
        }
    }
}
