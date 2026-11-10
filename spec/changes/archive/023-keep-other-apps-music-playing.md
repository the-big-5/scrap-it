# 023: Keep other apps' music playing in the scrapbook
Status: Done

## Why
Music from another app (for example Spotify) stops when a scrapbook page with Live Photos is open. If the user starts the music again, it stops again.

Cause: the app never sets up an audio session, so iOS uses the default `.soloAmbient`. That category silences other apps as soon as the app plays media. The Live Photo loops on the page (`LoopingVideoView`, change 013) are muted. But starting one still turns on the audio session and stops the other app's music. The loops start again after every drag, pinch or rotate of an item, so the music keeps stopping.

## Touches
tech.md (Scrapbook: Live Photo loops)

## Changes
- MODIFIED `LoopingVideoView` sets the shared audio session to `.ambient` before a loop starts. That category mixes with other apps' audio and follows the silent switch. Music from other apps keeps playing while Live Photos loop on scrapbook pages.

## Tasks
- [x] Set `AVAudioSession.sharedInstance()` to `.ambient` in `LoopingPlayerUIView.play(_:)` before the player starts
- [x] Build; check on a device that Spotify keeps playing while a page with Live Photos is open and while items are moved

## Out of scope
- The camera: the capture session sets up its own audio session while recording Live Photos
- The Roll Reveal photo detail (`PHLivePhotoView`, change 021) and the debug last-shot view
- Playing the Live Photos' own sound
