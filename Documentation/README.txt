Necropoly Graveyard Statues
Maciej EmacEArt
================================================================

HOW TO ADD IT TO YOUR PROJECT
  Copy the CONTENTS of this pack (Prefabs, Meshes, Materials, Textures,
  Scenes, Documentation and EA_Shared.material) into the root of your Godot
  project, so that the folders land at res://Prefabs, res://Meshes and so on.
  The scenes point at those paths for their meshes, material and texture.
  The pack is self-contained and does not require any plugins or add-ons.

WHAT IS WHERE
  Prefabs/        ready-to-use object scenes (.scn) -- these are
                  what you instance in your own scenes
  Meshes/         meshes (.mesh), plus the source models as .gltf. Every
                  .gltf has a .bin file of the same name beside it - copy
                  the pair together or the model opens empty
  Materials/      the extra materials; the shared one, EA_Shared.material,
                  sits in the pack root
  Textures/       textures
  Scenes/         showcase demo scene
  Documentation/  this file, license, contents list

HOW TO USE
  Drag a .scn file from Prefabs/ into your scene, or use
  "Instantiate Child Scene". Every object already comes with its
  mesh, material and collision shape.

RECOLOURING THE WHOLE PACK
  The pack uses one shared material with a single palette texture.
  Replace the texture in Textures/ and every object changes at once.
  The .gltf source models use that same palette file, so they change with it.

TESTED ON
  Godot 4.7.1

LICENSE
  EmacEArt Asset License
  See LICENSE.txt in this folder.

CONTACT
  Website: emaceart.dev
  Discord: https://discord.com/invite/ctXaf5Ftqw

================================================================
