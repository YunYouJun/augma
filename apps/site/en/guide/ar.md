# AR device simulator

<a href="/ar/" target="_self">Open the device simulator</a>. Explore Augma's spatial layers and apps without wearing a device or turning on a camera.

## Exploring the simulated view

The view follows the [original Augma site](https://augma.elpsy.cn/): a clock and a white line at the top, and nine round icons at the bottom. Without the camera, the background is the current space scene in moving layers, or the original plain gray if you prefer. Click an app to open its floating window; click it again or press Escape to close it. Once the camera is on, the real world becomes the background.

Along the bottom, in order: mirror, weather, HUD display, sound, space, camera, navigation, GitHub and component docs. The system menu at the top right offers full screen, camera switching, theme, settings, notifications and device controls; the microphone at the top left opens [voice commands](#voice-commands-and-the-deepseek-assistant).

The interface is available in 简体中文, English and 日本語. Opened from these docs, it uses the language you are reading; opened directly, it keeps your last choice, or follows your browser the first time. Switch it in Settings → Language, and the choice is saved in the current browser. After a voice command runs, the result is read aloud in the current language; if the browser has no speech synthesis, the result is shown as text only, and Spoken feedback can be turned off in Settings.

| App | What you can try |
| --- | --- |
| Weather | Switch cities and view sample temperatures (not live weather) |
| Space | Switch between Sky Garden / City Stroll, scan or cancel a scan, pin / release anchors, click places in the scene |
| Navigation | Pick a destination, switch colored routes, start simulated navigation, step forward until you arrive, or end navigation |
| Sound | Play locally synthesized chords, pause, switch tracks, adjust progress and volume |
| Notifications | Review the actions from this session; opening marks them as read, and you can clear them |
| Settings | Language, panel opacity, dark view, focus mode, mirror view, spoken feedback, DeepSeek assistant, scene backdrop, depth motion, curved view, keyboard shortcuts, and restoring defaults |

Under Device in the system menu, you can put the device on standby, wake it, disconnect and reconnect. Standby or disconnecting stops scanning, navigation, sound, the camera and spatial AR. The eye icon at the bottom hides apps and spatial layers for a moment; click it again to bring them back.

Maps, places, distances and scan results are all simulated; they do not reflect your location, real-world recognition or live traffic. The interface draws on Augma's reality overlays, round app controls and floating routes, rebuilt as interactive SVG.

Display settings and volume are saved in the current browser; notifications and scene progress last only for this session. If you switch browser tabs while sound is playing, it pauses and does not resume on its own.

## Voice commands and the DeepSeek assistant

Click the microphone at the top left to open voice commands. In Chrome, Edge and Safari, click Start voice recognition, say a command such as "open the map" or "scan the space", then click Finish and run; each recording lasts up to about 12 seconds. The browser asks for the microphone the first time, and recognizes speech itself, possibly through its vendor's online service. In other browsers, type a command or click an example. Commands are first matched locally by rules.

After you add your own DeepSeek API key under Settings → DeepSeek assistant, phrases and questions the local rules miss go to the assistant. It answers in a sentence or two, shown in the panel and read aloud in the current language, or runs one of the demo's actions, whose result the device announces. The request, with the last few exchanges, goes straight from the browser to DeepSeek, and calls may be charged; see the [official pricing](https://api-docs.deepseek.com/quick_start/pricing/). The key stays in the current browser; remove it in Settings, since restoring defaults keeps it. The assistant cannot browse the web or read live data, and the places, weather and notifications in the demo are simulated.

## Keyboard shortcuts

While focus is outside a text field, single keys open apps and change the view:

| Key | Action |
| --- | --- |
| `W` `A` `S` `C` `N` | Open Weather, Sound, Space, Camera or Navigation; press again to close |
| `Shift+N` | Notifications |
| `,` | Settings |
| `H` `D` `M` `F` | Show or hide the HUD, toggle dark view, mirror view, full screen |
| `V` | Start or stop a voice command; opens the voice command panel where the browser has no speech recognition |
| `?` | View and customize all shortcuts |
| `Esc` | Close the current panel |

Every default is a single key, at most with Shift. Browsers, operating systems and other apps' global hotkeys always add ⌘, Ctrl or Alt, so the defaults cannot collide with them, and keys pressed in text fields, dropdowns and dialogs never trigger them. Press `?`, or choose View and customize under Settings → Keyboard shortcuts, to record a new key for any action or clear it; Device and focus mode start unassigned. Recording rejects combinations the browser or system owns (⌘/Ctrl with a key, ⌘/Ctrl+Shift with a key, Windows key combinations, function keys such as F5), input method switches such as Ctrl+Space, and keys that operate the page such as Tab, Enter and the arrows. Common global hotkeys, such as the WeChat and QQ screenshot keys, Alfred and Raycast launchers and VoiceOver's ⌃⌥, can still be saved, with a note that those apps may catch them first while running. When a key already belongs to another action, press it again to move it; the other action is left unassigned.

Turn single-key shortcuts off in Settings if they get in the way of a screen reader or voice input; Esc still closes panels. Custom keys are kept in the current browser, and restoring defaults resets them too.

## Optional view effects

System menu → Settings → View effects at the top right has three independent switches, saved automatically:

- **Scene backdrop** (on by default): without the camera, the current space scene is drawn in an anime style with an AR layer on top. Sky Garden is a clear sky with cumulus clouds and a floating island crowned by a spire; City Stroll is a skyline at dusk with a lattice tower and a sky train; dark view turns them into a starry night and a neon night. A hexagon AR grid spreads over the ground with rings rippling out, data shards drift upward, and a scan line sweeps the city. Far, middle and near layers are blurred by depth, and the sun throws a lens flare. Switching scenes in Space fades the background across; turn it off for the plain gray background.
- **Depth motion** (off by default): moving the mouse shifts the scene backdrop layer by layer, and gives spatial layers and floating windows a subtle parallax and perspective; an opening window fades in and comes into focus while the scene, map and camera backgrounds blur slightly. Touch screens keep the entrance animation but nothing follows your finger, so scrolling and tapping stay easy.
- **Curved view** (off by default): the top and bottom white lines become shallow arcs, and the nine round icons at the bottom line up along the arc. It works on its own, without depth motion.

When the system's reduced motion setting is on, depth motion and the backdrop's animation pause, while the still scene and the curved look stay. Hiding the HUD, putting the device on standby, entering spatial AR or switching to the background also pause depth motion. Restoring defaults turns the scene backdrop on and the other two effects off.

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
