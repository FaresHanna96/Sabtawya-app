package com.sabtawya.sabtawya

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val callerPermissions = arrayOf(
        Manifest.permission.READ_PHONE_STATE,
        Manifest.permission.READ_CALL_LOG,
    )

    private fun hasCallerPermissions() = callerPermissions.all {
        ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sabtawya/caller_id")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // The saved numbers, as {digits: name}; kept by their last
                    // ten digits so 0101…, +20101… and 0020101… all match.
                    "setNumbers" -> {
                        val map = (call.arguments as? Map<*, *>)
                            ?.entries
                            ?.associate {
                                val digits = it.key.toString().filter { c -> c.isDigit() }
                                (if (digits.length <= 10) digits else digits.takeLast(10)) to
                                    it.value.toString()
                            }
                            ?: emptyMap()
                        CallerIdStore.save(this, map)
                        result.success(null)
                    }
                    "clear" -> {
                        CallerIdStore.clear(this)
                        result.success(null)
                    }
                    "isEnabled" ->
                        result.success(CallerIdStore.isEnabled(this) && hasCallerPermissions())
                    "requestPermissions" -> {
                        if (hasCallerPermissions()) {
                            result.success(true)
                        } else {
                            pendingPermissionResult?.success(false)
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(this, callerPermissions, 4701)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4701) {
            pendingPermissionResult?.success(hasCallerPermissions())
            pendingPermissionResult = null
        }
    }
}
