// The env.log host from Ghostty's example/wasm-{key-encode,sgr}/index.html.
// Emscripten supplies its own compiler runtime imports alongside this API.
addToLibrary({
  log: function(ptr, len) {
    const text = new TextDecoder().decode(HEAPU8.subarray(ptr, ptr + len));
    if (Module['ghosttyLog']) Module['ghosttyLog'](text);
    else console.log('[wasm]', text);
  }
});
