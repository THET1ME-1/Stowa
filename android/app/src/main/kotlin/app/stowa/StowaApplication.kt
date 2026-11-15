package app.stowa

import android.app.Application
import app.stowa.edge.EdgeService

/** Процесс Stowa: сбор ошибок ставится раньше любого окна, приёмника и фоновой задачи. */
class StowaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        CrashCatcher.install(this)
        // HyperOS поднимает процесс после смахивания, а службу корешков теряет: проверить и поднять
        EdgeService.reviveLater(this)
    }
}
