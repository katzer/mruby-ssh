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

module SSH
  # A session class representing the connection service running on top of the
  # SSH transport layer. It manages the creation of channels (see open_channel),
  # and the dispatching of messages to the various channels.
  #
  # You will rarely (if ever) need to instantiate this class directly; rather,
  # you'll almost always use Net::SSH.start to initialize a new network
  # connection, authenticate a user, and return a new connection session, all in
  # one call.
  class Session
    # A convenience method for executing a command.
    #
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the command could not be executed.
    def exec(cmd, opts = nil)
      channel = Channel.new(self)
      channel.open
      channel.exec(cmd, opts, false)
    ensure
      channel.close
    end

    # Requests that a new channel be opened. By default, the channel will be of
    # type "session", but if you know what you're doing you can select any of
    # the channel types supported by the SSH protocol.
    #
    # @param See SSH::Channel#initialize
    #
    # @return [ Void ]
    def open_channel(type = :session, pkg_size = nil, win_size = nil, cmd = nil, &block)
      channel = Channel.new(self, type, pkg_size, win_size)

      channel.open(cmd)

      block ? yield(channel) && nil : channel
    ensure
      channel.close if block
    end
  end
end
