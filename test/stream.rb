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

def open_channel(ssh)
  channel = SSH::Channel.new(ssh)
ensure
  channel.open
  yield(channel) if block_given?
end

def pipe(ssh, cmd)
  channel = open_channel(ssh) { |ch| ch.request('exec', cmd) }
  [SSH::Stream.new(channel), SSH::Stream.new(channel, SSH::Stream::STDERR)]
end

assert 'SSH::Stream' do
  assert_kind_of Class, SSH::Stream
end

assert 'SSH::Stream::STDIO' do
  assert_include SSH::Stream.constants, :STDIO
  assert_kind_of Integer, SSH::Stream::STDIO
end

assert 'SSH::Stream::STDERR' do
  assert_include SSH::Stream.constants, :STDERR
  assert_kind_of Integer, SSH::Stream::STDERR
end

SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  assert 'SSH::Stream#channel' do
    assert_kind_of SSH::Channel, SSH::Stream.new(open_channel(ssh)).channel
  end

  assert 'SSH::Stream#gets' do
    io, = pipe(ssh, 'echo ETNA')

    assert_equal 'ETNA', io.gets(chomp: true)
    assert_nil           io.gets
  end

  assert 'SSH::Stream#gets(nil)' do
    io, = pipe(ssh, 'echo hello;echo world')
    assert_equal "hello\nworld\n", io.gets(nil)
  end

  assert 'SSH::Stream#gets(int)' do
    io, = pipe(ssh, 'echo hello;echo world')

    assert_equal 'hello',   io.gets(5)
    assert_equal "\nworld", io.gets(6)
  end

  assert 'SSH::Stream#gets(str)' do
    io, = pipe(ssh, 'echo hello;echo world')

    assert_equal 'hello', io.gets("\n", chomp: true)
    assert_equal 'world', io.gets(chomp: true)
  end

  assert 'SSH::Stream#readlines' do
    io, = pipe(ssh, 'echo hello;echo world')

    assert_equal %w[hello world], io.readlines(chomp: true)
  end

  assert 'SSH::Stream#readline' do
    io, = pipe(ssh, 'echo hello;echo world')

    assert_equal 'hello', io.readline(chomp: true)
    assert_equal 'world', io.readline(chomp: true)
  end

  assert 'SSH::Stream#getc' do
    io, = pipe(ssh, 'echo ETNA')

    assert_equal 'E',  io.getc
    assert_equal 'T',  io.getc
    assert_equal 'N',  io.getc
    assert_equal 'A',  io.getc
    assert_equal "\n", io.getc
    assert_equal nil,  io.getc
  end

  irb_in_path = open_channel(ssh) { |ch| ch.exec('irb -v') }.exitstatus == 0

  assert 'SSH::Stream#write' do
    if irb_in_path
      io, = pipe(ssh, 'irb')

      assert_equal 3, io.write('1+1')
      assert_equal 1, io.write("\n")

      2.times { io.gets }
      assert_equal '2', io.gets(chomp: true)

      io.close
    else
      skip "Command 'irb' not supported."
    end
  end

  assert 'SSH::Stream#<<' do
    if irb_in_path
      io, = pipe(ssh, 'irb')

      io << '1+1' << "\n"

      2.times { io.gets }
      assert_equal '2', io.gets(chomp: true)

      io.close
    else
      skip "Command 'irb' not supported."
    end
  end

  assert 'SSH::Stream#puts' do
    if irb_in_path
      io, er = pipe(ssh, 'irb')

      io.puts '1+1'
      io.puts "$stderr.puts 'error'"

      2.times { io.gets }
      assert_equal '2',     io.gets(chomp: true)
      assert_equal 'error', er.gets(chomp: true)

      io.close
    else
      skip "Command 'irb' not supported."
    end
  end

  assert 'SSH::Stream#flush' do
    io, = pipe(ssh, 'echo 123')

    assert_false io.eof?
    io.close
    assert_false io.eof?

    assert_equal 4, io.flush
    assert_nil  io.getc
    assert_true io.eof?
  end
end
