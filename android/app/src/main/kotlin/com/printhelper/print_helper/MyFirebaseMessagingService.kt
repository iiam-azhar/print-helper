package com.printhelper.print_helper

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telecom.*
import android.util.Log
import androidx.annotation.RequiresPermission
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.twilio.twilio_voice.receivers.TVBroadcastReceiver
import com.twilio.twilio_voice.service.TVConnectionService
import com.twilio.twilio_voice.storage.StorageImpl
import com.twilio.twilio_voice.types.TelecomManagerExtension.canReadPhoneNumbers
import com.twilio.twilio_voice.types.TelecomManagerExtension.canReadPhoneState
import com.twilio.twilio_voice.types.TelecomManagerExtension.hasCallCapableAccount
import com.twilio.voice.CallException
import com.twilio.voice.CallInvite
import com.twilio.voice.CancelledCallInvite
import com.twilio.voice.MessageListener
import com.twilio.voice.Voice

class MyFirebaseMessagingService : FlutterFirebaseMessagingService(), MessageListener {

    companion object {
        private const val TAG = "MyFCMService"
        private const val ACTION_NEW_TOKEN = "ACTION_NEW_TOKEN"
        private const val EXTRA_FCM_TOKEN = "token"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "onNewToken: $token")
        
        // Broadcast the new token to Twilio Voice
        val intent = Intent(ACTION_NEW_TOKEN).apply {
            putExtra(EXTRA_FCM_TOKEN, token)
        }
        sendBroadcast(intent)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "onMessageReceived: Data = ${remoteMessage.data}")
        
        if (remoteMessage.data.isNotEmpty()) {
            val valid = Voice.handleMessage(this, remoteMessage.data, this)
            if (valid) {
                Log.d(TAG, "onMessageReceived: Intercepted and handled by Twilio Voice SDK")
                return
            }
        }
        
        // Forward general notifications to Flutter (firebase_messaging background handler)
        super.onMessageReceived(remoteMessage)
    }

    //region MessageListener Implementation (Verbatim from Twilio Voice service)
    @RequiresPermission(allOf = [Manifest.permission.RECORD_AUDIO, Manifest.permission.READ_PHONE_STATE, Manifest.permission.READ_PHONE_NUMBERS])
    @SuppressLint("MissingPermission")
    override fun onCallInvite(callInvite: CallInvite) {
        Log.d(TAG, "onCallInvite: CallSid = ${callInvite.callSid}, From = ${callInvite.from}")
        
        val tm = applicationContext.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val shouldRejectOnNoPermissions = StorageImpl(applicationContext).rejectOnNoPermissions
        var missingPermissions = emptyArray<String>()

        if (!tm.canReadPhoneState(applicationContext)) {
            missingPermissions += "No `READ_PHONE_STATE` permission, cannot check if phone account is registered."
        }

        if (!tm.canReadPhoneNumbers(applicationContext)) {
            missingPermissions += "No `READ_PHONE_NUMBERS` permission, cannot communicate with ConnectionService if not granted."
        }

        if (!tm.hasCallCapableAccount(applicationContext, TVConnectionService::class.java.name)) {
            missingPermissions += "No call capable phone account registered."
        }

        if (missingPermissions.isNotEmpty()) {
            missingPermissions.forEach { Log.e(TAG, it) }

            if (!shouldRejectOnNoPermissions) {
                return
            }
            
            Log.e(TAG, "onCallInvite: Rejecting incoming call due to missing permissions")

            Intent(applicationContext, TVBroadcastReceiver::class.java).apply {
                action = TVBroadcastReceiver.ACTION_INCOMING_CALL_IGNORED
                putExtra(TVBroadcastReceiver.EXTRA_INCOMING_CALL_IGNORED_REASON, missingPermissions)
                putExtra(TVBroadcastReceiver.EXTRA_CALL_HANDLE, callInvite.callSid)
                LocalBroadcastManager.getInstance(applicationContext).sendBroadcast(this)
            }

            callInvite.reject(applicationContext)
            return
        }

        // Notify TelecomManager about incoming call
        Intent(applicationContext, TVConnectionService::class.java).apply {
            action = TVConnectionService.ACTION_INCOMING_CALL
            putExtra(TVConnectionService.EXTRA_INCOMING_CALL_INVITE, callInvite)
            applicationContext.startService(this)
        }

        // Notify Flutter about incoming call
        Intent(applicationContext, TVBroadcastReceiver::class.java).apply {
            action = TVBroadcastReceiver.ACTION_INCOMING_CALL
            putExtra(TVBroadcastReceiver.EXTRA_CALL_INVITE, callInvite)
            putExtra(TVBroadcastReceiver.EXTRA_CALL_HANDLE, callInvite.callSid)
            LocalBroadcastManager.getInstance(applicationContext).sendBroadcast(this)
        }
    }

    override fun onCancelledCallInvite(cancelledCallInvite: CancelledCallInvite, callException: CallException?) {
        Log.d(TAG, "onCancelledCallInvite: ", callException)
        Intent(applicationContext, TVConnectionService::class.java).apply {
            action = TVConnectionService.ACTION_CANCEL_CALL_INVITE
            putExtra(TVConnectionService.EXTRA_CANCEL_CALL_INVITE, cancelledCallInvite)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(this)
            } else {
                applicationContext.startService(this)
            }
        }
    }
    //endregion
}
