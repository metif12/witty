module input

import os
import strings

// This module is a help generator for keybind actions documentation.
// It can generate documentation in different formats (plaintext for CLI,
// markdown for website) while maintaining consistent content.

// HelpFormat represents the output format for documentation.
pub enum HelpFormat {
	// Plain text output with indentation.
	plaintext
	// Markdown formatted output.
	markdown
}

// generate_help generates keybind actions documentation.
pub fn generate_help(format HelpFormat, show_docs bool) string {
	entries := binding_action_help_entries() or { return '' }
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
		if show_docs && entry.docs.len > 0 && pending_docs.len > 0 {
			write_help_docs(mut out, format, pending_docs)
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

// binding_action_help_entries reads the V translation's ActionTag declaration
// and extracts the doc comments attached to every field. Ghostty obtains the
// same information with Zig AST reflection and generated help_strings.
fn binding_action_help_entries() ![]HelpEntry {
	path := os.join_path(os.dir(@FILE), 'binding.v')
	source := os.read_file(path)!
	mut entries := []HelpEntry{}
	mut in_enum := false
	mut docs := []string{}
	for raw_line in source.split_into_lines() {
		line := raw_line.trim_space()
		if !in_enum {
			if line == 'pub enum ActionTag {' {
				in_enum = true
			}
			continue
		}
		if line == '}' {
			break
		}
		if line.starts_with('//') {
			docs << line.trim_string_left('//').trim_space()
			continue
		}
		if line.len == 0 || line.starts_with('@[') {
			continue
		}
		name := line.all_before(' ').all_before('=').trim_space()
		if name.len == 0 || name.starts_with('_') {
			docs = []
			continue
		}
		entries << HelpEntry{
			name: name
			docs: docs.clone()
		}
		docs = []
	}
	return entries
}

fn write_help_docs(mut out strings.Builder, format HelpFormat, docs []string) {
	for line in docs {
		match format {
			.plaintext { out.write_string('  ${line}\n') }
			.markdown { out.write_string('${line}\n') }
		}
	}
}
