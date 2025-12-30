package com.myqurani.hafidz

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class GoalWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.goal_widget).apply {
                val current = widgetData.getInt("goal_current", 0)
                val target = widgetData.getInt("goal_target", 10)
                val titleText = widgetData.getString("goal_title_text", "Target Harian")
                val progressText = widgetData.getString("goal_progress_text", "$current/$target Ayat")
                
                val safeTarget = if (target > 0) target else 1
                val progress = (current.toFloat() / safeTarget.toFloat() * 100).toInt()

                setProgressBar(R.id.widget_goal_progress, 100, progress, false)
                setTextViewText(R.id.widget_goal_title, titleText)
                setTextViewText(R.id.widget_goal_text, progressText)

                // Open App on Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_goal_title, pendingIntent)
                setOnClickPendingIntent(R.id.widget_goal_text, pendingIntent)
                setOnClickPendingIntent(R.id.widget_goal_progress, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)

            // Update Generated Preview for Android 15+ (API 35+)
            if (android.os.Build.VERSION.SDK_INT >= 35) {
                try {
                    val componentName = android.content.ComponentName(context, GoalWidgetProvider::class.java)
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
}
