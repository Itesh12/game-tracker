package com.example.game_tracker.infrastructure.service

import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import com.example.game_tracker.domain.controller.LocationController
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class LocationControllerImpl(
    private val context: Context
) : LocationController {

    override suspend fun isGpsAvailable(): Boolean {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
               locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    override suspend fun isLocationPermissionGranted(): Boolean {
        val fineGranted = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseGranted = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fineGranted || coarseGranted
    }

    override suspend fun getSingleLocationFix(highAccuracy: Boolean): Pair<Double, Double> = withContext(Dispatchers.IO) {
        if (!isLocationPermissionGranted()) {
            throw IllegalStateException("Location permission denied")
        }

        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val provider = if (highAccuracy && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            LocationManager.GPS_PROVIDER
        } else {
            LocationManager.NETWORK_PROVIDER
        }

        try {
            val lastLocation = locationManager.getLastKnownLocation(provider)
            if (lastLocation != null) {
                Pair(lastLocation.latitude, lastLocation.longitude)
            } else {
                Pair(37.7749, -122.4194) // Default fallback coordinates
            }
        } catch (e: SecurityException) {
            throw IllegalStateException("Security exception accessing location: ${e.message}")
        }
    }
}
