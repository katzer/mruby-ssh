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

assert 'SSH::Channel#initialize', 'session not connected' do
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
  assert_raise(NoMethodError) { channel.type = 'other' }
end

assert 'SSH::Channel#local_maximum_packet_size' do
  channel = SSH::Channel.new(dummy)
  assert_raise(NoMethodError) { channel.local_maximum_packet_size = 'other' }
end

assert 'SSH::Channel#local_maximum_window_size' do
  channel = SSH::Channel.new(dummy)
  assert_raise(NoMethodError) { channel.local_maximum_window_size = 'other' }
end

SSH.start('test.rebex.net') do |ssh|
  assert 'SSH::Channel#new', 'session not logged in' do
    assert_false SSH::Channel.new(ssh).open?
  end

  assert 'SSH::Channel#open', 'session not logged in' do
    channel = SSH::Channel.new(ssh)
    assert_raise(RuntimeError) { channel.open }
    assert_raise(RuntimeError) { channel.open('msg') }
  end

  ssh.login('demo', 'password')

  assert 'SSH::Channel#open', 'session not logged in' do
    channel = SSH::Channel.new(ssh)
    assert_nothing_raised { channel.open }
    assert_nothing_raised { channel.open(nil) }
  end

  assert 'SSH::Channel#new', 'session logged in' do
    assert_true SSH::Channel.new(ssh).open?
  end

  assert 'SSH::Channel#close' do
    channel = SSH::Channel.new(ssh)

    channel.close
    assert_false channel.open?
    assert_nothing_raised { channel.close }

    channel.open
    assert_true channel.open?

    ssh.close
    assert_false channel.open?
    assert_nothing_raised { channel.close }
  end
end
