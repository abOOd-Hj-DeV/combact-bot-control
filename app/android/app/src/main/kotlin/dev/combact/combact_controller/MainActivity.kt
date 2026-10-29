package dev.combact.combact_controller

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "combact/link"
    private var cm: ConnectivityManager? = null
    private var wifiCallback: ConnectivityManager.NetworkCallback? = null
    private var bound = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Keep the screen on while driving — a lock screen mid-match is a DQ.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bindWifi" -> { bindWifi(); result.success(bound) }
                    "unbind" -> { unbind(); result.success(true) }
                    else -> result.notImplemented()
                }
            }
    }

    /// The robot's AP has no internet, so Android prefers mobile data and
    /// drops our UDP. requestNetwork + bindProcessToNetwork forces all app
    /// sockets onto the WiFi interface.
    private fun bindWifi() {
        val mgr = cm ?: return
        if (bound) return
        val req = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: android.net.Network) {
                bound = mgr.bindProcessToNetwork(network)
            }
            override fun onLost(network: android.net.Network) {
                bound = false
            }
        }
        wifiCallback = cb
        mgr.requestNetwork(req, cb)
    }

    private fun unbind() {
        val mgr = cm ?: return
        wifiCallback?.let { runCatching { mgr.unregisterNetworkCallback(it) } }
        wifiCallback = null
        if (bound) mgr.bindProcessToNetwork(null)
        bound = false
    }

    override fun onDestroy() {
        unbind()
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onDestroy()
    }
}
