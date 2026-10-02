#pragma once
/* The same manual extern declarations used by src/os/i18n.zig. */
extern char *bindtextdomain(const char *, const char *);
extern char *textdomain(const char *);
extern char *dgettext(const char *, const char *);
extern void _libintl_locale_name_canonicalize(char *);
