package com.preeternal.reactnativecookiemanager

internal const val COOKIE_CHANGE_OBSERVATION_NOT_SUPPORTED =
  "Cookie change subscriptions are only supported on iOS"

internal fun rejectCookieChangeObservation(): Nothing =
  throw UnsupportedOperationException(COOKIE_CHANGE_OBSERVATION_NOT_SUPPORTED)
