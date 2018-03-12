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

assert 'SSH' do
  assert_kind_of Module, SSH
end

assert 'SSH.startup' do
  assert_nothing_raised { SSH.startup }
  assert_true SSH.ready?
end

assert 'SSH.cleanup' do
  assert_nothing_raised { SSH.cleanup }
  assert_false SSH.ready?
end

assert 'SSH.start' do
  assert_include SSH.public_methods, :start
end

assert 'SSH::TIMEOUT_ERROR' do
  assert_include SSH.constants, :TIMEOUT_ERROR
end

assert 'SSH::DISCONNECT_ERROR' do
  assert_include SSH.constants, :DISCONNECT_ERROR
end

assert 'SSH::AUTHENTICATION_ERROR' do
  assert_include SSH.constants, :AUTHENTICATION_ERROR
end
