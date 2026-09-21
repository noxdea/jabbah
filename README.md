# Jabbah

Jabbah (ν Scorpii, from Arabic *jabha*, “forehead”) is a dependency-free
Ruby HTML parser for static documents and reader applications. It builds a
tolerant tree, supports a useful CSS selector subset, serializes safely, and
includes conservative sanitization and article extraction. It never executes
JavaScript.

## Features

- Error-tolerant HTML and fragment parsing with implicit element closing
- Elements, text, comments, doctypes, attributes, traversal, and cloning
- Tag, id, class, attribute, descendant/child, and common structural selectors
- UTF-8, BOM, and declared charset decoding using Ruby's standard library
- `docs`, `feed`, and `mail` sanitization profiles with XSS-safe URL handling
- Remote-image blocking with `data-blocked-src`, `cid:` preservation, and callbacks
- Readability-style article extraction without network access or native extensions

## Installation

```ruby
gem "jabbah"
```

```sh
gem install jabbah
```

## Quick start

```ruby
require "jabbah"

document = Jabbah.parse("<article><h1>Hello</h1><p>Welcome.</p></article>")
puts document.at("article").text
puts document.to_html

safe = Jabbah::Sanitize.clean(document, profile: :feed, base_url: "https://example.test/")
article = Jabbah::Extract.article(safe)
puts article[:title] if article
```

`Jabbah.parse` returns a `Jabbah::Document`; `Jabbah.fragment` parses a
fragment without adding `html`, `head`, or `body` wrappers. `Document#at`
returns the first match and `#search` returns all matches.

Sanitization returns a cloned document. Remote images are blocked by default;
the number blocked is available as `Document#blocked_count`. Link targets are
forced to `_blank` with `noopener noreferrer`.

## Development

```sh
bundle install
bundle exec rake test
```

Jabbah has no runtime dependencies and requires Ruby 3.2 or newer.

## License

Jabbah is released under the [MIT License](LICENSE.txt).
