package com.starmedia.shell

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Chaquopy 真调用桥（对标催壳）
 *
 * 流程：loadScript 将源码写入 filesDir/py_modules → importlib 加载
 *       call 时 callAttr 调 TVBox 风格函数，返回 JSON 字符串
 *
 * 反射调用 com.chaquo.python.*，无依赖时 isAvailable=false，Dart Fallback。
 */
class PythonBridge(private val appContext: Context) : MethodChannel.MethodCallHandler {

    private val tag = "PythonBridge"
    private val modules = HashMap<String, String>() // safeName -> source

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(ensureStarted())
            "loadScript" -> {
                val module = call.argument<String>("module") ?: ""
                val source = call.argument<String>("source") ?: ""
                if (module.isEmpty() || source.isEmpty()) {
                    result.error("bad_args", "module/source empty", null)
                    return
                }
                val safe = safeName(module)
                modules[safe] = source
                try {
                    if (!ensureStarted()) {
                        result.success(false)
                        return
                    }
                    installModule(safe, source)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(tag, "loadScript", e)
                    result.error("load_failed", e.message, null)
                }
            }
            "call" -> {
                if (!ensureStarted()) {
                    result.success(null)
                    return
                }
                val module = call.argument<String>("module") ?: ""
                val method = call.argument<String>("method") ?: ""
                val argsJson = call.argument<String>("args") ?: "[]"
                try {
                    val safe = safeName(module)
                    if (modules.containsKey(safe)) {
                        installModule(safe, modules[safe]!!)
                    }
                    result.success(invokePython(safe, method, argsJson))
                } catch (e: Exception) {
                    Log.e(tag, "call $module.$method", e)
                    result.error("py_error", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun safeName(module: String) =
        module.replace(Regex("[^a-zA-Z0-9_]"), "_").ifEmpty { "spider" }

    private fun isChaquopyPresent(): Boolean = try {
        Class.forName("com.chaquo.python.Python")
        true
    } catch (_: ClassNotFoundException) {
        false
    }

    private fun ensureStarted(): Boolean {
        if (!isChaquopyPresent()) return false
        return try {
            val pythonCls = Class.forName("com.chaquo.python.Python")
            val started = pythonCls.getMethod("isStarted").invoke(null) as Boolean
            if (!started) {
                val platformCls = Class.forName("com.chaquo.python.android.AndroidPlatform")
                val platform = platformCls
                    .getConstructor(Context::class.java)
                    .newInstance(appContext.applicationContext)
                // Python.start(Platform)
                val start = pythonCls.methods.first {
                    it.name == "start" && it.parameterTypes.size == 1
                }
                start.invoke(null, platform)
            }
            true
        } catch (e: Exception) {
            Log.e(tag, "ensureStarted", e)
            false
        }
    }

    private fun modulesDir(): File {
        val dir = File(appContext.filesDir, "py_modules")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun installModule(safe: String, source: String) {
        val dir = modulesDir()
        File(dir, "$safe.py").writeText(source, Charsets.UTF_8)

        val py = pythonInstance()
        // 保证 path
        val code = """
import sys
p = r'''${dir.absolutePath}'''
if p not in sys.path:
    sys.path.insert(0, p)
""".trimIndent()
        runPythonCode(py, code)

        val importlib = getModule(py, "importlib")
        try {
            val mod = callAttr(importlib, "import_module", safe)
            callAttr(importlib, "reload", mod!!)
        } catch (_: Exception) {
            callAttr(importlib, "import_module", safe)
        }
    }

    private fun invokePython(safe: String, method: String, argsJson: String): String {
        val py = pythonInstance()
        val importlib = getModule(py, "importlib")
        val mod = callAttr(importlib, "import_module", safe)
            ?: throw IllegalStateException("cannot import $safe")

        val jsonArr = JSONArray(argsJson)
        val args = Array(jsonArr.length()) { i -> jsonToJava(jsonArr.get(i)) }

        val ret = callAttr(mod, method, *args)

        // Python json.dumps
        val jsonMod = getModule(py, "json")
        val dumped = callAttr(jsonMod, "dumps", ret)
        return dumped?.toString() ?: "null"
    }

    private fun runPythonCode(py: Any, code: String) {
        val builtins = py.javaClass.getMethod("getBuiltins").invoke(py)
        callAttr(builtins!!, "exec", code)
    }

    private fun jsonToJava(v: Any?): Any? = when (v) {
        null, JSONObject.NULL -> null
        is JSONObject -> {
            val map = LinkedHashMap<String, Any?>()
            val it = v.keys()
            while (it.hasNext()) {
                val k = it.next()
                map[k] = jsonToJava(v.get(k))
            }
            map
        }
        is JSONArray -> {
            val list = ArrayList<Any?>(v.length())
            for (i in 0 until v.length()) list.add(jsonToJava(v.get(i)))
            list
        }
        is Int, is Long, is Double, is Boolean, is String -> v
        is Number -> v
        else -> v.toString()
    }

    private fun pythonInstance(): Any {
        val cls = Class.forName("com.chaquo.python.Python")
        return cls.getMethod("getInstance").invoke(null)!!
    }

    private fun getModule(py: Any, name: String): Any {
        return py.javaClass.getMethod("getModule", String::class.java).invoke(py, name)!!
    }

    /**
     * PyObject.callAttr(String, Object...)
     */
    private fun callAttr(receiver: Any, name: String, vararg args: Any?): Any? {
        val methods = receiver.javaClass.methods.filter { it.name == "callAttr" }
        for (m in methods) {
            try {
                return when {
                    m.parameterTypes.size == 1 -> m.invoke(receiver, name)
                    m.isVarArgs -> {
                        val packed = arrayOfNulls<Any>(args.size)
                        for (i in args.indices) packed[i] = args[i]
                        m.invoke(receiver, name, packed)
                    }
                    m.parameterTypes.size == 2 &&
                        m.parameterTypes[1].isArray -> {
                        val packed = arrayOfNulls<Any>(args.size)
                        for (i in args.indices) packed[i] = args[i]
                        m.invoke(receiver, name, packed)
                    }
                    else -> m.invoke(receiver, name, *args)
                }
            } catch (_: IllegalArgumentException) {
                continue
            } catch (e: java.lang.reflect.InvocationTargetException) {
                throw e.targetException ?: e
            }
        }
        // fallback: get attribute then __call__
        val get = receiver.javaClass.methods.firstOrNull { it.name == "get" && it.parameterTypes.size == 1 }
        val attr = get?.invoke(receiver, name) ?: error("callAttr not found for $name")
        val call = attr.javaClass.methods.firstOrNull { it.name == "call" }
            ?: error("cannot call $name")
        return call.invoke(attr, *args)
    }
}
