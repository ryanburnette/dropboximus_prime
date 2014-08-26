Dropboximus Prime
=================

**Dropboximus Prime** is a Ruby library which uses Dropbox as a remote management
location and processes common web content including Markdown and YAML.

Standard use cases include Sinatra and Ruby sites where content is stored in
a Dropbox folder shared among publishers. Objects will be filled with site content
in the Model using the `get` method. Markdown files become HTML. YAML files
become a Hash or Array. Images become an object with useful methods for creating
associated image tags.

The library supports globbing of the local cache.

The `refresh` and `prune` methods can be scheduled to keep sites up-to-date
with changes.

This library is a work in progress and is intended for simple use cases.

Supported Formats
-----------------

+ Markdown
+ YAML
+ Images

Issues
------

Feel free to report issues and make pull requests.

Version History
---------------

+ 0.2.0
  + New usage pattern
  + Compare remote instead of cache timeouts
  + Globbing
  + Other improvements

+ 0.1.3

+ 0.1.2

+ 0.1.1

+ 0.1.0
  + Initial version

License
-------

Apache2
