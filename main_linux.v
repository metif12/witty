module main

// Linux entry point. Translated from ghostty's src/main_ghostty.zig main():
// after global state and CLI actions (handled elsewhere), it creates the
// core App, initializes the apprt runtime App with it, and runs the GUI
// event loop. On Linux the runtime is GTK.

import core
import apprt.gtk

fn main() {
	// Create our app state.
	mut app := core.App.create() or {
		eprintln('failed to create app: ${err}')
		return
	}
	defer {
		app.destroy()
	}

	// Create our runtime app.
	mut app_runtime := gtk.App{}
	app_runtime.init(app) or {
		eprintln('failed to initialize runtime app: ${err}')
		return
	}
	defer {
		app_runtime.terminate()
	}

	// Ghostty starts the quit timer here if the apprt exposes it
	// (`@hasDecl(apprt.App, "startQuitTimer")`). The GTK App adapter does
	// not expose it, so like the comptime check being false, we skip it.

	// Run the GUI event loop.
	app_runtime.run() or {
		eprintln('runtime app failed: ${err}')
		return
	}
}
