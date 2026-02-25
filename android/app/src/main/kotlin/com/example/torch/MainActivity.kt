package com.example.torch

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.torch/foreground"
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraId = cameraManager?.cameraIdList?.firstOrNull {
            cameraManager?.getCameraCharacteristics(it)
                ?.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "setTorch" -> {
                    val isOn = call.argument<Boolean>("isOn") ?: false
                    try {
                        cameraId?.let { cameraManager?.setTorchMode(it, isOn) }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("TORCH_ERROR", e.message, null)
                    }
                }
                "startForeground" -> {
                    val isOn = call.argument<Boolean>("isOn") ?: false
                    try {
                        cameraId?.let { cameraManager?.setTorchMode(it, false) }
                    } catch (e: Exception) {}
                    TorchForegroundService.start(this, isOn)
                    result.success(null)
                }
                "stopForeground" -> {
                    TorchForegroundService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        TorchForegroundService.flutterChannel = channel
    }
}
