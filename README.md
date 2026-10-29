# Social App (Solace)

A Flutter app for a social media API. You can post photos, like and comment, find people, add friends and chat with them.

## About this project

The original web app was made by [@Muhammad-Ahsan09](https://github.com/Muhammad-Ahsan09).  I took it and converted it into a Flutter app for mobile, using the same backend.

Web app: https://social-media-app-d66c.vercel.app/

Backend: https://social-media-app-five-rust.vercel.app

## What it does

1. Sign up and log in, with a show and hide button on the password field
2. Scroll a feed of posts, like them and leave comments
3. Double tap a photo to like it, and see how many comments a post has
4. Share photos and videos, with play, pause, skip, mute and a progress bar for videos
5. Post moments that disappear after 24 hours, shown as boxes, and watch your friends' moments
6. Create your own posts and delete them later
7. Discover posts on a style wall and search for people and posts, with your search highlighted in the results
8. Scenes: swipe through short videos, like, comment and post your own
9. Journeys: create a chapter with a cover and add memories with photos and videos
10. Send friend requests and manage your friends list
11. Chat with your friends
12. Edit your profile and change your photo
13. Tap someone's profile picture to see their moment, or hold it to see the full photo
14. Dark mode and theme colors, remembered after you close the app
15. Videos pause when you scroll away, and images load faster because they are saved on your phone
16. A friendly message when you are offline

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

