// Copy this file to Secrets.swift and fill in your values.
// Secrets.swift is gitignored and will not be committed.
//
// You also need to copy Secrets.xcconfig.example → Secrets.xcconfig
// in CloomApp/Resources/ and set GOOGLE_CLIENT_ID there.
// build.sh auto-derives GOOGLE_REVERSED_CLIENT_ID for Info.plist URL scheme substitution.
//
// To get a Google OAuth Client ID:
// 1. Go to https://console.cloud.google.com
// 2. Create a project (or select existing)
// 3. Enable the Google Drive API
// 4. Go to APIs & Services > Credentials > Create Credentials > OAuth Client ID
// 5. Choose "macOS" as the application type
// 6. Set bundle ID to "com.cloom.app"
// 7. Copy the Client ID below

enum Secrets {
    static let googleClientID = ""
}
