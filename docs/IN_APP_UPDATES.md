# Google Play in-app updates

FoxyCo uses Google's Play In-App Update library with the flexible update type.
The feature is only active when Google Play reports an update for the installed
Play-distributed application. Debug and sideloaded installs fail closed and do
not show an error.

## Test with Play Internal testing

1. Build and upload version A of the AAB to FoxyCo's Internal testing track.
2. Add the tester's Google account to the track and accept the tester opt-in.
3. Install version A from Google Play, not from a local APK.
4. Increment `version`/version code and build version B.
5. Upload B to the same tester distribution and wait for Play to expose it to
   the tester account.
6. Open version A and wait for FoxyCo to check for updates on Home/resume.
7. Confirm the compact `FoxyCo update available` card appears while Home is idle.
8. Confirm it shows `Later` and `Update now`.
9. Tap `Update now` and accept Google's flexible update consent UI.
10. Continue using FoxyCo while Play downloads B in the background.
11. Confirm the card changes to `FoxyCo update ready`, then tap `Restart now`.
12. Confirm Play completes the installation and FoxyCo reopens on version B.

The prompt is hidden while FoxyCo is watching or paused in a live session. A
flexible update that Play reports as unavailable for the installed build is
ignored without showing a misleading action. Selecting `Later` suppresses the
prompt for the current foreground session.

Google Play's Internal App Sharing can be used instead of Internal testing if
the tester account and distribution path are configured for it. A locally
sideloaded APK is not an equivalent test: Play may not consider it eligible for
an in-app update because Play must manage the installed package and update.
