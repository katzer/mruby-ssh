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
  # A general exception class, to act as the ancestor of all other SSH
  # exception classes.
  class Exception < ::RuntimeError
    # Construct a new Exception object, optionally passing in a message
    # and a SSH specific error code.
    #
    # @param [ String ] msg  Optional error message.
    # @param [ Int ]    code Optional SSH error code.
    #
    # @return [ Void ]
    def initialize(msg = nil, errno = 0)
      super(msg)
      @errno = errno
    end

    # The SSH error code.
    #
    # @return [ Int ]
    attr_reader :errno
  end

  # This exception is raised when authentication fails (whether it be
  # public key authentication, password authentication, or whatever).
  class AuthenticationFailed < SSH::Exception; end

  # This exception is raised when a connection attempt times out.
  class ConnectError < SSH::Exception; end

  # This exception is raised when the remote host has disconnected
  # unexpectedly.
  class Disconnect < SSH::Exception; end

  # This exception is raised when the remote host has disconnected/
  # timeouted unexpectedly.
  class Timeout < Disconnect; end

  # This exception is primarily used internally.
  class ChannelRequestFailed < SSH::Exception; end

  # Base class for host key exceptions.
  class HostKeyError < SSH::Exception; end
end

unless Object.const_defined? :EOFError
  class IOError < StandardError; end
  class EOFError < IOError; end
end
