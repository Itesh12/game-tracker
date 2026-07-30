package com.example.game_tracker

import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest

object CloudinaryUploader {
    private const val CLOUD_NAME = "dsuaryuxj"
    private const val API_KEY = "331165958884664"
    private const val API_SECRET = "ZU-t1_zmu6PkbHVP0PyG_2028LM"

    fun uploadFile(file: File, callback: (String?) -> Unit) {
        Thread {
            try {
                val bytes = file.readBytes()
                val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                val timestamp = (System.currentTimeMillis() / 1000).toString()
                val signatureInput = "timestamp=${timestamp}${API_SECRET}"
                val signature = sha1Hex(signatureInput)

                val url = URL("https://api.cloudinary.com/v1_1/$CLOUD_NAME/image/upload")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")

                val encodedBase64 = URLEncoder.encode("data:image/png;base64,$base64", "UTF-8")
                val postData = "file=$encodedBase64&api_key=$API_KEY&timestamp=$timestamp&signature=$signature"
                conn.outputStream.use { it.write(postData.toByteArray(Charsets.UTF_8)) }

                if (conn.responseCode == 200 || conn.responseCode == 201) {
                    val responseText = conn.inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(responseText)
                    val secureUrl = json.optString("secure_url")
                    callback(if (secureUrl.isNotEmpty()) secureUrl else null)
                } else {
                    callback(null)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                callback(null)
            }
        }.start()
    }

    private fun sha1Hex(input: String): String {
        val md = MessageDigest.getInstance("SHA-1")
        val digest = md.digest(input.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}
