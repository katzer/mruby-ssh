# MIT License
#
# Copyright (c) Sebastian Katzer 2017
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

dummy = SSH::Session.new

def open_channel(ssh)
  channel = SSH::Channel.new(ssh)
ensure
  channel.open
  yield(channel) if block_given?
end

assert 'SSH::Channel' do
  assert_kind_of Class, SSH::Channel
end

assert 'SSH::Channel::WINDOW_DEFAULT' do
  assert_include SSH::Channel.constants, :WINDOW_DEFAULT
  assert_kind_of Integer, SSH::Channel::WINDOW_DEFAULT
end

assert 'SSH::Channel::PACKET_DEFAULT' do
  assert_include SSH::Channel.constants, :PACKET_DEFAULT
  assert_kind_of Integer, SSH::Channel::PACKET_DEFAULT
end

assert 'SSH::Channel::EXT_NORMAL' do
  assert_include SSH::Channel.constants, :EXT_NORMAL
  assert_kind_of Integer, SSH::Channel::EXT_NORMAL
end

assert 'SSH::Channel::EXT_IGNORE' do
  assert_include SSH::Channel.constants, :EXT_IGNORE
  assert_kind_of Integer, SSH::Channel::EXT_IGNORE
end

assert 'SSH::Channel::EXT_MERGE' do
  assert_include SSH::Channel.constants, :EXT_MERGE
  assert_kind_of Integer, SSH::Channel::EXT_MERGE
end

assert 'SSH::Channel#initialize' do
  assert_raise(ArgumentError) { SSH::Channel.new }

  channel = SSH::Channel.new(dummy)
  assert_false channel.open?
  assert_equal 'session', channel.type
  assert_equal SSH::Channel::PACKET_DEFAULT, channel.local_maximum_packet_size
  assert_equal SSH::Channel::WINDOW_DEFAULT, channel.local_maximum_window_size

  channel = SSH::Channel.new(dummy, 'direct-tcpip', 10, 20)
  assert_false channel.open?
  assert_equal 'direct-tcpip', channel.type
  assert_equal 10, channel.local_maximum_packet_size
  assert_equal 20, channel.local_maximum_window_size

  channel = SSH::Channel.new(dummy, :session)
  assert_equal 'session', channel.type
end

assert 'SSH::Channel#type' do
  channel = SSH::Channel.new(dummy)
  assert_true channel.type.frozen?
  assert_false channel.methods.include? :type=
end

assert 'SSH::Channel#local_maximum_packet_size' do
  channel = SSH::Channel.new(dummy)
  assert_false channel.methods.include? :local_maximum_packet_size=
end

assert 'SSH::Channel#local_maximum_window_size' do
  channel = SSH::Channel.new(dummy)
  assert_false channel.methods.include? :local_maximum_window_size=
end

assert 'SSH::Channel#properties' do
  channel = SSH::Channel.new(dummy)

  assert_kind_of Hash, channel.properties
  assert_true  channel.properties.empty?
  assert_false channel.methods.include? :properties=

  channel[:key] = :value

  assert_equal :value, channel[:key]
  assert_equal :value, channel.properties[:key]
end

SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  rb_in_path = open_channel(ssh) { |ch| ch.exec('ruby -v') }.close(true) == 0

  assert 'SSH::Channel#open' do
    channel = SSH::Channel.new(ssh)

    assert_raise(RuntimeError) { SSH::Channel.new(dummy).open }

    assert_nothing_raised { channel.open }
    assert_true channel.open?
    assert_raise(RuntimeError) { channel.open }
  end

  assert 'SSH::Channel#request' do
    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.request('shell') }

    channel = open_channel(ssh)
    assert_nothing_raised { channel.request('shell') }
  end

  assert 'SSH::Channel#subsystem' do
    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.subsystem('sftp') }

    channel = open_channel(ssh)
    assert_nothing_raised { channel.subsystem('sftp') }
  end

  assert 'SSH::Channel#exec' do
    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.exec('echo ETNA') }

    channel = open_channel(ssh)
    assert_equal "ETNA\n", channel.exec('echo ETNA')

    channel = open_channel(ssh)
    assert_equal "ETNA\n", channel.exec('echo ETNA', chomp: false)

    channel = open_channel(ssh)
    assert_equal 'ETNA', channel.exec('echo ETNA', chomp: true)
  end

  assert 'SSH::Channel#capture2' do
    channel  = open_channel(ssh)
    out, suc = channel.capture2('echo ETNA')

    assert_equal "ETNA\n", out
    assert_true suc

    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.capture2('echo ETNA') }
  end

  assert 'SSH::Channel#capture2e' do
    channel = open_channel(ssh)

    if rb_in_path
      out, suc = channel.capture2e("ruby -e 'print(1);$stderr.print(1)'")
    else
      out, suc = channel.capture2e('echo 11', chomp: true)
    end

    assert_equal '11', out
    assert_true suc

    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.capture2e('echo ETNA') }
  end

  assert 'SSH::Channel#capture3' do
    channel = open_channel(ssh)

    if rb_in_path
      out, err, suc = channel.capture3("ruby -e 'print(1);$stderr.print(1)'")
    else
      out, err, suc = channel.capture3('echo 1', chomp: true)
      err = '1' if err.nil?
    end

    assert_equal '1', out
    assert_equal '1', err
    assert_true suc

    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.capture3('echo ETNA') }
  end

  assert 'SSH::Channel#popen2' do
    io, ok = open_channel(ssh).popen2('echo ETNA')

    assert_kind_of SSH::Stream, io
    assert_equal SSH::Stream::STDIO, io.id
    assert_equal "ETNA\n", io.read
    assert_true ok

    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.popen2('echo ETNA') }
  end

  assert 'SSH::Channel#popen2e' do
    channel = open_channel(ssh)

    if rb_in_path
      io, ok = channel.popen2e("ruby -e 'print(1);$stderr.print(1)'")
    else
      io, ok = channel.popen2e('echo 11')
    end

    assert_kind_of SSH::Stream, io
    assert_equal SSH::Stream::STDIO, io.id
    assert_equal '11', io.gets(chomp: true)
    assert_true ok

    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.popen2e('hostname') }
  end

  assert 'SSH::Channel#popen3' do
    channel = open_channel(ssh)

    if rb_in_path
      io, er, ok = channel.popen3("ruby -e 'print(1);$stderr.print(1)'")
    else
      io, er, ok = channel.popen3('echo 1')
    end

    assert_kind_of SSH::Stream, io
    assert_equal SSH::Stream::STDIO, io.id
    assert_kind_of SSH::Stream, er
    assert_equal SSH::Stream::STDERR, er.id
    assert_equal '1', io.gets(chomp: true)
    assert_equal '1', er.gets(chomp: true) if rb_in_path
    assert_true ok

    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.popen3('hostname') }
  end

  assert 'SSH::Channel#env' do
    channel = open_channel(ssh) { |ch| ch.request 'shell' }

    if channel.env('MRB_SSH', 'env')
      assert_equal 'MRB_SSH', channel.exec('echo $MRB_SSH', chomp: true)
    else
      skip ssh.last_error
    end
  end

  assert 'SSH::Channel#eof' do
    channel = open_channel(ssh)

    assert_false channel.eof?
    channel.eof(true)
    assert_true channel.eof?
  end

  assert 'SSH::Channel#close' do
    channel = SSH::Channel.new(ssh)

    channel.close
    assert_false channel.open?
    assert_nothing_raised { channel.close }

    channel.open
    assert_equal 0, channel.close(true)
    assert_true channel.closed?

    channel = open_channel(ssh) { |ch| ch.exec('unknown') }
    assert_equal 127, channel.close(true)
    assert_true  channel.closed?

    channel.open
    ssh.close
    assert_false channel.open?
    assert_nothing_raised { channel.close }
  end
end
