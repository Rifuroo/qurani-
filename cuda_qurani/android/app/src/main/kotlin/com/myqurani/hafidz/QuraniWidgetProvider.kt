package com.myqurani.hafidz

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class QuraniWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.qurani_widget).apply {
                
                // Get data with defaults (Handle Long/Int mismatch from Flutter)
                val arabic = widgetData.getString("ayah_arabic", "Loading...")
                val translation = widgetData.getString("ayah_translation", null)
                val reference = widgetData.getString("ayah_reference", "")
                val titleText = widgetData.getString("ayah_title_text", "Ayah of the Day")
                
                // Safe number reading helpers
                fun SharedPreferences.getSafeInt(key: String, def: Int): Int {
                    return try { this.getInt(key, def) } catch (e: Exception) { this.getLong(key, def.toLong()).toInt() }
                }

                val surahId = widgetData.getSafeInt("ayah_surah_id", 1)
                val ayahNum = widgetData.getSafeInt("ayah_number", 1)
                
                // Format Ayah with Ornate Parentheses ﴾ ١٢٣ ﴿ (Best fallback for Widget)
                val arabicDigits = toArabicDigits(ayahNum)
                // Remove existing end-of-verse symbols/numbers
                val cleanArabic = arabic?.replace(Regex("[\\u06DD\\uFD3E\\uFD3F\\d\\u0660-\\u0669]+\\s*$"), "")?.trim() ?: ""
                val formattedArabic = "$cleanArabic \uFD3F$arabicDigits\uFD3E"
                
                // Set text directly
                setTextViewText(R.id.widget_title, titleText)
                setTextViewText(R.id.widget_ayah_arabic, formattedArabic)
                
                // Visibility logic for translation (Hide when empty/Arabic)
                if (translation.isNullOrEmpty()) {
                    setViewVisibility(R.id.widget_ayah_translation, android.view.View.GONE)
                } else {
                    setViewVisibility(R.id.widget_ayah_translation, android.view.View.VISIBLE)
                    setTextViewText(R.id.widget_ayah_translation, translation)
                }
                setTextViewText(R.id.widget_ayah_reference, reference)
                
                // Open App on Click with Deep Link Data
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context, 
                    MainActivity::class.java,
                    Uri.parse("qurani://ayah/$surahId/$ayahNum")
                )

                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)

            // Update Generated Preview for Android 15+ (API 35+)
            if (android.os.Build.VERSION.SDK_INT >= 35) {
                try {
                    val componentName = android.content.ComponentName(context, QuraniWidgetProvider::class.java)
                    appWidgetManager.setWidgetPreview(
                        componentName,
                        android.appwidget.AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
                        views
                    )
                } catch (e: Exception) {
                    // Fallback or ignore if API is not available as expected
                }
            }
        }
    }

    private fun toArabicDigits(number: Int): String {
        val english = "0123456789"
        val arabic = "٠١٢٣٤٥٦٧٨٩"
        val builder = StringBuilder()
        val str = number.toString()
        for (char in str) {
            val index = english.indexOf(char)
            if (index != -1) {
                builder.append(arabic[index])
            } else {
                builder.append(char)
            }
        }
        return builder.toString()
    }
}
