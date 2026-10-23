package com.example.autoclicker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BankingModeReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DISABLE_BANKING = "com.example.autoclicker.ACTION_DISABLE_BANKING"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == ACTION_DISABLE_BANKING) {
            Log.d("BankingModeReceiver", "Disabling Accessibility Service for Banking Mode")
            RapidoAutoClickService.instance?.disableForBanking(context)
        }
    }
}
