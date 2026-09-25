module renderer

import macos

// Ghostty selects the renderer at compile time: renderer.Renderer is
// GenericRenderer(Metal) on Apple platforms. These aliases are the
// GraphicsAPI-dependent types of that instantiation.
pub type GraphicsAPI = MetalAPI
pub type GraphicsShaders = MetalShaders
pub type GraphicsFrameState = MetalFrameState
pub type GraphicsTexture = MetalTexture

// DisplayLink is macos.video.DisplayLink on macOS.
pub type DisplayLink = macos.CVDisplayLink

// The objc AutoreleasePool the renderer thread wraps its mailbox drain in.
pub type AutoreleasePool = macos.AutoreleasePool
