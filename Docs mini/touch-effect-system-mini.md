# Touch Effect System (Mini) Docs

[Overview](#overview) | [Setup](#setup) | [Core Components](#core-components) | [Contacts](#contacts)

*Developed by [© Octanta Studio](https://www.octantastudio.com/en/) 2024.*

---

## Overview

**Touch Effect System Mini** is an easy-to-use Unity asset tailored for touch effects. It's suitable for point-and-click games, as well as any other projects that require touch visualization. The demo version includes basic One-Touch effects to use. For a more feature-rich system, explore [this advanced asset](https://u3d.as/3C7x).

### Technical details

- Developed using Unity 6000.0.42f1.
- Tested on mid-range Android devices (API 24+) and Windows 10/11 PCs with consistent performance.
- The asset relies only on standard Unity components and classes, with no third-party dependencies required.

### Free vs Full version

| Feature | Free Version | [Full Version](https://u3d.as/3C7x) |
|---|:---:|:---:|
| OneTouch basic effects with easy drag-and-drop prefab setup | ✅ | ✅ |
| Cross-platform input support | ✅ | ✅ |
| Universal rendering and layering system | ✅ | ✅ |
| Adaptability to screen resolutions and devices | ❌ | ✅ |
| Extensive shader library (25+ variants) | ❌ | ✅ |
| Trail system with advanced controls | ❌ | ✅ |
| Sprite-based particle system (SparkleSpawner) | ❌ | ✅ |
| Preview system (ParticlePreviewPlayer) | ❌ | ✅ |
| Playback Conditions support | ❌ | ✅ |
| Logic for holding the effect | ❌ | ✅ |
| Technical support and custom development services | ❌ | ✅ |

---

## Setup

![Setup](https://octanta-studio.gitbook.io/touch-effect-system-for-unity-ua/~gitbook/image?url=https%3A%2F%2F2168082229-files.gitbook.io%2F%7E%2Ffiles%2Fv0%2Fb%2Fgitbook-x-prod.appspot.com%2Fo%2Fspaces%252FCr5sN2zDHwaviOprY28q%252Fuploads%252FDYtBqUeHPTxQ6wKSWp2I%252Fsetup%2520%282%29.png%3Falt%3Dmedia%26token%3De592a423-e771-4506-8be5-c9b6bdd2c830&width=400&dpr=3&quality=100&sign=16cc429664d04fb6163f2a3487376c7f&sv=3)

1. Import the asset and locate the **TouchEffects** prefabs folder:
   `Assets → OctantaStudio → TouchEffectSystem → Prefabs → TouchEffects`
2. Add an effect prefab to your Canvas, for example, the **TouchCircle** for simple touch response.
3. Assign **Target Canvas** in the component, or it will be auto-detected.
4. **Check that the Input Controller component inside the prefab matches your Input System (Old/New).** See [Core Components → Input Controller](#input-controllercs).

The asset is ready to use immediately after Canvas setup. Run the scene to test.

### Recommended steps

5. **Unpack the prefab.**
6. Open the **Glow Material** set in the `TouchGlowUI` component to experiment with the effect color or other available settings. After adjusting, restart the scene to test the touch visual.
7. Use **DemoScene** to explore all available prefabs. Run the scene, enable and disable the prefabs on the Canvas, and watch the touch effects in the Game window.

---

## Core Components

### Input Controller.cs

A cross-platform input system with automatic configuration for desktops and mobile devices. Not intended for manual editing. Contains a public field to set the Input System. By default, the system is set up for the **Old Input Manager**. To fully switch, follow these steps:

- Open `Edit → Project Settings → Player → Configuration` and set **Active Input Handling** to New/Old.
  - For **New**: install the Input System Unity package.
  - For **Old**: delete this package.
  - Check the **EventSystem** on the scene to make sure it is set up correctly for the current input.
- Set `inputSystemType` to New/Old in the `InputController` component.

### TouchGlowUI.cs

Main system controller managing effect generation. Not intended for manual editing. Contains important references for assignment and public settings:

- **Target Canvas** - UI canvas on the scene for positioning and scaling.
- **Input Controller** - component reference.
- **Glow Material** - material created from shader for visual particle effect.
- **Point Prefab** - template GameObject for trail UI points.
- **Glow Lifetime** (1s) - how long each touch effect stays visible before fading.
- **Desktop Point Size** (120x120px) - dimensions of individual touch effects in pixels.

### Shaders

- `TouchPointCircle`, `TouchPointDiamond`, `TouchPointSquare`, `TouchPointTriangle`, `TouchPointPlus`, `TouchPointSparkle` - geometric shapes with customizable core, glow, and ring layers for one-touch.

Try generating your own touch effect using the system's capabilities and neural networks.
[Watch the YouTube tutorial on AI generation →](https://www.youtube.com/watch?v=vp_m3pRJC6w)

![UI Shader → Material → UI particle](https://octanta-studio.gitbook.io/touch-effect-system-for-unity-ua/~gitbook/image?url=https%3A%2F%2F2168082229-files.gitbook.io%2F%7E%2Ffiles%2Fv0%2Fb%2Fgitbook-x-prod.appspot.com%2Fo%2Fspaces%252FCr5sN2zDHwaviOprY28q%252Fuploads%252FYYn2uNquHYvFlU16MJKg%252FVFX%2520Toolkit.png%3Falt%3Dmedia%26token%3D057b7b86-2f08-4009-9e37-4d5ea691b265&width=400&dpr=3&quality=100&sign=c2b477746f2791f4ab7e7c8f8245ab1a&sv=3)

### TouchTextUI.cs

Additional controller managing TMP Text effect generation. Not intended for manual editing. Contains important references for assignment and public settings:

- **Target Canvas** - UI canvas on the scene for positioning and scaling.
- **Input Controller** - component reference.
- **Text Prefab** - template GameObject.
- **Font Asset**, **Font Style**, **Font Size** - basic text visual settings.
- **Main Sprite Asset** - to insert sprites into text.
- **Text Strings**, **Text Colors** - values and colors to choose from for randomization.
- **Appearance Animation** type (None/Radial/Directional).
- **Text Lifetime** (1s) - how long each touch effect stays visible before fading.
- **Min / Max Move Distance** (50/150px) - distance from touch where the effect begins and ends.

---

## Contacts

Need help? Contact us:

- **Email:** [octantastudio@gmail.com](mailto:octantastudio@gmail.com)
- **Discord:** join the Octanta Studio channel <https://discord.gg/6SPxKpFZFC> and use branch `to-developers`. We will provide an answer or create a special YouTube tutorial.

---

[Overview](#overview) | [Setup](#setup) | [Core Components](#core-components) | [Contacts](#contacts)

*Developed by [© Octanta Studio](https://www.octantastudio.com/en/) 2024.*
