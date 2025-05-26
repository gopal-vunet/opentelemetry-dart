package com.example.opentelemetry

import android.app.Activity
import android.app.Application
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.flutter.plugin.common.MethodChannel
import io.opentelemetry.android.BuildConfig
import io.opentelemetry.android.OpenTelemetryRum
import io.opentelemetry.android.OpenTelemetryRumBuilder
import io.opentelemetry.android.config.OtelRumConfig
import io.opentelemetry.android.features.diskbuffering.DiskBufferingConfiguration
import io.opentelemetry.api.common.AttributeKey
import io.opentelemetry.api.common.AttributeKey.stringKey
import io.opentelemetry.api.common.Attributes
import io.opentelemetry.exporter.otlp.http.logs.OtlpHttpLogRecordExporter
import io.opentelemetry.exporter.otlp.http.trace.OtlpHttpSpanExporter
import io.opentelemetry.sdk.common.CompletableResultCode
import io.opentelemetry.sdk.logs.LogRecordProcessor
import io.opentelemetry.sdk.logs.ReadWriteLogRecord
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager

class OtelUtils(
    private val context: Application,
    private val spansIngestUrl: String,
    private val logsIngestUrl: String,
    private val appName : String,
    private val appType : String,
    private val buildType : String,
    private val apiKey : String,
) {

    companion object {
        // Global OpenTelemetryRum Instance
        var rum: OpenTelemetryRum? = null
    }

    private fun getAppVersionName(): String {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            return packageInfo.versionName.toString()
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            "Unknown"
        }
    }

    private fun getAppVersionCode(): Long {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            }
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            -1
        }
    }

    private val TAG = "OtelUtils"

    fun initRum() {
        Log.i(TAG, "Initializing the opentelemetry-android-agent")
        val diskBufferingConfig =
            DiskBufferingConfiguration.builder()
                .setEnabled(true)
                .setMaxCacheSize(10_000_000)
                .build()

        val appVersionName = getAppVersionName()
        val versionCode = getAppVersionCode().toString()
        Log.d(TAG, "onCreate: appVersionName=$appVersionName versionCode=$versionCode")
        val config =
            OtelRumConfig()
                .setGlobalAttributes(
                    Attributes.builder().apply {
                        put(AttributeKey.stringKey("app.version.name"), appVersionName)
                        put(AttributeKey.stringKey("app.name"), appName)
                        put(AttributeKey.stringKey("app.version.code"), versionCode)
                        put(AttributeKey.stringKey("android.type"), appType)
                        put(AttributeKey.stringKey("build.type"), buildType)
                        put(AttributeKey.stringKey("device.manufacturer"), Build.MANUFACTURER)
                        put(AttributeKey.stringKey("device.model.identifier"), Build.MODEL)
                        put(AttributeKey.stringKey("device.model.name"), Build.MODEL)
                        put(
                            AttributeKey.stringKey("os.description"),
                            "Android Version ${Build.VERSION.RELEASE} (Build ${Build.DISPLAY} API level ${Build.VERSION.SDK_INT})"
                        )
                        put(AttributeKey.stringKey("os.name"), "Android")
                        put(AttributeKey.stringKey("os.type"), "linux")
                        put(AttributeKey.stringKey("os.version"), Build.VERSION.RELEASE)
                        put(
                            AttributeKey.stringKey("os.security.patch"),
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Build.VERSION.SECURITY_PATCH else "unknown"
                        )
                    }.build()
                )


        val sessionAwareLogProcessor = SessionAwareLogProcessor(
            sessionIdProvider = { rum?.rumSessionId },
            routeProvider = {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                flutterPrefs.getString("flutter.currentWidget", "unknown") ?: "unknown"
            },
            customAttributesProvider = {

                val attributesBuilder = Attributes.builder()

                OpentelemetryPlugin.channel.invokeMethod("getCustomAttributes", null, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (result is Map<*, *>) {
                            for ((key, value) in result) {
                                if (key is String && value is String) {
                                    attributesBuilder.put(stringKey(key), value)
                                }
                            }
                        }
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e(TAG, "Error from Dart: $errorMessage")
                    }

                    override fun notImplemented() {
                        Log.e(TAG, "Dart method not implemented")
                    }
                })


                attributesBuilder.build()
            },
        )

        val trustAllCerts = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        }

        val sslContext = SSLContext.getInstance("TLS").apply {
            init(null, arrayOf(trustAllCerts), SecureRandom())
        }

        val otelRumBuilder: OpenTelemetryRumBuilder =
            OpenTelemetryRum.builder(context, config)
                .addSpanExporterCustomizer {
                    OtlpHttpSpanExporter.builder()
                        .setEndpoint(spansIngestUrl)
                        .setSslContext(sslContext, trustAllCerts)
                        .setHeaders {
                            mapOf("X-API-Key" to apiKey)
                        }
                        .build()
                }
                .addLogRecordExporterCustomizer {
                    OtlpHttpLogRecordExporter.builder()
                        .setSslContext(sslContext, trustAllCerts)
                        .setEndpoint(logsIngestUrl)
                        .build()
                }
                .addLoggerProviderCustomizer { sdkLoggerProviderBuilder, _ ->
                    sdkLoggerProviderBuilder.addLogRecordProcessor(sessionAwareLogProcessor)
                }

        try {
            rum = otelRumBuilder.build()
            Log.d(TAG, "RUM session started: " + rum!!.rumSessionId)
            val observer = AppLifeCycleListener()
            ProcessLifecycleOwner.get().lifecycle.addObserver(observer)
        } catch (e: Exception) {
            Log.e(TAG, "Oh no!", e)
        }
    }
}




class SessionAwareLogProcessor(
    private val sessionIdProvider: () -> String?,
    private val routeProvider: () -> String?,
    private val customAttributesProvider: () -> Attributes
) : LogRecordProcessor {

    override fun onEmit(context: io.opentelemetry.context.Context, logRecord: ReadWriteLogRecord){
        // Add session ID to the log record's attributes
        val currentAttributes = logRecord.toLogRecordData().attributes
        val updatedAttributes = Attributes.builder()
            .putAll(customAttributesProvider())
            .putAll(currentAttributes)
            .put(stringKey("session.id"), sessionIdProvider().toString())
            .put(stringKey("screen.name"), routeProvider().toString() )
            .build()

        logRecord.setAllAttributes(updatedAttributes)
    }

    override fun shutdown(): CompletableResultCode {
        return CompletableResultCode.ofSuccess()
    }

    override fun forceFlush(): CompletableResultCode {
        return CompletableResultCode.ofSuccess()
    }
}


class AppLifeCycleListener : DefaultLifecycleObserver {
    private val TAG = "AppLifeCycleListener"

    override fun onStart(owner: LifecycleOwner) {
        Log.d(TAG, "AppForeground")
        if(OtelUtils.rum != null){
            val tracer = OtelUtils.rum!!.openTelemetry.tracerProvider.tracerBuilder("io.opentelementry.applifecycle").build()
            val span = tracer.spanBuilder("AppForeground").startSpan()
            span.end()
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        Log.d(TAG, "AppBackground")
        if(OtelUtils.rum != null){
            val tracer = OtelUtils.rum!!.openTelemetry.tracerProvider.tracerBuilder("io.opentelementry.applifecycle").build()
            val span = tracer.spanBuilder("AppBackground").startSpan()
            span.end()
        }
    }

}