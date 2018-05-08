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
  class Stream
    # To behaive like a pipe.
    include SSH::IO

    # The ID of the stream (STDIO or STDERR).
    #
    # @return [ Integer ]
    attr_reader :id

    # The underlying SSH channel.
    #
    # @return [ SSH::Channel ]
    attr_reader :channel

    # Check if the remote host has sent an EOF status.
    #
    # @return [ Boolean ]
    def eof?
      channel.eof?
    end

    # Tell the remote host that no further data will be sent.
    # Processes typically interpret this as a closed stdin descriptor.
    #
    # @param [ Boolean ] wait_for_eof Wait for the remote end to send EOF.
    #                                 Defaults to: true
    #
    # @return [ Void ]
    def close(wait_for_eof = true)
      channel.eof(wait_for_eof)
    end
  end
end
