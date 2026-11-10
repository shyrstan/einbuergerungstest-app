package de.einbtest.app

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Play Integrity token for server-side verification (see lib/services/integrity.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/integrity").setMethodCallHandler { call, result ->
            if (call.method != "token") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val nonce = call.argument<String>("nonce")
            if (nonce.isNullOrEmpty()) {
                result.error("args", "nonce missing", null)
                return@setMethodCallHandler
            }
            val builder = IntegrityTokenRequest.builder().setNonce(nonce)
            call.argument<String>("cloudProject")?.toLongOrNull()?.let { builder.setCloudProjectNumber(it) }
            IntegrityManagerFactory.create(applicationContext)
                .requestIntegrityToken(builder.build())
                .addOnSuccessListener { result.success(it.token()) }
                .addOnFailureListener { result.error("integrity", it.message, null) }
        }
    }
}
