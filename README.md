# Mine-imator with some new features

> [!WARNING]
> This fork of Mine-imator was made PURELY by an LLM, aside from the original Mine-imator code

This fork adds black and white depth map rendering to Mine-imator and maybe some other features if I'm unemployed enough to ask Claude to make them.

I'm sorry if I disappointed you with the information that this is vibe coded. I know that feeling. If you're someone that actually knows how to code and you want to unslopify this, be my guest.

## What this fork adds

Everything below is new compared to Mine-imator 2.0.2 Continuation Build 1.0.15 alpha 1. In the app, most of these settings are marked with a badge (DEPTH, RAYTRACING, HDR10, OVERKILL or CUSTOM), so you can tell them apart from the original ones.

### Render modes
- **Raytraced mode**: a new view mode (flame button next to Render, Shaded and Flat), plus a "Raytraced rendering" switch when exporting images and movies. It uses hardware ray tracing (DXR 1.1 on RT cores) for traced shadows, colored bounce light, reflections, specular highlights, point and spot lights, and glowing (emissive) blocks. Its settings are in the Raytracing category of the Render tab.
- **OVERKILL mode**: a path-traced view and export mode that makes lighting and reflections as realistic as possible. It has multi-bounce light, light sampled at every bounce, glossy reflections of reflections, Fresnel on every surface, and metals that tint their reflections. Its settings are in the OVERKILL category: samples, bounces, light samples, paths per frame, firefly clamp and Russian roulette.
- **Light through see-through objects**: in Raytraced and OVERKILL modes, shadows get lighter smoothly as an object becomes more transparent, instead of switching at 50% opacity. Stained glass colors the light that passes through it, and looks the same seen in a reflection as seen directly.
- **Graphics card chooser**: pick which graphics card Mine-imator uses (System default, High performance or a specific card) at the top of the Render tab. The change applies on the next start.

### Materials
- **PBR materials** category in the Render tab: uses the material and normal maps of your resource pack (LabPBR/SEUS), with normal map strength and roughness, metallic and reflectivity multipliers. Texture AO works in Raytraced mode. Blocks left on the default maps use the maps of their texture's resource pack.
- **Reflectiveness**: a new material value for objects, next to Metallic. It works in Render, Raytraced and OVERKILL modes.
- **Parallax**: blocks with height maps look 3D, with adjustable depth and self-shadowing. Works in Render and Raytraced modes.

### Depth map
- **Depth map (black & white)** render pass: renders a grayscale depth image, useful for things like ControlNet. Settings: Near distance, Far distance, Curve, Near is white, and Normal map detail, which adds the surface detail from PBR height maps.

### Export
- **HDR10 export** for images and movies. Images and PNG sequences are 16-bit PQ / Rec.2020 PNGs; MP4 and MOV are 10-bit HDR10 video. Peak brightness and Paper white are in the HDR10 render settings.
- **Export Minecraft model** (Render menu): exports the scene, or only the selected objects, as a Minecraft JSON model with its texture baked in. It can be saved as a ready-to-use resource pack with an item definition. Bent and turned parts keep their shape, using Minecraft's free element rotations (or only the classic 22.5° and 45° turns, for older versions).

### CUSTOM features
Features that weren't asked for by name but that made sense to add. They're marked with a CUSTOM badge:
- **Denoise** for ray tracing
- **Time limit per frame** for exports
- **Sky reflections**: how strongly the sky shows in reflections
- **Reflection bumpiness**: how much normal maps bend reflections, so very reflective bumpy blocks reflect cleanly instead of in patches
- **Firefly clamp** for Raytraced mode, which removes bright single-pixel speckles
- **Safe area guides** over the view
- **Render time estimate** in the viewport

### Other changes
- New logo and app icons.
- Developer mode no longer skips most blocks while loading, shows the debug overlay on every launch, or opens a test project at startup.
- Fixes: normal map strength now deepens bumps instead of flattening them; the picture no longer slowly dims after many samples in Raytraced and OVERKILL modes; reflections no longer point into the surface they come from.


<p align="center">
  <img src="https://www.mineimatorforums.com/uploads/monthly_2021_08/image.png.4699187f1f02be8222a5bf5100c1738f.png" width=800/>
  <br/>
  <br/>
  <img src="https://www.mineimatorforums.com/uploads/monthly_2023_03/336815532_programview.png.9212aa1f6d1bed63411408aa5e905ce0.png" width=800/>
</p>

Mine-imator is a 3D movie maker based on the sandbox game Minecraft, with over 10 million downloads since its launch in 2012. Version 2.0, the 10th anniversary update brings numerous additions including a new UI, new renderer, animation features, multiplatform support and 3D world importer.

Website and download: https://www.mineimator.com

The software is written using GameMaker Language and converted to a separate C++ environment using a custom built GML parser (CppGen). The final executable is built for Windows, Mac OS and Linux using the Qt framework, DirectX/OpenGL rendering and various other libraries.

You can open GmProject/Mine-imator.yyp directly in GameMaker on Windows (it may need to be converted), but to support all features you must build and run the C++ project. For full build instructions, see CppProject/BUILD.md.
