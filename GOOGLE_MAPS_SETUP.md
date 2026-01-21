# Google Maps Setup Instructions

## Why is the map not loading?

The interactive map feature requires a valid Google Maps API key. Currently, the app is using a placeholder API key which is why you see a fallback view instead of the actual map.

## How to fix this:

### Step 1: Get Google Maps API Key

1. **Go to Google Cloud Console**: https://console.cloud.google.com/
2. **Create a new project** or select an existing one
3. **Enable APIs**:
   - Go to "APIs & Services" > "Library"
   - Search for and enable "Maps SDK for Android"
   - Search for and enable "Geocoding API" (for address search)
4. **Create API Key**:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy the generated API key

### Step 2: Configure the API Key

1. **Open**: `android/app/src/main/AndroidManifest.xml`
2. **Replace** the placeholder API key:
   ```xml
   <!-- Replace this line -->
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="AIzaSyDevelopmentKeyForTesting123456789"/>
   
   <!-- With your real API key -->
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_ACTUAL_API_KEY_HERE"/>
   ```

### Step 3: Secure Your API Key (Recommended)

1. **In Google Cloud Console**, go to your API key
2. **Click "Restrict Key"**
3. **Set Application restrictions**:
   - Choose "Android apps"
   - Add your package name: `com.example.blood_donation_app`
   - Add your SHA-1 certificate fingerprint
4. **Set API restrictions**:
   - Choose "Restrict key"
   - Select only the APIs you need:
     - Maps SDK for Android
     - Geocoding API

### Step 4: Test the Map

1. **Rebuild the app**: `flutter clean && flutter pub get && flutter run`
2. **Navigate to location picker** (Create Blood Request > Select Location)
3. **You should now see the interactive Google Map**

## Current Functionality Without API Key

Even without the API key, the location picker still works:
- ✅ GPS location detection
- ✅ Address search using geocoding
- ✅ Location selection and confirmation
- ✅ Coordinate display
- ❌ Interactive map visualization

## Cost Information

- Google Maps API has a **free tier** with generous limits
- **First $200/month is free** for most users
- **Maps SDK for Android**: $7 per 1,000 requests (after free tier)
- **Geocoding API**: $5 per 1,000 requests (after free tier)

For a blood donation app, you're unlikely to exceed the free tier limits.

## Alternative Solutions

If you prefer not to set up Google Maps API:
1. The current fallback interface works perfectly
2. Users can still search for locations and use GPS
3. All location functionality remains intact
4. Only the visual map is missing

## Need Help?

If you encounter issues:
1. Check the Android Studio logcat for error messages
2. Verify your API key is correctly placed in AndroidManifest.xml
3. Ensure the required APIs are enabled in Google Cloud Console
4. Make sure your API key restrictions allow your app package name