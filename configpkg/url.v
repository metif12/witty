module configpkg

// Default URL regex from config/url.zig. This is intentionally kept in
// Oniguruma syntax, including its negative lookbehind assertions.
const url_schemes = r'https?://|mailto:|ftp://|file:|ssh:|git://|ssh://|tel:|magnet:|ipfs://|ipns://|gemini://|gopher://|news:'

const ipv6_url_pattern = r'(?:\[[:0-9a-fA-F]+(?:[:0-9a-fA-F]*)+\](?::[0-9]+)?)'

pub const default_url_pattern = r'(?:' + url_schemes + r')(?:' + ipv6_url_pattern + r'|[\w\-.~:/?#@!$&*+,;=%]+(?:[\(\[]\w*[\)\]])?)+(?<![,.])|(?:\.\.\/|\.\/|(?<!\w)\/)(?:(?=[\w\-.~:\/?#@!$&*+,;=%]*\.)[\w\-.~:\/?#@!$&*+,;=%]+(?: [\w\-.~:\/?#@!$&*+,;=%]*[\/.])*(?: +(?= *$))?|(?![\w\-.~:\/?#@!$&*+,;=%]*\.)[\w\-.~:\/?#@!$&*+,;=%]+(?: [\w\-.~:\/?#@!$&*+,;=%]+)*(?: +(?= *$))?)|[\w][\w\-.]*\/(?=[\w\-.~:\/?#@!$&*+,;=%]*\.)[\w\-.~:\/?#@!$&*+,;=%]+(?: [\w\-.~:\/?#@!$&*+,;=%]*[\/.])*(?: +(?= *$))?'
