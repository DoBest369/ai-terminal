package com.termind.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.InetSocketAddress
import java.net.Socket

/**
 * 连接可达性探测（A-Reach）：纯 TCP connect，不做 SSH 握手（对齐 apple ReachabilityChecker）。
 */
object Reachability {
    /** TCP 探测：能在超时内建立连接即视为可达。 */
    suspend fun probe(host: String, port: Int, timeoutMs: Int = 3000): Boolean =
        withContext(Dispatchers.IO) {
            runCatching {
                Socket().use { sock ->
                    sock.connect(InetSocketAddress(host, port), timeoutMs)
                    true
                }
            }.getOrDefault(false)
        }
}
