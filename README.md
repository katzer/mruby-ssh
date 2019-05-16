# SSH client for mruby <br> [![Build Status](https://travis-ci.com/katzer/mruby-ssh.svg?branch=master)](https://travis-ci.com/katzer/mruby-ssh) [![Build status](https://ci.appveyor.com/api/projects/status/bkd5aem5ap1n22cs/branch/master?svg=true)](https://ci.appveyor.com/project/katzer/mruby-ssh/branch/master) [![codebeat badge](https://codebeat.co/badges/b7257079-893a-480e-b658-80d79419d429)](https://codebeat.co/projects/github-com-katzer-mruby-ssh-master)

Inspired by [Net::SSH][net_ssh], empowers [mruby][mruby].

The snippet demontrates how to execute a command on the remote host:

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  hostname = ssh.exec('hostname')
end
```

## Installation

Add the line below to your `build_config.rb`:

```ruby
MRuby::Build.new do |conf|
  # ... (snip) ...
  conf.gem 'mruby-ssh'
end
```

Or add this line to your aplication's `mrbgem.rake`:

```ruby
MRuby::Gem::Specification.new('your-mrbgem') do |spec|
  # ... (snip) ...
  spec.add_dependency 'mruby-ssh'
end
```

The resulting binary will be statically linked agains _libssh2_ and _mbedtls_. There are no external runtime dependencies and the code should run fine for Linux, Unix and Windows platform.

## Usage

To initiate a SSH session it is recommended to use `SSH.start`. Next to the optional host and user, the following keys are supported: `user`, `password`, `key`, `passphrase`, `properties`, `non_interactive`, `timeout`, `compress` and `sigpipe`.

Password:

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  ssh # => SSH::Session
end
```

Keyboard-Interactive:

```ruby
SSH.start('test.rebex.net', 'demo') do |ssh|
  ssh # => SSH::Session
end
```

Publickey:

```ruby
SSH.start('test.rebex.net', 'demo', key: '~/.ssh/id_rsa') do |ssh|
  ssh # => SSH::Session
end
```

### SSH::Session

A session class representing the connection service running on top of the SSH transport layer. It provides both low-level (connect, login, close, etc.) and high-level (open_channel, exec) SSH operations.

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  ssh.fingerprint # => '60 C6 65 66 13 89 7B 5A 86 C5 2F 8F 7E CC 92 36 10 3B 3E 42'
end
```

See [session.rb](mrblib/session.rb) and [session.c](src/session.c) for a complete list of available methods.

### SSH::Channel

Multiple "channels" can be multiplexed onto a single SSH channel, each operating independently and seemingly in parallel. This class represents a single such channel. Most operations performed with the mruby-ssh library will involve using one or more channels.

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  ssh.open_channel do |channel|
    channel.env('MRB_VERSION', '1.4.1')
    channel.exec('printf $MRB_VERSION') # => '1.4.1'
  end
end
```

To capture both stdout and stderr streams:

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  ssh.open_channel do |channel|
    out, err, suc = channel.capture3("ruby -e '$stdout.print(1);$stderr.print(2)'")
  end
end
```

To interact with the remote process:

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  ssh.open_channel do |channel|
    io, suc = channel.popen2e('irb')

    io.puts('1+1')
    io.gets(chomp: true) # => '2'
  end
end
```

To interact with a screen based process (like vim or emacs):

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  ssh.open_channel do |channel|
    channel.request_pty term: 'xterm', chars_wide: 120
  end
end
```

See [channel.rb](mrblib/channel.rb) and [channel.c](src/channel.c) for a complete list of available methods.

### Compression

Add the line below to your `build_config.rb`:

```ruby
MRuby::Build.new do |build|
  # ... (snip) ...
  build.cc.defines += %w[LIBSSH2_HAVE_ZLIB HAVE_UNISTD_H]
end
```

Now initiate a new SSH session with `compress:true`:

```ruby
SSH.start('test.rebex.net', 'demo', password: 'password', compress: true)
```

### Threading

To initiate SSH sessions within threads add the line below to your `build_config.rb`:

```ruby
MRuby::Build.new do |build|
  # ... (snip) ...
  build.cc.defines += %w[MBEDTLS_THREADING_PTHREAD MBEDTLS_THREADING_C]
end
```

### Debugging

To trace additional debug informations at runtime add the line below to your `build_config.rb`:

```ruby
MRuby::Build.new do |build|
  # ... (snip) ...
  build.cc.defines << 'MRB_SSH_DEBUG'
end
```

### Dynamic linking

For dynamic linking with _libssh2.so_ add the line below to your `build_config.rb`:

```ruby
MRuby::Build.new do |build|
  # ... (snip) ...
  build.cc.defines << 'MRB_SSH_LINK_LIB'
end
```

To only link the crypto backend at runtime (e.g. OpenSSL) add the line below to your `build_config.rb`:

```ruby
MRuby::Build.new do |build|
  # ... (snip) ...
  build.cc.defines += %w[MRB_SSH_LINK_CRYPTO LIBSSH2_OPENSSL]
  build.linker.libraries += %w[ssl crypto]
end
```

## Development

Clone the repo:
    
    $ git clone https://github.com/katzer/mruby-ssh.git && cd mruby-ssh/

Compile the source:

    $ rake compile

Run the tests:

    $ rake test

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/katzer/mruby-ssh.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Authors

- Sebastián Katzer, Fa. appPlant GmbH

## License

The mgem is available as open source under the terms of the [MIT License][license].

Made with :yum: in Leipzig

© 2017 [appPlant GmbH][appplant]

[mruby]: https://github.com/mruby/mruby
[net_ssh]: https://github.com/net-ssh/net-ssh
[license]: http://opensource.org/licenses/MIT
[appplant]: www.appplant.de