package com.raimonvibe.wonders

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends AudioServiceActivity rather than FlutterActivity so the activity and
 * the media service share one FlutterEngine.
 *
 * Without it audio_service starts a second engine of its own, and the
 * notification ends up driving a SpeechController the app cannot see: play on
 * the lock screen would begin a reading that nothing on screen reflects.
 *
 * It also answers one method channel, for the notification permission Android
 * 13 introduced. That is done here rather than with a permission plugin because
 * the need is a single Android-only call, and the obvious plugin
 * (permission_handler) ships an Android build script that does not compile
 * against this project's Gradle — a whole dependency, and a broken release
 * build, to avoid thirty lines.
 *
 * minSdk is 24, so `checkSelfPermission` and `requestPermissions` are both on
 * the framework and no androidx dependency is needed.
 */
class MainActivity : AudioServiceActivity() {

    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureNotificationPermission" ->
                        ensureNotificationPermission(result)
                    else -> result.notImplemented()
                }
            }
    }

    /** Grants immediately below Android 13, where the permission does not exist. */
    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        // Only one request can be outstanding. Answering a second call rather
        // than replacing `pending` is what keeps the first Dart future from
        // hanging for the life of the app.
        if (pending != null) {
            result.success(false)
            return
        }

        pending = result
        requestPermissions(arrayOf(permission), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending?.success(granted)
        pending = null
    }

    private companion object {
        const val CHANNEL = "wonders/notifications"
        const val REQUEST_CODE = 4711
    }
}
