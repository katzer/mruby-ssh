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

class SFTP
  # A synonym for FTP.new, but with a mandatory host parameter.
  # If a block is given, it is passed the FTP object, which will be closed
  # when the block finishes, or when an exception is raised.
  #
  # @param [ String ] host Optional host name.
  # @param [ *Array ] args See FTP.new
  #
  # @return [ Net::FTP ]
  def self.open(host, *args)
    if block_given?
      ftp = new(host, *args)
      begin
        yield ftp
      ensure
        ftp.close
      end
    else
      new(host, *args)
    end
  end

  # Creates and returns a new FTP object. If a host is given,
  # a connection is made.
  #
  # @param [ String ] host Optional host name.
  # @param [ Hash ]   opts Each key of which is a symbol.
  #
  # @return [ Net::FTP ]
  def initialize(host = nil, opts = {})
    return unless host
    connect(host, opts[:port] || 22)
    login(opts[:username], opts[:password]) if opts[:username]
  end

  # The hostname specified when calling 'connect'.
  #
  # @return [ String ]
  attr_reader :host

  # If the socket is connected to the host.
  #
  # @return [ Boolean ]
  def connected?
    !closed?
  end
end
