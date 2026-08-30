package com.example.game_tracker

import android.util.Log
import org.json.JSONObject
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

object CloudinaryUploader {
    private const val TAG = "CloudinaryUploader"
    private const val CLOUD_NAME = "dsuaryuxj"
    private const val API_KEY = "331165958884664"
    private const val API_SECRET = "ZU-t1_zmu6PkbHVP0PyG_2028LM"

    fun uploadFile(file: File, callback: (url: String?, error: String?) -> Unit) {
        Thread {
            try {
                val boundary = "===${System.currentTimeMillis()}==="
                val timestamp = (System.currentTimeMillis() / 1000).toString()
                val signatureInput = "timestamp=${timestamp}${API_SECRET}"
                val signature = sha1Hex(signatureInput)

                val url = URL("https://api.cloudinary.com/v1_1/$CLOUD_NAME/image/upload")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    doOutput = true
                    doInput = true
                    useCaches = false
                    connectTimeout = 30000
                    readTimeout = 30000
                    setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                }

                val outputStream = DataOutputStream(conn.outputStream)

                // Field: api_key
                outputStream.writeBytes("--$boundary\r\n")
                outputStream.writeBytes("Content-Disposition: form-data; name=\"api_key\"\r\n\r\n")
                outputStream.writeBytes("$API_KEY\r\n")

                // Field: timestamp
                outputStream.writeBytes("--$boundary\r\n")
                outputStream.writeBytes("Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n")
                outputStream.writeBytes("$timestamp\r\n")

                // Field: signature
                outputStream.writeBytes("--$boundary\r\n")
                outputStream.writeBytes("Content-Disposition: form-data; name=\"signature\"\r\n\r\n")
                outputStream.writeBytes("$signature\r\n")

                // File data
                outputStream.writeBytes("--$boundary\r\n")
                outputStream.writeBytes("Content-Disposition: form-data; name=\"file\"; filename=\"${file.name}\"\r\n")
                outputStream.writeBytes("Content-Type: image/jpeg\r\n\r\n")

                val fileInputStream = FileInputStream(file)
                val buffer = ByteArray(4096)
                var bytesRead: Int
                while (fileInputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                outputStream.writeBytes("\r\n")
                fileInputStream.close()

                // End boundary
                outputStream.writeBytes("--$boundary--\r\n")
                outputStream.flush()
                outputStream.close()

                val responseCode = conn.responseCode
                if (responseCode == 200 || responseCode == 201) {
                    val responseText = conn.inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(responseText)
                    val secureUrl = json.optString("secure_url")
                    Log.d(TAG, "Cloudinary upload successful: $secureUrl")
                    callback(if (secureUrl.isNotEmpty()) secureUrl else null, null)
                } else {
                    val errorText = try {
                        conn.errorStream?.bufferedReader()?.use { it.readText() } ?: "HTTP $responseCode"
                    } catch (_: Throwable) {
                        "HTTP $responseCode"
                    }
                    Log.e(TAG, "Cloudinary upload failed ($responseCode): $errorText")
                    callback(null, "Cloudinary upload failed ($responseCode): $errorText")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Cloudinary upload exception: ${e.message}", e)
                callback(null, "Upload exception: ${e.message}")
            }
        }.start()
    }

    private fun sha1Hex(input: String): String {
        val md = MessageDigest.getInstance("SHA-1")
        val digest = md.digest(input.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}
