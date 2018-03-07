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

module SSH
  # Default SSH port
  PORT = 22

  # A synonym for SSH::Session.new, but with a mandatory host parameter.
  # If a block is given, it is passed the SSH object, which will be closed
  # when the block finishes, or when an exception is raised.
  #
  # @param [ String ] host The host name.
  # @param [ String ] user Optional user name.
  # @param [ Hash ]   opts See SSH::Session.new
  #
  # @return [ Net::FTP ]
  def self.start(host, user = nil, opts = {})
    opts[:user] = user if user
    session     = Session.new(host, opts)

    return session unless block_given?

    begin
      yield session
    ensure
      session.close
    end
  end
end
