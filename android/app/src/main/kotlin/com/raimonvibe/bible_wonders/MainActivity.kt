package com.raimonvibe.bible_wonders

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * Extends AudioServiceActivity rather than FlutterActivity so the activity and
 * the media service share one FlutterEngine.
 *
 * Without it audio_service starts a second engine of its own, and the
 * notification ends up driving a SpeechController the app cannot see: play on
 * the lock screen would begin a reading that nothing on screen reflects.
 */
class MainActivity : AudioServiceActivity()
