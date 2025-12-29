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
                val surahId = widgetData.getInt("ayah_surah_id", 1)
                val ayahNum = widgetData.getInt("ayah_number", 1)
                
                // Format Ayah with End Symbol (Ornate Parentheses)
                val arabicDigits = toArabicDigits(ayahNum)
                val formattedArabic = "$arabic \uFD3F$arabicDigits\uFD3E"

                // Set text directly
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
