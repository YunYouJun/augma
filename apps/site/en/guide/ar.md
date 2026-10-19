# AR device simulator

<a href="/ar/" target="_self">Open the device simulator</a>. Explore Augma's spatial layers and apps without wearing a device or turning on a camera.

## Exploring the simulated view

The view follows the [original Augma site](https://augma.elpsy.cn/): by default it shows only a gray background, a clock and a white line at the top, and nine round icons at the bottom. Click an app to open its floating window; click it again or press Escape to close it. Once the camera is on, the real world becomes the background.

Along the bottom, in order: mirror, weather, HUD display, sound, space, camera, navigation, GitHub and component docs. The system menu at the top right offers full screen, camera switching, theme, settings, notifications and device controls; the microphone at the top left opens clickable simulated voice commands without asking for microphone permission.

The interface is available in 简体中文, English and 日本語. Opened from these docs, it uses the language you are reading; opened directly, it keeps your last choice, or follows your browser the first time. Switch it in Settings → Language, and the choice is saved in the current browser. After a voice command runs, the result is read aloud in the current language; if the browser has no speech synthesis, the result is shown as text only, and Spoken feedback can be turned off in Settings.

| App | What you can try |
| --- | --- |
| Weather | Switch cities and view sample temperatures (not live weather) |
| Space | Switch between Sky Garden / City Stroll, scan or cancel a scan, pin / release anchors, click places in the scene |
| Navigation | Pick a destination, switch colored routes, start simulated navigation, step forward until you arrive, or end navigation |
| Sound | Play locally synthesized chords, pause, switch tracks, adjust progress and volume |
| Notifications | Review the actions from this session; opening marks them as read, and you can clear them |
| Settings | Language, panel opacity, dark view, focus mode, mirror view, spoken feedback, depth motion, curved view, and restoring defaults |

Under Device in the system menu, you can put the device on standby, wake it, disconnect and reconnect. Standby or disconnecting stops scanning, navigation, sound, the camera and spatial AR. The eye icon at the bottom hides apps and spatial layers for a moment; click it again to bring them back.

Maps, places, distances and scan results are all simulated; they do not reflect your location, real-world recognition or live traffic. The interface draws on Augma's reality overlays, round app controls and floating routes, rebuilt as interactive SVG.

Display settings and volume are saved in the current browser; notifications and scene progress last only for this session. If you switch browser tabs while sound is playing, it pauses and does not resume on its own.

## Optional view effects

System menu → Settings → View effects at the top right has two independent switches, off by default and saved automatically:

- **Depth motion**: moving the mouse gives spatial layers and floating windows a subtle parallax and perspective; an opening window fades in and comes into focus while the map and camera backgrounds blur slightly. Touch screens keep the entrance animation but nothing follows your finger, so scrolling and tapping stay easy.
- **Curved view**: the top and bottom white lines become shallow arcs, and the nine round icons at the bottom line up along the arc. It works on its own, without depth motion.

When the system's reduced motion setting is on, depth motion pauses but the curved look stays. Hiding the HUD, putting the device on standby, entering spatial AR or switching to the background also pause depth motion. Restoring defaults turns both effects off.

## Connecting a camera

Open the Camera app at the bottom and click Turn on camera; only then does the browser ask for permission. The camera feed is shown on this page only and is never uploaded. You can switch cameras, turn on mirroring in Settings, or save a camera snapshot without the HUD. You can cancel while waiting for permission; the video track is released when you turn off the camera, put the device on standby or leave the page.

The camera needs HTTPS (localhost is fine for development) and a browser that supports MediaDevices. If permission is denied or no device is available, the simulated interface still works.

## Spatial AR

Browsers that support `immersive-ar` show a Prepare spatial AR button. Babylon and the XR code load only after you click it; once ready, click Enter spatial AR so that this user action starts the session. You can go back to camera mode.

Regular desktop browsers can usually use only the simulated or camera modes. Device support, reference spaces and permissions for spatial AR depend on what the browser actually offers; automated tests cannot replace testing on real hardware.

## How the Vue example is built

The simulator uses Vue 3.5 `<script setup lang="ts">`, reactive props destructuring, typed events, `defineModel` and `useTemplateRef`. The entry only composes device features; each app receives state through props and sends actions through events.

- `SystemBar`, `DeviceDock` and `DeviceWindow` manage the system bar, app launchers and floating windows; with no app open, the view stays empty.
- `useSimulator` manages the connection, scenes, scanning, navigation and notifications.
- `useDisplaySettings` manages display preferences and local storage, and validates the settings it reads.
- `useSoundscape`, `useCamera` and `useXr` manage browser resources and clean up on exit.
- Device apps reuse the public Augma components; app state, scene data and Babylon stay in the demo project.
