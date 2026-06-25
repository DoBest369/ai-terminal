package com.termind.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import java.util.concurrent.TimeUnit

/**
 * 定时后台巡检（N-CronAuto）：周期性对所有连接做 TCP 可达性探测，离线则发本地通知。
 * 主动运维——不用手动点，后台自动盯着服务器在线状态。
 * 注：密码不持久化，后台仅做可达性探测；完整状态巡检需凭据，留 TODO。
 */
class InspectWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result = coroutineScope {
        val conns = ConnectionStore.load(applicationContext)
        if (conns.isEmpty()) return@coroutineScope Result.success()
        val offline = conns.map { c ->
            async { c to Reachability.probe(c.host, c.port) }
        }.awaitAll().filter { !it.second }.map { it.first }
        if (offline.isNotEmpty()) {
            notify(applicationContext, "${offline.size} 台服务器离线",
                offline.joinToString("、") { it.name })
        }
        Result.success()
    }

    companion object {
        private const val CHANNEL = "termind_inspect"
        private const val WORK = "termind_periodic_inspect"

        fun ensureChannel(ctx: Context) {
            val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL) == null) {
                mgr.createNotificationChannel(
                    NotificationChannel(CHANNEL, "服务器巡检", NotificationManager.IMPORTANCE_DEFAULT)
                        .apply { description = "定时巡检发现异常时提醒" })
            }
        }

        fun notify(ctx: Context, title: String, text: String) {
            ensureChannel(ctx)
            if (ctx.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
            val n = NotificationCompat.Builder(ctx, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("⚡ Termind · $title")
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .build()
            runCatching { NotificationManagerCompat.from(ctx).notify(1001, n) }
        }

        /** 启用定时巡检（最小间隔 15 分钟） */
        fun enable(ctx: Context, minutes: Long = 15) {
            ensureChannel(ctx)
            val req = PeriodicWorkRequestBuilder<InspectWorker>(maxOf(15, minutes), TimeUnit.MINUTES).build()
            WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.UPDATE, req)
        }

        fun disable(ctx: Context) {
            WorkManager.getInstance(ctx).cancelUniqueWork(WORK)
        }
    }
}
