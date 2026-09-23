# CMA MCQ Portal — Android (Flutter)

This repository contains the existing CMA MCQ Portal website plus a Flutter Android wrapper.

## How the APK works

The Flutter app opens the live GitHub Pages portal inside an Android WebView, so website/Firebase changes can be published without rebuilding the APK.

Portal URL:
`https://rohitfcg123-arch.github.io/CMA-MCQ-Portal-Android/`

## Build from phone

Push the repository to GitHub. GitHub Actions runs Flutter on the server and creates:

`build/app/outputs/flutter-apk/app-release.apk`

Download it from the workflow's **Artifacts** section.

## Important

The app wrapper detects its own user-agent and the website uses Google redirect sign-in inside the Android app instead of the browser popup flow. This is needed because WebView environments do not reliably support the normal browser popup flow.

For Play Store release, configure a real signing key; the GitHub Actions artifact above is intended for testing/distribution outside Play Store.
