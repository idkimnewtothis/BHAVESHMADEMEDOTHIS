package eu.kanade.tachiyomi.network
import android.content.Context
import okhttp3.OkHttpClient
import okhttp3.CookieJar
import java.util.concurrent.TimeUnit

class NetworkHelper(context: Context) {
    val cookieJar = CookieJar.NO_COOKIES
    val client = OkHttpClient.Builder().cookieJar(cookieJar)
        .connectTimeout(8, TimeUnit.SECONDS).readTimeout(15, TimeUnit.SECONDS)
        .callTimeout(20, TimeUnit.SECONDS)
        .addInterceptor { chain ->
            val response = chain.proceed(chain.request())
            if (response.code in listOf(401, 402, 403) || response.header("cf-mitigated") == "challenge") {
                response.close()
                throw java.io.IOException("Source requires login, payment or a challenge and is unsupported")
            }
            response
        }.build()
    val cloudflareClient = client
    val nonCloudflareClient = client
    companion object {
        fun defaultUserAgentProvider() = "Bhavesh/1.0 (Android)"
    }
}
