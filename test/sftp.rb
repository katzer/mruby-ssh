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

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

assert 'SFTP' do
  assert_kind_of Class, SFTP
end

assert 'SFTP::new', 'without host' do
  assert_nothing_raised { SFTP.new }
end

assert 'SFTP::new', 'invalid host' do
  assert_raise(TypeError) { SFTP.new 123 }
  assert_raise(RuntimeError) { SFTP.new '123' }
end

assert 'SFTP::open', 'invalid host' do
  assert_raise(TypeError) { SFTP.open 123 }
  assert_raise(RuntimeError) { SFTP.open '123' }
end

assert 'SFTP#connect' do
  ftp = SFTP.new

  begin
    assert_nothing_raised { ftp.connect('test.rebex.net', 22) }
    assert_equal 'test.rebex.net', ftp.host
    assert_true ftp.connected?
  ensure
    ftp.close
  end
end

assert 'SFTP#close' do
  begin
    ftp = SFTP.new('test.rebex.net')
    assert_nothing_raised { SFTP.new.close }
    assert_equal 'test.rebex.net', ftp.host
  ensure
    ftp.close if ftp
  end

  if ftp
    assert_false ftp.connected?
    assert_nil   ftp.host
  end
end

assert 'SFTP#login' do
  ftp = SFTP.new 'test.rebex.net'

  begin
    assert_false ftp.logged_in?
    assert_raise(TypeError) { ftp.login 1, 2 }
    assert_false ftp.logged_in?

    assert_nothing_raised { ftp.login('demo', 'password') }
    assert_true ftp.logged_in?
  ensure
    ftp.close
    assert_false ftp.logged_in?
  end
end

assert 'SFTP::new', 'auto connect' do
  begin
    ftp = SFTP.new('test.rebex.net')
    assert_true  ftp.connected?
    assert_false ftp.logged_in?
  ensure
    ftp.close if ftp
  end
end

assert 'SFTP::new', 'auto login' do
  begin
    ftp = SFTP.new('test.rebex.net', username: 'demo', password: 'password')
    assert_true ftp.logged_in?
  ensure
    ftp.close if ftp
  end
end

assert 'SFTP::open' do
  sftp = nil

  SFTP.open('test.rebex.net') do |ftp|
    sftp = ftp
    assert_kind_of SFTP, ftp
    assert_true ftp.connected?
    assert_equal 'test.rebex.net', ftp.host
  end

  assert_false sftp.nil?
  assert_true  sftp.closed? if sftp
end

assert 'SFTP::open', 'auto login' do
  SFTP.open('test.rebex.net', username: 'demo', password: 'password') do |ftp|
    assert_true ftp.logged_in?
  end
end

assert 'SFTP#list' do
  SFTP.open('test.rebex.net') do |ftp|
    ftp.login('demo', 'password')
    assert_raise(TypeError)    { ftp.list 123 }
    assert_raise(RuntimeError) { ftp.list '~' }
    assert_nothing_raised { ftp.list }
    assert_nothing_raised { ftp.list '/' }
    assert_kind_of Array, ftp.list
    assert_false ftp.list.empty?
  end
end

assert 'SFTP#entries' do
  SFTP.open('test.rebex.net') do |ftp|
    ftp.login('demo', 'password')
    assert_raise(TypeError)    { ftp.entries 123 }
    assert_raise(RuntimeError) { ftp.entries '~' }
    assert_nothing_raised { ftp.entries }
    assert_nothing_raised { ftp.entries '/' }
    assert_kind_of Array, ftp.entries
    assert_false ftp.entries.empty?
    assert_not_include ftp.entries, '.'
    assert_not_include ftp.entries, '..'
    assert_not_equal '/', ftp.entries.first[0]
    assert_equal     '/', ftp.entries('/').first[0]
    assert_not_equal '/', ftp.entries('/').first[1]
    assert_not_equal ftp.entries('pub'), ftp.entries('pub/example')
    assert_equal 'pub/example/', ftp.entries('pub/example').first[0...12]
  end
end

assert 'SFTP#last_errno' do
  SFTP.open('test.rebex.net') do |ftp|
    assert_nil      ftp.last_error
    assert_equal 0, ftp.last_errno

    ftp.login('demo', 'false') rescue nil

    assert_kind_of String,  ftp.last_error
    assert_kind_of Integer, ftp.last_errno
    assert_not_equal 0,     ftp.last_errno
  end
end

assert 'SFTP#mtime' do
  SFTP.open('test.rebex.net') do |ftp|
    assert_raise(RuntimeError) { ftp.mtime 'pub/example' }

    ftp.login('demo', 'password')
    mtime = ftp.mtime 'pub/example'

    assert_kind_of Integer, mtime
    assert_true mtime > 0
  end
end

assert 'SFTP#atime' do
  SFTP.open('test.rebex.net') do |ftp|
    assert_raise(RuntimeError) { ftp.atime 'pub/example' }

    ftp.login('demo', 'password')
    atime = ftp.atime 'pub/example'

    assert_kind_of Integer, atime
    assert_true atime > 0
  end
end
