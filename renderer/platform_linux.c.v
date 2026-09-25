module renderer

// Ghostty selects the renderer at compile time: renderer.Renderer is
// GenericRenderer(OpenGL) on Linux. These aliases are the
// GraphicsAPI-dependent types of that instantiation.
pub type GraphicsAPI = OpenGLAPI
pub type GraphicsShaders = GLShaders
pub type GraphicsFrameState = GLFrameState
pub type GraphicsTexture = GLTexture

// DisplayLink is void outside macOS; the renderer's display link is never set.
pub struct DisplayLink {}

// There is no autorelease pool outside Darwin (`void` in the source).
pub struct AutoreleasePool {}
