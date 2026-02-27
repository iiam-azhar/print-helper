package com.printhelper.print_helper

import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        registerTwilioPhoneAccountIfNeeded()
    }

    private fun registerTwilioPhoneAccountIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val componentName = ComponentName(this, "com.twilio.twilio_voice.service.TVConnectionService")
            val handle = PhoneAccountHandle(componentName, "print_helper_twilio")
            val builder = PhoneAccount.builder(handle, "Print Helper")
            builder.setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
            val phoneAccount = builder.build()
            telecomManager.registerPhoneAccount(phoneAccount)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
