// Ghostty's terminfo entry.
//
// Translated from ghostty/src/terminfo/ghostty.zig. The capability list and its
// commentary are carried over verbatim and in source order.
module terminfo

// ghostty_terminfo is Ghostty's terminfo entry.
pub const ghostty_terminfo = Source{
	names: [
		'xterm-ghostty',
		'ghostty',
		'Ghostty',
	]
	capabilities: [
		// automatic right margin -- when reaching the end of a line, text is
		// wrapped to the next line.
		Capability{ name: 'am', value: CapabilityValue.boolean() },

		// background color erase -- screen is erased with the background color
		Capability{ name: 'bce', value: CapabilityValue.boolean() },

		// terminal can change color definitions, i.e. we can change the color
		// palette.
		Capability{ name: 'ccc', value: CapabilityValue.boolean() },

		// supports changing the window title.
		Capability{ name: 'hs', value: CapabilityValue.boolean() },

		// terminal has a meta key
		Capability{ name: 'km', value: CapabilityValue.boolean() },

		// terminal will not echo input on the screen on its own
		Capability{ name: 'mc5i', value: CapabilityValue.boolean() },

		// safe to move (move what?) while in insert/standout mode. (???)
		Capability{ name: 'mir', value: CapabilityValue.boolean() },
		Capability{ name: 'msgr', value: CapabilityValue.boolean() },

		// no pad character (???)
		Capability{ name: 'npc', value: CapabilityValue.boolean() },

		// newline ignored after 80 cols (???)
		Capability{ name: 'xenl', value: CapabilityValue.boolean() },

		// Terminal supports default colors
		Capability{ name: 'AX', value: CapabilityValue.boolean() },

		// Tmux "truecolor" mode. Other programs also use this to detect
		// if the terminal supports "truecolor". This means that the terminal
		// can display 24-bit RGB colors.
		Capability{ name: 'Tc', value: CapabilityValue.boolean() },

		// Colored underlines. https://sw.kovidgoyal.net/kitty/underlines/
		Capability{ name: 'Su', value: CapabilityValue.boolean() },

		// Terminal supports a number of xterm extensions
		Capability{ name: 'XT', value: CapabilityValue.boolean() },

		// Full keyboard support using Kitty's keyboard protocol:
		// https://sw.kovidgoyal.net/kitty/keyboard-protocol/
		Capability{ name: 'fullkbd', value: CapabilityValue.boolean() },

		// Number of colors in the color palette.
		Capability{ name: 'colors', value: CapabilityValue.numeric(256) },

		// Number of columns in a line. Our terminal is variable width on
		// Window resize but this appears to just be the value set by most
		// terminals.
		Capability{ name: 'cols', value: CapabilityValue.numeric(80) },

		// Initial tabstop interval.
		Capability{ name: 'it', value: CapabilityValue.numeric(8) },

		// Number of lines on a page. Similar to cols this is variable width
		// but this appears to be the value set by most terminals.
		Capability{ name: 'lines', value: CapabilityValue.numeric(24) },

		// Number of color pairs on the screen.
		Capability{ name: 'pairs', value: CapabilityValue.numeric(32767) },

		// Alternate character set. This is the VT100 alternate character set.
		// I don't know what the value means, I copied this from Kitty and
		// verified with some other terminals (looks similar).
		Capability{ name: 'acsc', value: CapabilityValue.string('++\\,\\,--..00``aaffgghhiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz{{||}}~~') },

		// Curly, dashed, etc underlines
		Capability{ name: 'Smulx', value: CapabilityValue.string('\\E[4:%p1%dm') },

		// Colored underlines
		Capability{ name: 'Setulc', value: CapabilityValue.string('\\E[58:2::%p1%{65536}%/%d:%p1%{256}%/%{255}%&%d:%p1%{255}%&%d%;m') },

		// Cursor styles
		Capability{ name: 'Ss', value: CapabilityValue.string('\\E[%p1%d q') },

		// Cursor style reset
		Capability{ name: 'Se', value: CapabilityValue.string('\\E[2 q') },

		// OSC 52 Clipboard
		Capability{ name: 'Ms', value: CapabilityValue.string('\\E]52;%p1%s;%p2%s\\007') },

		// Synchronized output
		Capability{ name: 'Sync', value: CapabilityValue.string('\\E[?2026%?%p1%{1}%-%tl%eh%;') },

		// Bracketed paste mode
		Capability{ name: 'BD', value: CapabilityValue.string('\\E[?2004l') },
		Capability{ name: 'BE', value: CapabilityValue.string('\\E[?2004h') },
		// Bracketed paste start/end
		Capability{ name: 'PS', value: CapabilityValue.string('\\E[200~') },
		Capability{ name: 'PE', value: CapabilityValue.string('\\E[201~') },

		// Mouse
		Capability{ name: 'XM', value: CapabilityValue.string('\\E[?1006;1000%?%p1%{1}%=%th%el%;') },
		Capability{ name: 'xm', value: CapabilityValue.string('\\E[<%i%p3%d;%p1%d;%p2%d;%?%p4%tM%em%;') },

		// Secondary device attributes request / response
		Capability{ name: 'RV', value: CapabilityValue.string('\\E[>c') },
		Capability{ name: 'rv', value: CapabilityValue.string('\\E\\\\[[0-9]+;[0-9]+;[0-9]+c') },

		// XTVERSION
		Capability{ name: 'XR', value: CapabilityValue.string('\\E[>0q') },
		Capability{ name: 'xr', value: CapabilityValue.string('\\EP>\\\\|[ -~]+a\\E\\\\') },

		// DECSLRM (Left/Right Margins)
		Capability{ name: 'Enmg', value: CapabilityValue.string('\\E[?69h') },
		Capability{ name: 'Dsmg', value: CapabilityValue.string('\\E[?69l') },
		Capability{ name: 'Clmg', value: CapabilityValue.string('\\E[s') },
		Capability{ name: 'Cmg', value: CapabilityValue.string('\\E[%i%p1%d;%p2%ds') },

		// Clear screen. E3 is the extension to clear scrollback
		Capability{ name: 'clear', value: CapabilityValue.string('\\E[H\\E[2J') },
		Capability{ name: 'E3', value: CapabilityValue.string('\\E[3J') },

		// Focus reporting. Introduced in ncurses 6.4-20231028
		Capability{ name: 'fe', value: CapabilityValue.string('\\E[?1004h') },
		Capability{ name: 'fd', value: CapabilityValue.string('\\E[?1004l') },
		Capability{ name: 'kxIN', value: CapabilityValue.string('\\E[I') },
		Capability{ name: 'kxOUT', value: CapabilityValue.string('\\E[O') },

		// These are all capabilities that should be pretty straightforward
		// and map to input sequences.
		Capability{ name: 'bel', value: CapabilityValue.string('^G') },
		Capability{ name: 'blink', value: CapabilityValue.string('\\E[5m') },
		Capability{ name: 'bold', value: CapabilityValue.string('\\E[1m') },
		Capability{ name: 'cbt', value: CapabilityValue.string('\\E[Z') },
		Capability{ name: 'civis', value: CapabilityValue.string('\\E[?25l') },
		Capability{ name: 'cnorm', value: CapabilityValue.string('\\E[?12l\\E[?25h') },
		Capability{ name: 'cr', value: CapabilityValue.string('\\r') },
		Capability{ name: 'csr', value: CapabilityValue.string('\\E[%i%p1%d;%p2%dr') },
		Capability{ name: 'cub', value: CapabilityValue.string('\\E[%p1%dD') },
		Capability{ name: 'cub1', value: CapabilityValue.string('^H') },
		Capability{ name: 'cud', value: CapabilityValue.string('\\E[%p1%dB') },
		Capability{ name: 'cud1', value: CapabilityValue.string('^J') },
		Capability{ name: 'cuf', value: CapabilityValue.string('\\E[%p1%dC') },
		Capability{ name: 'cuf1', value: CapabilityValue.string('\\E[C') },
		Capability{ name: 'cup', value: CapabilityValue.string('\\E[%i%p1%d;%p2%dH') },
		Capability{ name: 'cuu', value: CapabilityValue.string('\\E[%p1%dA') },
		Capability{ name: 'cuu1', value: CapabilityValue.string('\\E[A') },
		Capability{ name: 'cvvis', value: CapabilityValue.string('\\E[?12;25h') },
		Capability{ name: 'dch', value: CapabilityValue.string('\\E[%p1%dP') },
		Capability{ name: 'dch1', value: CapabilityValue.string('\\E[P') },
		Capability{ name: 'dim', value: CapabilityValue.string('\\E[2m') },
		Capability{ name: 'dl', value: CapabilityValue.string('\\E[%p1%dM') },
		Capability{ name: 'dl1', value: CapabilityValue.string('\\E[M') },
		Capability{ name: 'dsl', value: CapabilityValue.string('\\E]2;\\007') },
		Capability{ name: 'ech', value: CapabilityValue.string('\\E[%p1%dX') },
		Capability{ name: 'ed', value: CapabilityValue.string('\\E[J') },
		Capability{ name: 'el', value: CapabilityValue.string('\\E[K') },
		Capability{ name: 'el1', value: CapabilityValue.string('\\E[1K') },
		Capability{ name: 'flash', value: CapabilityValue.string('\\E[?5h$<100/>\\E[?5l') },
		Capability{ name: 'fsl', value: CapabilityValue.string('^G') },
		Capability{ name: 'home', value: CapabilityValue.string('\\E[H') },
		Capability{ name: 'hpa', value: CapabilityValue.string('\\E[%i%p1%dG') },
		Capability{ name: 'ht', value: CapabilityValue.string('^I') },
		Capability{ name: 'hts', value: CapabilityValue.string('\\EH') },
		Capability{ name: 'ich', value: CapabilityValue.string('\\E[%p1%d@') },
		Capability{ name: 'ich1', value: CapabilityValue.string('\\E[@') },
		Capability{ name: 'il', value: CapabilityValue.string('\\E[%p1%dL') },
		Capability{ name: 'il1', value: CapabilityValue.string('\\E[L') },
		Capability{ name: 'ind', value: CapabilityValue.string('\\n') },
		Capability{ name: 'indn', value: CapabilityValue.string('\\E[%p1%dS') },
		Capability{ name: 'initc', value: CapabilityValue.string('\\E]4;%p1%d;rgb\\:%p2%{255}%*%{1000}%/%2.2X/%p3%{255}%*%{1000}%/%2.2X/%p4%{255}%*%{1000}%/%2.2X\\E\\\\') },
		Capability{ name: 'invis', value: CapabilityValue.string('\\E[8m') },
		Capability{ name: 'oc', value: CapabilityValue.string('\\E]104\\007') },
		Capability{ name: 'op', value: CapabilityValue.string('\\E[39;49m') },
		Capability{ name: 'rc', value: CapabilityValue.string('\\E8') },
		Capability{ name: 'rep', value: CapabilityValue.string('%p1%c\\E[%p2%{1}%-%db') },
		Capability{ name: 'rev', value: CapabilityValue.string('\\E[7m') },
		Capability{ name: 'ri', value: CapabilityValue.string('\\EM') },
		Capability{ name: 'rin', value: CapabilityValue.string('\\E[%p1%dT') },
		Capability{ name: 'ritm', value: CapabilityValue.string('\\E[23m') },
		Capability{ name: 'rmacs', value: CapabilityValue.string('\\E(B') },
		Capability{ name: 'rmam', value: CapabilityValue.string('\\E[?7l') },
		Capability{ name: 'rmcup', value: CapabilityValue.string('\\E[?1049l') },
		Capability{ name: 'rmir', value: CapabilityValue.string('\\E[4l') },
		Capability{ name: 'rmkx', value: CapabilityValue.string('\\E[?1l\\E>') },
		Capability{ name: 'rmso', value: CapabilityValue.string('\\E[27m') },
		Capability{ name: 'rmul', value: CapabilityValue.string('\\E[24m') },
		Capability{ name: 'rmxx', value: CapabilityValue.string('\\E[29m') },
		Capability{ name: 'setab', value: CapabilityValue.string('\\E[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m') },
		Capability{ name: 'setaf', value: CapabilityValue.string('\\E[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m') },
		Capability{ name: 'setrgbb', value: CapabilityValue.string('\\E[48:2:%p1%d:%p2%d:%p3%dm') },
		Capability{ name: 'setrgbf', value: CapabilityValue.string('\\E[38:2:%p1%d:%p2%d:%p3%dm') },
		Capability{ name: 'sgr', value: CapabilityValue.string('%?%p9%t\\E(0%e\\E(B%;\\E[0%?%p6%t;1%;%?%p2%t;4%;%?%p1%p3%|%t;7%;%?%p4%t;5%;%?%p7%t;8%;m') },
		Capability{ name: 'sgr0', value: CapabilityValue.string('\\E(B\\E[m') },
		Capability{ name: 'sitm', value: CapabilityValue.string('\\E[3m') },
		Capability{ name: 'smacs', value: CapabilityValue.string('\\E(0') },
		Capability{ name: 'smam', value: CapabilityValue.string('\\E[?7h') },
		Capability{ name: 'smcup', value: CapabilityValue.string('\\E[?1049h') },
		Capability{ name: 'smir', value: CapabilityValue.string('\\E[4h') },
		Capability{ name: 'smkx', value: CapabilityValue.string('\\E[?1h\\E=') },
		Capability{ name: 'smso', value: CapabilityValue.string('\\E[7m') },
		Capability{ name: 'smul', value: CapabilityValue.string('\\E[4m') },
		Capability{ name: 'smxx', value: CapabilityValue.string('\\E[9m') },
		Capability{ name: 'tbc', value: CapabilityValue.string('\\E[3g') },
		Capability{ name: 'tsl', value: CapabilityValue.string('\\E]2;') },
		Capability{ name: 'u6', value: CapabilityValue.string('\\E[%i%d;%dR') },
		Capability{ name: 'u7', value: CapabilityValue.string('\\E[6n') },
		Capability{ name: 'u8', value: CapabilityValue.string('\\E[?%[;0123456789]c') },
		Capability{ name: 'u9', value: CapabilityValue.string('\\E[c') },
		Capability{ name: 'vpa', value: CapabilityValue.string('\\E[%i%p1%dd') },

		//-----------------------------------------------------------
		// Completely unvalidated entries that are blindly copied from
		// other terminals (Kitty, Wezterm, Alacritty) and may or may not
		// actually work with Ghostty. todo is to validate these!

		Capability{ name: 'kDC', value: CapabilityValue.string('\\E[3;2~') },
		Capability{ name: 'kDC3', value: CapabilityValue.string('\\E[3;3~') },
		Capability{ name: 'kDC4', value: CapabilityValue.string('\\E[3;4~') },
		Capability{ name: 'kDC5', value: CapabilityValue.string('\\E[3;5~') },
		Capability{ name: 'kDC6', value: CapabilityValue.string('\\E[3;6~') },
		Capability{ name: 'kDC7', value: CapabilityValue.string('\\E[3;7~') },
		Capability{ name: 'kDN', value: CapabilityValue.string('\\E[1;2B') },
		Capability{ name: 'kDN3', value: CapabilityValue.string('\\E[1;3B') },
		Capability{ name: 'kDN4', value: CapabilityValue.string('\\E[1;4B') },
		Capability{ name: 'kDN5', value: CapabilityValue.string('\\E[1;5B') },
		Capability{ name: 'kDN6', value: CapabilityValue.string('\\E[1;6B') },
		Capability{ name: 'kDN7', value: CapabilityValue.string('\\E[1;7B') },
		Capability{ name: 'kEND', value: CapabilityValue.string('\\E[1;2F') },
		Capability{ name: 'kEND3', value: CapabilityValue.string('\\E[1;3F') },
		Capability{ name: 'kEND4', value: CapabilityValue.string('\\E[1;4F') },
		Capability{ name: 'kEND5', value: CapabilityValue.string('\\E[1;5F') },
		Capability{ name: 'kEND6', value: CapabilityValue.string('\\E[1;6F') },
		Capability{ name: 'kEND7', value: CapabilityValue.string('\\E[1;7F') },
		Capability{ name: 'kHOM', value: CapabilityValue.string('\\E[1;2H') },
		Capability{ name: 'kHOM3', value: CapabilityValue.string('\\E[1;3H') },
		Capability{ name: 'kHOM4', value: CapabilityValue.string('\\E[1;4H') },
		Capability{ name: 'kHOM5', value: CapabilityValue.string('\\E[1;5H') },
		Capability{ name: 'kHOM6', value: CapabilityValue.string('\\E[1;6H') },
		Capability{ name: 'kHOM7', value: CapabilityValue.string('\\E[1;7H') },
		Capability{ name: 'kIC', value: CapabilityValue.string('\\E[2;2~') },
		Capability{ name: 'kIC3', value: CapabilityValue.string('\\E[2;3~') },
		Capability{ name: 'kIC4', value: CapabilityValue.string('\\E[2;4~') },
		Capability{ name: 'kIC5', value: CapabilityValue.string('\\E[2;5~') },
		Capability{ name: 'kIC6', value: CapabilityValue.string('\\E[2;6~') },
		Capability{ name: 'kIC7', value: CapabilityValue.string('\\E[2;7~') },
		Capability{ name: 'kLFT', value: CapabilityValue.string('\\E[1;2D') },
		Capability{ name: 'kLFT3', value: CapabilityValue.string('\\E[1;3D') },
		Capability{ name: 'kLFT4', value: CapabilityValue.string('\\E[1;4D') },
		Capability{ name: 'kLFT5', value: CapabilityValue.string('\\E[1;5D') },
		Capability{ name: 'kLFT6', value: CapabilityValue.string('\\E[1;6D') },
		Capability{ name: 'kLFT7', value: CapabilityValue.string('\\E[1;7D') },
		Capability{ name: 'kNXT', value: CapabilityValue.string('\\E[6;2~') },
		Capability{ name: 'kNXT3', value: CapabilityValue.string('\\E[6;3~') },
		Capability{ name: 'kNXT4', value: CapabilityValue.string('\\E[6;4~') },
		Capability{ name: 'kNXT5', value: CapabilityValue.string('\\E[6;5~') },
		Capability{ name: 'kNXT6', value: CapabilityValue.string('\\E[6;6~') },
		Capability{ name: 'kNXT7', value: CapabilityValue.string('\\E[6;7~') },
		Capability{ name: 'kPRV', value: CapabilityValue.string('\\E[5;2~') },
		Capability{ name: 'kPRV3', value: CapabilityValue.string('\\E[5;3~') },
		Capability{ name: 'kPRV4', value: CapabilityValue.string('\\E[5;4~') },
		Capability{ name: 'kPRV5', value: CapabilityValue.string('\\E[5;5~') },
		Capability{ name: 'kPRV6', value: CapabilityValue.string('\\E[5;6~') },
		Capability{ name: 'kPRV7', value: CapabilityValue.string('\\E[5;7~') },
		Capability{ name: 'kRIT', value: CapabilityValue.string('\\E[1;2C') },
		Capability{ name: 'kRIT3', value: CapabilityValue.string('\\E[1;3C') },
		Capability{ name: 'kRIT4', value: CapabilityValue.string('\\E[1;4C') },
		Capability{ name: 'kRIT5', value: CapabilityValue.string('\\E[1;5C') },
		Capability{ name: 'kRIT6', value: CapabilityValue.string('\\E[1;6C') },
		Capability{ name: 'kRIT7', value: CapabilityValue.string('\\E[1;7C') },
		Capability{ name: 'kUP', value: CapabilityValue.string('\\E[1;2A') },
		Capability{ name: 'kUP3', value: CapabilityValue.string('\\E[1;3A') },
		Capability{ name: 'kUP4', value: CapabilityValue.string('\\E[1;4A') },
		Capability{ name: 'kUP5', value: CapabilityValue.string('\\E[1;5A') },
		Capability{ name: 'kUP6', value: CapabilityValue.string('\\E[1;6A') },
		Capability{ name: 'kUP7', value: CapabilityValue.string('\\E[1;7A') },
		Capability{ name: 'kbs', value: CapabilityValue.string('^?') },
		Capability{ name: 'kcbt', value: CapabilityValue.string('\\E[Z') },
		Capability{ name: 'kcub1', value: CapabilityValue.string('\\EOD') },
		Capability{ name: 'kcud1', value: CapabilityValue.string('\\EOB') },
		Capability{ name: 'kcuf1', value: CapabilityValue.string('\\EOC') },
		Capability{ name: 'kcuu1', value: CapabilityValue.string('\\EOA') },
		Capability{ name: 'kdch1', value: CapabilityValue.string('\\E[3~') },
		Capability{ name: 'kend', value: CapabilityValue.string('\\EOF') },
		Capability{ name: 'kent', value: CapabilityValue.string('\\EOM') },
		Capability{ name: 'kf1', value: CapabilityValue.string('\\EOP') },
		Capability{ name: 'kf10', value: CapabilityValue.string('\\E[21~') },
		Capability{ name: 'kf11', value: CapabilityValue.string('\\E[23~') },
		Capability{ name: 'kf12', value: CapabilityValue.string('\\E[24~') },
		Capability{ name: 'kf13', value: CapabilityValue.string('\\E[1;2P') },
		Capability{ name: 'kf14', value: CapabilityValue.string('\\E[1;2Q') },
		Capability{ name: 'kf15', value: CapabilityValue.string('\\E[1;2R') },
		Capability{ name: 'kf16', value: CapabilityValue.string('\\E[1;2S') },
		Capability{ name: 'kf17', value: CapabilityValue.string('\\E[15;2~') },
		Capability{ name: 'kf18', value: CapabilityValue.string('\\E[17;2~') },
		Capability{ name: 'kf19', value: CapabilityValue.string('\\E[18;2~') },
		Capability{ name: 'kf2', value: CapabilityValue.string('\\EOQ') },
		Capability{ name: 'kf20', value: CapabilityValue.string('\\E[19;2~') },
		Capability{ name: 'kf21', value: CapabilityValue.string('\\E[20;2~') },
		Capability{ name: 'kf22', value: CapabilityValue.string('\\E[21;2~') },
		Capability{ name: 'kf23', value: CapabilityValue.string('\\E[23;2~') },
		Capability{ name: 'kf24', value: CapabilityValue.string('\\E[24;2~') },
		Capability{ name: 'kf25', value: CapabilityValue.string('\\E[1;5P') },
		Capability{ name: 'kf26', value: CapabilityValue.string('\\E[1;5Q') },
		Capability{ name: 'kf27', value: CapabilityValue.string('\\E[1;5R') },
		Capability{ name: 'kf28', value: CapabilityValue.string('\\E[1;5S') },
		Capability{ name: 'kf29', value: CapabilityValue.string('\\E[15;5~') },
		Capability{ name: 'kf3', value: CapabilityValue.string('\\EOR') },
		Capability{ name: 'kf30', value: CapabilityValue.string('\\E[17;5~') },
		Capability{ name: 'kf31', value: CapabilityValue.string('\\E[18;5~') },
		Capability{ name: 'kf32', value: CapabilityValue.string('\\E[19;5~') },
		Capability{ name: 'kf33', value: CapabilityValue.string('\\E[20;5~') },
		Capability{ name: 'kf34', value: CapabilityValue.string('\\E[21;5~') },
		Capability{ name: 'kf35', value: CapabilityValue.string('\\E[23;5~') },
		Capability{ name: 'kf36', value: CapabilityValue.string('\\E[24;5~') },
		Capability{ name: 'kf37', value: CapabilityValue.string('\\E[1;6P') },
		Capability{ name: 'kf38', value: CapabilityValue.string('\\E[1;6Q') },
		Capability{ name: 'kf39', value: CapabilityValue.string('\\E[1;6R') },
		Capability{ name: 'kf4', value: CapabilityValue.string('\\EOS') },
		Capability{ name: 'kf40', value: CapabilityValue.string('\\E[1;6S') },
		Capability{ name: 'kf41', value: CapabilityValue.string('\\E[15;6~') },
		Capability{ name: 'kf42', value: CapabilityValue.string('\\E[17;6~') },
		Capability{ name: 'kf43', value: CapabilityValue.string('\\E[18;6~') },
		Capability{ name: 'kf44', value: CapabilityValue.string('\\E[19;6~') },
		Capability{ name: 'kf45', value: CapabilityValue.string('\\E[20;6~') },
		Capability{ name: 'kf46', value: CapabilityValue.string('\\E[21;6~') },
		Capability{ name: 'kf47', value: CapabilityValue.string('\\E[23;6~') },
		Capability{ name: 'kf48', value: CapabilityValue.string('\\E[24;6~') },
		Capability{ name: 'kf49', value: CapabilityValue.string('\\E[1;3P') },
		Capability{ name: 'kf5', value: CapabilityValue.string('\\E[15~') },
		Capability{ name: 'kf50', value: CapabilityValue.string('\\E[1;3Q') },
		Capability{ name: 'kf51', value: CapabilityValue.string('\\E[1;3R') },
		Capability{ name: 'kf52', value: CapabilityValue.string('\\E[1;3S') },
		Capability{ name: 'kf53', value: CapabilityValue.string('\\E[15;3~') },
		Capability{ name: 'kf54', value: CapabilityValue.string('\\E[17;3~') },
		Capability{ name: 'kf55', value: CapabilityValue.string('\\E[18;3~') },
		Capability{ name: 'kf56', value: CapabilityValue.string('\\E[19;3~') },
		Capability{ name: 'kf57', value: CapabilityValue.string('\\E[20;3~') },
		Capability{ name: 'kf58', value: CapabilityValue.string('\\E[21;3~') },
		Capability{ name: 'kf59', value: CapabilityValue.string('\\E[23;3~') },
		Capability{ name: 'kf6', value: CapabilityValue.string('\\E[17~') },
		Capability{ name: 'kf60', value: CapabilityValue.string('\\E[24;3~') },
		Capability{ name: 'kf61', value: CapabilityValue.string('\\E[1;4P') },
		Capability{ name: 'kf62', value: CapabilityValue.string('\\E[1;4Q') },
		Capability{ name: 'kf63', value: CapabilityValue.string('\\E[1;4R') },
		Capability{ name: 'kf7', value: CapabilityValue.string('\\E[18~') },
		Capability{ name: 'kf8', value: CapabilityValue.string('\\E[19~') },
		Capability{ name: 'kf9', value: CapabilityValue.string('\\E[20~') },
		Capability{ name: 'khome', value: CapabilityValue.string('\\EOH') },
		Capability{ name: 'kich1', value: CapabilityValue.string('\\E[2~') },
		Capability{ name: 'kind', value: CapabilityValue.string('\\E[1;2B') },
		Capability{ name: 'kmous', value: CapabilityValue.string('\\E[<') },
		Capability{ name: 'knp', value: CapabilityValue.string('\\E[6~') },
		Capability{ name: 'kpp', value: CapabilityValue.string('\\E[5~') },
		Capability{ name: 'kri', value: CapabilityValue.string('\\E[1;2A') },
		Capability{ name: 'rs1', value: CapabilityValue.string('\\E]\\E\\\\\\Ec') },
		Capability{ name: 'sc', value: CapabilityValue.string('\\E7') },
	]
}
