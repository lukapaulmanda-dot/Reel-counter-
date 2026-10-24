#!/bin/bash
# Reel Counter - generates the whole Android project. Run from the repo root.
set -e

PKG_DIR=app/src/main/java/com/reelcounter/app
mkdir -p $PKG_DIR app/src/main/res/xml app/src/main/res/values

# ---------------- Gradle files ----------------
cat > settings.gradle.kts <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "ReelCounter"
include(":app")
EOF

cat > build.gradle.kts <<'EOF'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
EOF

cat > gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=false
kotlin.code.style=official
EOF

cat > app/build.gradle.kts <<'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.reelcounter.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.reelcounter.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}
EOF

# ---------------- Manifest + resources ----------------
cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.VIBRATE" />

    <application
        android:allowBackup="true"
        android:icon="@android:drawable/ic_menu_view"
        android:label="Reel Counter"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".ReelService"
            android:exported="false"
            android:label="Reel Counter"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_config" />
        </service>
    </application>
</manifest>
EOF

cat > app/src/main/res/xml/accessibility_config.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeViewScrolled|typeWindowStateChanged|typeWindowContentChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagReportViewIds|flagIncludeNotImportantViews"
    android:canRetrieveWindowContent="true"
    android:notificationTimeout="100"
    android:description="@string/service_desc" />
EOF

cat > app/src/main/res/values/strings.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="service_desc">Counts the reels/shorts you scroll in YouTube, Instagram, Facebook, Snapchat and similar apps, and shows a small counter on screen. Everything stays on your phone. Nothing is sent anywhere.</string>
</resources>
EOF

# ---------------- Store.kt (data + app list) ----------------
cat > $PKG_DIR/Store.kt <<'EOF'
package com.reelcounter.app

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object Store {

    // package name -> display name
    val APPS = linkedMapOf(
        "com.google.android.youtube" to "YouTube Shorts",
        "com.instagram.android" to "Instagram Reels",
        "com.instagram.lite" to "Instagram Lite",
        "com.facebook.katana" to "Facebook Reels",
        "com.facebook.lite" to "Facebook Lite",
        "com.snapchat.android" to "Snapchat Spotlight",
        "com.zhiliaoapp.musically" to "TikTok",
        "com.ss.android.ugc.trill" to "TikTok (Asia)",
        "in.mohalla.video" to "Moj",
        "com.eterno.shortvideos" to "Josh",
        "com.next.innovation.takatak" to "MX TakaTak"
    )

    // Apps where the WHOLE app is reels, so we always count
    val ALWAYS = setOf(
        "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill",
        "in.mohalla.video",
        "com.eterno.shortvideos",
        "com.next.innovation.takatak"
    )

    // For mixed apps: words in the screen's internal IDs that mean "reels section is open"
    val KEYS = mapOf(
        "com.google.android.youtube" to listOf("reel_player", "reel_recycler", "shorts_player"),
        "com.instagram.android" to listOf("clips_viewer", "reel_viewer", "clips_swipe"),
        "com.instagram.lite" to listOf("clips_viewer", "reel_viewer"),
        "com.facebook.katana" to listOf("reel"),
        "com.facebook.lite" to listOf("reel"),
        "com.snapchat.android" to listOf("spotlight")
    )

    private fun sp(c: Context) =
        c.applicationContext.getSharedPreferences("reels", Context.MODE_PRIVATE)

    fun dayKey(daysAgo: Int = 0): String {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
        return SimpleDateFormat("yyyyMMdd", Locale.US).format(cal.time)
    }

    fun addReel(c: Context, pkg: String) {
        val s = sp(c)
        val d = dayKey()
        val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        s.edit()
            .putInt("$d:count", s.getInt("$d:count", 0) + 1)
            .putInt("$d:h$h", s.getInt("$d:h$h", 0) + 1)
            .putInt("$d:app:$pkg:count", s.getInt("$d:app:$pkg:count", 0) + 1)
            .apply()
    }

    fun addSecond(c: Context, pkg: String) {
        val s = sp(c)
        val d = dayKey()
        s.edit()
            .putInt("$d:secs", s.getInt("$d:secs", 0) + 1)
            .putInt("$d:app:$pkg:secs", s.getInt("$d:app:$pkg:secs", 0) + 1)
            .apply()
    }

    fun count(c: Context, d: String) = sp(c).getInt("$d:count", 0)
    fun secs(c: Context, d: String) = sp(c).getInt("$d:secs", 0)
    fun hour(c: Context, d: String, h: Int) = sp(c).getInt("$d:h$h", 0)
    fun appCount(c: Context, d: String, pkg: String) = sp(c).getInt("$d:app:$pkg:count", 0)
    fun appSecs(c: Context, d: String, pkg: String) = sp(c).getInt("$d:app:$pkg:secs", 0)

    fun getLimit(c: Context) = sp(c).getInt("limit", 50)
    fun setLimit(c: Context, v: Int) {
        sp(c).edit().putInt("limit", v).apply()
    }
}
EOF

# ---------------- ReelService.kt (the counter brain + overlay) ----------------
cat > $PKG_DIR/ReelService.kt <<'EOF'
package com.reelcounter.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.TextView

class ReelService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var wm: WindowManager? = null
    private var overlay: TextView? = null
    private var overlayShown = false

    private var curPkg = ""
    private var inReels = false
    private var misses = 0
    private var lastCheck = 0L
    private var lastCount = 0L

    // runs every second: adds watch time while you are inside reels
    private val tick = object : Runnable {
        override fun run() {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (inReels && pm.isInteractive) {
                Store.addSecond(this@ReelService, curPkg)
                refresh()
            }
            handler.postDelayed(this, 1000)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        buildOverlay()
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, 1000)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        hideOverlay()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(e: AccessibilityEvent?) {
        if (e == null) return
        val pkg = e.packageName?.toString() ?: return
        if (pkg == packageName || pkg == "com.android.systemui") return
        val now = SystemClock.elapsedRealtime()
        val type = e.eventType

        // Some other app (home screen, keyboard, etc.)
        if (!Store.APPS.containsKey(pkg)) {
            if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                curPkg = pkg
                leaveReels()
            }
            return
        }

        if (pkg != curPkg) {
            curPkg = pkg
            leaveReels()
        }

        // Check (at most every 0.4s) whether the reels screen is open
        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || now - lastCheck > 400) {
            lastCheck = now
            val res = detect(pkg)
            if (res == true) {
                misses = 0
                if (!inReels) {
                    inReels = true
                    showOverlay()
                    countReel(pkg, now) // the first reel you land on
                }
            } else if (res == false) {
                misses++
                if (misses >= 2) leaveReels()
            }
        }

        // A big vertical swipe inside reels = next reel
        if (type == AccessibilityEvent.TYPE_VIEW_SCROLLED && inReels && bigScroll(e)) {
            countReel(pkg, now)
        }
    }

    private fun countReel(pkg: String, now: Long) {
        if (now - lastCount < 700) return // ignore double events from one swipe
        lastCount = now
        Store.addReel(this, pkg)
        refresh()
        val n = Store.count(this, Store.dayKey())
        val lim = Store.getLimit(this)
        if (lim > 0 && n >= lim && (n - lim) % 10 == 0) vibrate()
    }

    private fun leaveReels() {
        inReels = false
        misses = 0
        hideOverlay()
    }

    // true = reels screen open, false = not, null = can't tell right now
    private fun detect(pkg: String): Boolean? {
        if (Store.ALWAYS.contains(pkg)) return true
        val keys = Store.KEYS[pkg] ?: return false
        val root = rootInActiveWindow ?: return null
        if (root.packageName?.toString() != pkg) return null
        return scan(root, keys, intArrayOf(0))
    }

    private fun scan(n: AccessibilityNodeInfo?, keys: List<String>, budget: IntArray): Boolean {
        if (n == null || budget[0] > 500) return false
        budget[0]++
        val id = n.viewIdResourceName
        if (id != null) {
            val l = id.lowercase()
            for (k in keys) if (l.contains(k)) return true
        }
        for (i in 0 until n.childCount) {
            if (scan(n.getChild(i), keys, budget)) return true
        }
        return false
    }

    // reels pager covers most of the screen; comment lists etc. do not
    private fun bigScroll(e: AccessibilityEvent): Boolean {
        val src = e.source ?: return true
        val r = Rect()
        src.getBoundsInScreen(r)
        val h = resources.displayMetrics.heightPixels
        return r.height() >= h * 0.7
    }

    private fun vibrate() {
        try {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            v.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
        } catch (ex: Exception) {
        }
    }

    // ---------- floating counter ----------
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun buildOverlay() {
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val tv = TextView(this)
        tv.setTextColor(Color.WHITE)
        tv.textSize = 15f
        tv.setTypeface(null, Typeface.BOLD)
        tv.setPadding(dp(14), dp(6), dp(14), dp(6))
        val bg = GradientDrawable()
        bg.setColor(0xB3000000.toInt())
        bg.cornerRadius = dp(20).toFloat()
        tv.background = bg
        overlay = tv
        refresh()
    }

    private fun showOverlay() {
        if (overlayShown || overlay == null) return
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        lp.y = dp(70)
        try {
            wm?.addView(overlay, lp)
            overlayShown = true
        } catch (ex: Exception) {
        }
        refresh()
    }

    private fun hideOverlay() {
        if (!overlayShown) return
        try {
            wm?.removeView(overlay)
        } catch (ex: Exception) {
        }
        overlayShown = false
    }

    private fun refresh() {
        val d = Store.dayKey()
        val n = Store.count(this, d)
        val s = Store.secs(this, d)
        val lim = Store.getLimit(this)
        overlay?.text = "🎬 $n today  •  ${s / 60}m"
        val bg = overlay?.background as? GradientDrawable
        bg?.setColor(if (lim > 0 && n >= lim) 0xCCD32F2F.toInt() else 0xB3000000.toInt())
    }
}
EOF

# ---------------- MainActivity.kt (dashboard + charts) ----------------
cat > $PKG_DIR/MainActivity.kt <<'EOF'
package com.reelcounter.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.InputType
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Locale

class MainActivity : Activity() {

    private lateinit var root: LinearLayout
    private lateinit var statusTv: TextView
    private lateinit var bigTv: TextView
    private lateinit var timeTv: TextView
    private lateinit var limitEt: EditText
    private lateinit var appsTv: TextView
    private lateinit var weekTitle: TextView
    private lateinit var hourChart: BarChart
    private lateinit var weekChart: BarChart

    private val handler = Handler(Looper.getMainLooper())
    private val loop = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 1500)
        }
    }

    private val gray = 0xFF6B7280.toInt()

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val scroll = ScrollView(this)
        scroll.setBackgroundColor(0xFFF1F3F9.toInt())
        root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setPadding(dp(16), dp(32), dp(16), dp(32))
        scroll.addView(root)
        setContentView(scroll)

        label(root, "🎬 Reel Counter", 26f, true)

        // status + settings button
        val c1 = card()
        statusTv = label(c1, "", 15f, true)
        val btn = Button(this)
        btn.text = "Open Accessibility Settings"
        btn.setOnClickListener { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
        c1.addView(btn)

        // today
        val c2 = card()
        label(c2, "Today", 14f, false, gray)
        bigTv = label(c2, "0", 56f, true, 0xFF4F5BD5.toInt())
        label(c2, "reels watched", 14f, false, gray)
        timeTv = label(c2, "", 15f)

        // limit
        val c3 = card()
        label(c3, "⏰ Daily limit (phone vibrates when reached, 0 = off)", 14f, true)
        limitEt = EditText(this)
        limitEt.inputType = InputType.TYPE_CLASS_NUMBER
        limitEt.setText(Store.getLimit(this).toString())
        c3.addView(limitEt)
        val save = Button(this)
        save.text = "Save limit"
        save.setOnClickListener {
            Store.setLimit(this, limitEt.text.toString().toIntOrNull() ?: 0)
            Toast.makeText(this, "Saved ✅", Toast.LENGTH_SHORT).show()
        }
        c3.addView(save)

        // per app
        val c4 = card()
        label(c4, "📱 Today per app", 16f, true)
        appsTv = label(c4, "", 15f)

        // hourly chart
        val c5 = card()
        label(c5, "🕒 Reels by hour of day (today)", 16f, true)
        hourChart = BarChart(this)
        c5.addView(hourChart)

        // weekly chart
        val c6 = card()
        weekTitle = label(c6, "📅 Last 7 days", 16f, true)
        weekChart = BarChart(this)
        weekChart.barColor = 0xFF22A06B.toInt()
        c6.addView(weekChart)

        val c7 = card()
        label(
            c7,
            "💡 Tip: if the counter stops working after a while, open Settings > Battery > Reel Counter and set it to 'Unrestricted'.",
            13f, false, gray
        )
    }

    override fun onResume() {
        super.onResume()
        handler.post(loop)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(loop)
    }

    private fun card(): LinearLayout {
        val l = LinearLayout(this)
        l.orientation = LinearLayout.VERTICAL
        l.setPadding(dp(16), dp(14), dp(16), dp(14))
        val bg = GradientDrawable()
        bg.setColor(Color.WHITE)
        bg.cornerRadius = dp(16).toFloat()
        l.background = bg
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        lp.topMargin = dp(12)
        root.addView(l, lp)
        return l
    }

    private fun label(
        p: ViewGroup, t: String, size: Float,
        bold: Boolean = false, color: Int = 0xFF222222.toInt()
    ): TextView {
        val tv = TextView(this)
        tv.text = t
        tv.textSize = size
        tv.setTextColor(color)
        if (bold) tv.setTypeface(null, Typeface.BOLD)
        p.addView(tv)
        return tv
    }

    private fun isServiceOn(): Boolean {
        val s = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""
        return s.contains(packageName) && s.contains("ReelService")
    }

    private fun fmtTime(s: Int): String {
        if (s >= 3600) {
            return "${s / 3600}h ${(s % 3600) / 60}m"
        }
        if (s >= 60) {
            return "${s / 60}m ${s % 60}s"
        }
        return "${s}s"
    }

    private fun refresh() {
        if (isServiceOn()) {
            statusTv.text = "✅ Counter is ON. Open Shorts/Reels and swipe!"
        } else {
            statusTv.text = "⚠️ Counter is OFF. Tap the button below, find Reel Counter, turn it ON."
        }

        val d = Store.dayKey()
        val n = Store.count(this, d)
        val s = Store.secs(this, d)
        bigTv.text = n.toString()
        var timeLine = "⏱ " + fmtTime(s) + " watched"
        if (n > 0) {
            timeLine = timeLine + "  •  ~" + (s / n).toString() + "s per reel"
        }
        timeTv.text = timeLine

        val sb = StringBuilder()
        for ((pkg, name) in Store.APPS) {
            val c = Store.appCount(this, d, pkg)
            val t = Store.appSecs(this, d, pkg)
            if (c > 0 || t > 0) sb.append("• $name: $c reels, ${fmtTime(t)}\n")
        }
        appsTv.text = if (sb.isEmpty()) "No reels yet today" else sb.toString().trim()

        hourChart.labels = (0..23).map { "$it" }
        hourChart.values = (0..23).map { Store.hour(this, d, it) }
        hourChart.invalidate()

        val days = (6 downTo 0).map { Store.dayKey(it) }
        val parser = SimpleDateFormat("yyyyMMdd", Locale.US)
        val dayName = SimpleDateFormat("EEE", Locale.US)
        weekChart.labels = days.map { dayName.format(parser.parse(it)!!) }
        weekChart.values = days.map { Store.count(this, it) }
        weekChart.invalidate()
        weekTitle.text = "📅 Last 7 days: ${weekChart.values.sum()} reels total"
    }
}

class BarChart(c: Context) : View(c) {
    var labels: List<String> = emptyList()
    var values: List<Int> = emptyList()
    var barColor: Int = 0xFF4F5BD5.toInt()
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            MeasureSpec.getSize(widthMeasureSpec),
            (190 * resources.displayMetrics.density).toInt()
        )
    }

    override fun onDraw(cv: Canvas) {
        val n = values.size
        if (n == 0) return
        val d = resources.displayMetrics.density
        val top = 20 * d
        val bottom = height - 22 * d
        val max = (values.maxOrNull() ?: 0).coerceAtLeast(1)
        val slot = width.toFloat() / n
        p.textAlign = Paint.Align.CENTER
        p.textSize = (if (n > 8) 9 else 12) * d

        for (i in 0 until n) {
            val bh = (bottom - top) * values[i] / max
            val x0 = i * slot + slot * 0.15f
            val x1 = (i + 1) * slot - slot * 0.15f
            p.color = barColor
            cv.drawRoundRect(x0, bottom - bh, x1, bottom, 4 * d, 4 * d, p)

            p.color = 0xFF374151.toInt()
            if (values[i] > 0) {
                cv.drawText("${values[i]}", (x0 + x1) / 2, bottom - bh - 4 * d, p)
            }
            if (n <= 8 || i % 3 == 0) {
                p.color = 0xFF6B7280.toInt()
                val lab = if (i < labels.size) labels[i] else ""
                cv.drawText(lab, (x0 + x1) / 2, height - 6 * d, p)
            }
        }
    }
}
EOF

echo "Project generated."
