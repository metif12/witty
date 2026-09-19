module input

import strings

const binding_action_help_data = $embed_file('keybind_action_help.txt').to_string()

pub fn generated_action_help_data() string {
	return binding_action_help_data
}

// This module is a help generator for keybind actions documentation.
// It can generate documentation in different formats (plaintext for CLI,
// markdown for website) while maintaining consistent content.

// Format represents the output format for documentation.
pub enum Format as u8 {
	// Plain text output with indentation.
	plaintext
	// Markdown formatted output.
	markdown
}

// generate generates keybind actions documentation. V returns the accumulated
// text because its standard writer interface is not a shared module protocol.
pub fn generate(format Format, show_docs bool) string {
	entries := binding_action_help_entries()
	mut out := strings.new_builder(entries.len * 64)
	if format == .markdown {
		out.write_string('---\n')
		out.write_string('title: Keybinding Action Reference\n')
		out.write_string('description: Reference of all Ghostty keybinding actions.\n')
		out.write_string('editOnGithubLink: https://github.com/ghostty-org/ghostty/edit/main/src/input/Binding.zig\n')
		out.write_string('---\n\n')
		out.write_string('This is a reference of all Ghostty keybinding actions.\n\n')
	}

	mut pending_docs := []string{}
	for entry in entries {
		// Ghostty buffers documentation so a shared comment placed above a run
		// of related actions is emitted immediately before the next documented
		// action. The V ActionTag has a comment on every field, but retaining the
		// buffer preserves the source algorithm for future shared comments.
		if show_docs && entry.docs.len > 0 {
			if pending_docs.len > 0 {
				write_help_docs(mut out, format, pending_docs)
			}
			out.write_u8(`\n`)
			pending_docs = []
		}
		if show_docs {
			match format {
				.plaintext { out.write_string('${entry.name}:\n') }
				.markdown { out.write_string('## `${entry.name}`\n') }
			}
		} else {
			out.write_string('${entry.name}\n')
		}
		if show_docs && entry.docs.len > 0 {
			pending_docs = entry.docs.clone()
		}
	}
	if pending_docs.len > 0 {
		write_help_docs(mut out, format, pending_docs)
	}
	return out.str()
}

struct HelpEntry {
	name string
	docs []string
}

// binding_action_help_entries reads the help_strings data generated from the
// pinned Binding.zig Action union and embedded into the executable at build
// time. Installed binaries therefore never need the source checkout.
fn binding_action_help_entries() []HelpEntry {
	mut entries := []HelpEntry{}
	mut name := ''
	mut docs := []string{}
	for line in binding_action_help_data.split_into_lines() {
		if line.starts_with('@@') {
			if name.len > 0 {
				// HelpStrings represents a trailing blank doc-comment line as a
				// trailing newline. The source generator explicitly skips the
				// final empty split field before buffering documentation.
				if docs.len > 0 && docs.last().len == 0 {
					docs.delete_last()
				}
				entries << HelpEntry{
					name: name
					docs: docs
				}
			}
			name = line[2..]
			docs = []string{}
			continue
		}
		docs << line
	}
	if name.len > 0 && name != '__end' {
		if docs.len > 0 && docs.last().len == 0 {
			docs.delete_last()
		}
		entries << HelpEntry{
			name: name
			docs: docs
		}
	}
	return entries
}

fn write_help_docs(mut out strings.Builder, format Format, docs []string) {
	for line in docs {
		match format {
			.plaintext { out.write_string('  ${line}\n') }
			.markdown { out.write_string('${line}\n') }
		}
	}
}
