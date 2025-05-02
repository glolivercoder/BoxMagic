package com.boxmagic.boxmagic

import androidx.multidex.MultiDexApplication

class MultiDexApplication : MultiDexApplication() {
    override fun onCreate() {
        super.onCreate()
        // Inicializações adicionais podem ser feitas aqui
    }
}
