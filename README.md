# Social App (Solice)

A Flutter app for a social media API. You can post photos, like and comment, find people, add friends and chat with them.

## About this project

The original web app was made by [@Muhammad-Ahsan09](https://github.com/Muhammad-Ahsan09).  I took it and converted it into a Flutter app for mobile, using the same backend.

Web app: https://social-media-app-d66c.vercel.app/

Backend: https://social-media-app-five-rust.vercel.app

## What it does

1. Sign up and log in
2. Scroll a feed of posts, like them and leave comments
3. Create your own posts and delete them later
4. Explore and search for people and posts
5. Send friend requests and manage your friends list
6. Chat with your friends
7. Edit your profile and change your photo

## Built with

Flutter, Riverpod for state, Dio for networking, flutter_secure_storage to keep the login token safe, and image_picker for photos.

## How to run it

You need Flutter installed (Dart 3.8 or newer) and an Android phone or emulator.

1. Clone the repo and open the folder in a terminal.

2. This repo only has the Dart code, so generate the platform folders first:

```
flutter create .
```

3. Open `android/app/src/main/AndroidManifest.xml` and add this line just above the `<application` tag. Without it the app can't reach the internet in a release build.

```
<uses-permission android:name="android.permission.INTERNET"/>
```

4. Get the packages:

```
flutter pub get
```

5. Run it:

```
flutter run
```

## Backend address

The API address lives at the top of `lib/api_client.dart`. If you host your own backend, change it there.
