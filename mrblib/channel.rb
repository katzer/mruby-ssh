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
  class Channel
    # Instantiates a new channel on the given connection, of the given type,
    # and with the given id. This also sets the default maximum packet size
    # and maximum window size.
    #
    # @param [ SSH::Session ] session The SSH connection.
    # @param [ String ] type Channel type to open. Typically one of
    #                        session, direct-tcpip, or tcpip-forward.
    #                        Defaults to: session
    # @param [ Int ] max_pkg_size Max number of bytes remote host is allowed
    #                             to send in a single packet.
    #                             Defaults to: PACKET_DEFAULT
    # @param [ Int ] max_win_size Max amount of unacknowledged data remote host
    #                             is allowed to send before receiving an packet.
    #                             Defaults to: WINDOW_DEFAULT
    # @param [ String ] msg Additional data as required by the selected type.
    #
    # @return [ Void ]
    def initialize(session, type = :session,
                   max_pkg_size = nil, max_win_size = nil, msg = nil)

      @session                   = session
      @type                      = type.to_s.freeze
      @local_maximum_packet_size = max_pkg_size || PACKET_DEFAULT
      @local_maximum_window_size = max_win_size || WINDOW_DEFAULT

      open(msg) if @session.logged_in?
    end

    # The type of this channel, usually 'session'.
    #
    # @return [ String ]
    attr_reader :type

    # The maximum packet size that the local host can receive.
    #
    # @return [ Int ]
    attr_reader :local_maximum_packet_size

    # The maximum amount of data that the local end of this channel can receive.
    # This is a total, not per-packet.
    #
    # @return [ Int ]
    attr_reader :local_maximum_window_size

    # If the channel is connected to the host.
    #
    # @return [ Boolean ]
    def open?
      !closed?
    end
  end
end
