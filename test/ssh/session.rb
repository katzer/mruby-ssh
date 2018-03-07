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

assert 'SSH::Session' do
  assert_kind_of Class, SSH::Session
end

assert 'SSH::Session#new' do
  ssh = SSH::Session.new

  assert_false ssh.connected?
  assert_false ssh.logged_in?
  assert_nil   ssh.host

  ssh = SSH::Session.new('test.rebex.net', user: 'demo', password: 'password')

  assert_true ssh.connected?
  assert_true ssh.logged_in?
  assert_equal 59, ssh.fingerprint.length
  assert_equal 'test.rebex.net', ssh.host

  ssh.close

  assert_false ssh.connected?
  assert_false ssh.logged_in?
  assert_nil   ssh.host
end

assert 'SSH::Session#connect+login' do
  ssh = SSH::Session.new

  assert_raise(RuntimeError) { ssh.fingerprint }
  assert_raise(RuntimeError) { ssh.userauth_methods 'demo' }
  assert_raise(RuntimeError) { ssh.userauth_method_supported? 'demo', 'xyz' }

  ssh.connect 'test.rebex.net'
  assert_true  ssh.connected?
  assert_false ssh.logged_in?

  assert_nil      ssh.last_error
  assert_equal 0, ssh.last_errno

  auth_methods = ssh.userauth_methods('demo')
  assert_kind_of Array, auth_methods
  assert_false auth_methods.empty?
  assert_kind_of String, auth_methods.first
  assert_true ssh.userauth_method_supported? 'demo', auth_methods[0]
  assert_false ssh.userauth_method_supported? 'demo', 'xyz'

  ssh.login('demo', 'false') rescue nil
  assert_kind_of String,  ssh.last_error
  assert_kind_of Integer, ssh.last_errno
  assert_not_equal 0,     ssh.last_errno
  assert_false ssh.logged_in?

  ssh.login 'demo', 'password'
  assert_true ssh.logged_in?

  ssh.close
end

assert 'SSH::start' do
  session = nil

  SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
    session = ssh
    assert_kind_of SSH::Session, ssh
    assert_true ssh.logged_in?
  end

  assert_true session.closed?
end
