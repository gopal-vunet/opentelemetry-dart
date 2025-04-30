package com.example.opentelemetry

import android.app.Application
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity.CONNECTIVITY_SERVICE
import io.flutter.embedding.android.FlutterActivity.TELEPHONY_SERVICE
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** OpentelemetryPlugin */
class OpentelemetryPlugin: FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel
    private val TAG = "OpentelemetryPlugin"

    private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine: ")
        this.flutterPluginBinding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "opentelemetry")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "onMethodCall: ${call.method} ${call.arguments}")
        when (call.method) {
            "getSessionId" -> {
                result.success(OtelUtils.rum?.rumSessionId)
            }
            "getDeviceInfo" -> {
                Log.d(TAG, "onMethodCall-getDeviceInfo: ${getDeviceInfo()}")
                result.success(getDeviceInfo())
            }
            "initialise" -> {
                try{
                    OtelUtils(
                        flutterPluginBinding.applicationContext as Application,
                        logsIngestUrl = call.argument<String?>("logsIngestUrl") ?: "",
                        spansIngestUrl =  call.argument<String?>("tracesIngestUrl") ?: "",
                        appName = call.argument<String?>("appName") ?: "",
                        appType = call.argument<String?>("appType") ?: "",
                    ).initRum()

                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "Error initializing Opentelemetry", e)
                    result.error("initialise_error", "Error initializing Opentelemetry", e)
                }
            }
            else -> {
              result.notImplemented()
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun getDeviceInfo(): Map<String, String> {
        val telephonyManager = flutterPluginBinding.applicationContext.getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        val connectivityManager = flutterPluginBinding.applicationContext.getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager

        val networkInfo = mutableMapOf(
            "device.manufacturer" to Build.MANUFACTURER,
            "device.model.identifier" to Build.MODEL,
            "device.model.name" to Build.MODEL,
            "os.description" to "Android Version ${Build.VERSION.RELEASE} (Build ${Build.DISPLAY} API level ${Build.VERSION.SDK_INT})",
            "os.name" to "Android",
            "os.type" to "linux",
            "os.version" to Build.VERSION.RELEASE,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            networkInfo["os.security.patch"] = Build.VERSION.SECURITY_PATCH
        }

        try {
            // Get carrier information
            networkInfo["network.carrier.icc"] = telephonyManager.simCountryIso ?: "unknown"
            networkInfo["network.carrier.mcc"] = telephonyManager.simOperator?.substring(0, 3) ?: "unknown"
            networkInfo["network.carrier.mnc"] = telephonyManager.simOperator?.substring(3) ?: "unknown"
            networkInfo["network.carrier.name"] = telephonyManager.simOperatorName ?: "unknown"

            // Get connection type
            val connectionType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val activeNetwork = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
                when {
                    capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "wifi"
                    capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "cellular"
                    else -> "unknown"
                }
            } else {
                @Suppress("DEPRECATION")
                when (connectivityManager.activeNetworkInfo?.type) {
                    ConnectivityManager.TYPE_WIFI -> "wifi"
                    ConnectivityManager.TYPE_MOBILE -> "cellular"
                    else -> "unknown"
                }
            }

            networkInfo["network.connection.type"] = connectionType

        } catch (e: SecurityException) {
            // Handle permission not granted
            Log.e(TAG, "Missing permissions for network info", e)
        }

        try {
            val pm = flutterPluginBinding.applicationContext.packageManager
            val pInfo = pm.getPackageInfo(flutterPluginBinding.applicationContext.packageName, 0)

            val versionName = pInfo.versionName
            val versionCode =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    pInfo.longVersionCode.toInt()
                } else {
                    pInfo.versionCode
                }

            networkInfo["app.version.name"] = versionName
            networkInfo["app.version.code"] = versionCode.toString()

        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
        }

        return networkInfo
    }
}
