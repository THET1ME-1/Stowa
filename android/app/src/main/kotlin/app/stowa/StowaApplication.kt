package app.stowa

import android.app.Application

/** Процесс Stowa: сбор ошибок ставится раньше любого окна, приёмника и фоновой задачи. */
class StowaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        CrashCatcher.install(this)
    }
}
