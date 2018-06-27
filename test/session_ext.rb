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

SSH.start('test.rebex.net', 'demo', password: 'password') do |ssh|
  assert 'SSH::Session#exec' do
    assert_equal "ETNA\n", ssh.exec('echo ETNA')
    assert_equal 'ETNA',   ssh.exec('echo ETNA', chomp: true)
    assert_equal 'ET',     ssh.exec('echo ETNA', 2)
  end

  assert 'SSH::Session#open_channel' do
    channel = ssh.open_channel
    called  = false

    assert_kind_of SSH::Channel, channel
    assert_true channel.open?
    assert_equal 'session', channel.type

    channel.close

    ret = ssh.open_channel do |ch|
      called = true

      assert_kind_of SSH::Channel, ch
      assert_true ch.open?
    end

    assert_true called
    assert_nil ret
  end
end
