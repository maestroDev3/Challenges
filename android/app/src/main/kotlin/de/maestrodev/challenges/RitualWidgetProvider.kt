package de.maestrodev.challenges

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Homescreen-Widget „Ritual – Heute“: bis zu vier Challenges mit Streak und
 * Haken. Der Haken ruft Dart im Hintergrund auf (ritual://check?id=…),
 * ein Tipp auf das Widget öffnet die App. Daten schreibt die App über
 * home_widget (Schlüssel count, id_i, title_i, streak_i, done_i).
 */
class RitualWidgetProvider : HomeWidgetProvider() {
    private val rows = listOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3)
    private val titles = listOf(R.id.title_0, R.id.title_1, R.id.title_2, R.id.title_3)
    private val streaks = listOf(R.id.streak_0, R.id.streak_1, R.id.streak_2, R.id.streak_3)
    private val checks = listOf(R.id.check_0, R.id.check_1, R.id.check_2, R.id.check_3)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.ritual_widget)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            val count = widgetData.getInt("count", 0)
            views.setViewVisibility(R.id.empty, if (count == 0) View.VISIBLE else View.GONE)
            for (i in rows.indices) {
                if (i >= count) {
                    views.setViewVisibility(rows[i], View.GONE)
                    continue
                }
                views.setViewVisibility(rows[i], View.VISIBLE)
                views.setTextViewText(titles[i], widgetData.getString("title_$i", ""))
                views.setTextViewText(streaks[i], widgetData.getString("streak_$i", ""))
                val done = widgetData.getBoolean("done_$i", false)
                views.setTextViewText(checks[i], if (done) "✓" else "○")
                val id = widgetData.getString("id_$i", "") ?: ""
                views.setOnClickPendingIntent(
                    checks[i],
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("ritual://check?id=" + Uri.encode(id)),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
