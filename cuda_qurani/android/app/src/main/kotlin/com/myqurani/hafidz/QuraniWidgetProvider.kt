package com.myqurani.hafidz

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class QuraniWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.qurani_widget).apply {
                
                // Get data with defaults
                val arabic = widgetData.getString("ayah_arabic", "Loading...")
                val translation = widgetData.getString("ayah_translation", "Tap to refresh")
                val reference = widgetData.getString("ayah_reference", "")
                val titleText = widgetData.getString("ayah_title_text", "Ayah of the Day") // Localized title
                val surahId = widgetData.getInt("ayah_surah_id", 1)
                val ayahNum = widgetData.getInt("ayah_number", 1)
                
                // Format Ayah with Ornate Parentheses ﴾ ١٢٣ ﴿ (Best fallback for Widget)
                val arabicDigits = toArabicDigits(ayahNum)
                // Remove existing end-of-verse symbols/numbers
                val cleanArabic = arabic?.replace(Regex("[\\u06DD\\uFD3E\\uFD3F\\d\\u0660-\\u0669]+\\s*$"), "")?.trim() ?: ""
                val formattedArabic = "$cleanArabic \uFD3F$arabicDigits\uFD3E"
                
                // Set text directly
                setTextViewText(R.id.widget_title, titleText)
                setTextViewText(R.id.widget_ayah_arabic, formattedArabic)
                setTextViewText(R.id.widget_ayah_translation, translation)
                setTextViewText(R.id.widget_ayah_reference, reference)
                
                // Open App on Click with Deep Link Data
                val intent = android.content.Intent(context, MainActivity::class.java)
                intent.action = android.content.Intent.ACTION_VIEW
                intent.data = android.net.Uri.parse("qurani://ayah/$surahId/$ayahNum")
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)
                
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 
                    0, 
                    intent, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                setOnClickPendingIntent(R.id.widget_logo, pendingIntent)
                // widget_app_name removed from layout
                setOnClickPendingIntent(R.id.widget_ayah_arabic, pendingIntent)
                setOnClickPendingIntent(R.id.widget_ayah_translation, pendingIntent)
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
