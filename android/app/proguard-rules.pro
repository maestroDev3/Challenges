# Eigene R8-Regeln für die Release-APK.

# WorkManager (kommt über home_widget) lädt seine Room-Datenbank per Reflexion
# (Klassenname + "_Impl"). Ohne diese Regeln entfernt R8 die generierte Klasse
# und die App stürzt beim Start ab (#94).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** { *; }
