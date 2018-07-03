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
  # The channel abstraction. Multiple "channels" can be multiplexed onto a
  # single SSH channel, each operating independently and seemingly in parallel.
  #
  # Channels are intended to be used asynchronously. You request that one be
  # opened (via SSH::Session#open_channel), and when it is opened, your callback
  # is invoked.
  class Channel
    # Instantiates a new channel on the given connection, of the given type,
    # and with the given id. This also sets the default maximum packet size
    # and maximum window size.
    #
    # @param [ SSH::Session ] session The SSH connection.
    # @param [ String ] type Channel type to open. Typically one of
    #                        session, direct-tcpip, or tcpip-forward.
    #                        Defaults to: session
    # @param [ Int ] pkg_size Max number of bytes remote host is allowed
    #                         to send in a single packet.
    #                         Defaults to: PACKET_DEFAULT
    # @param [ Int ] win_size Max amount of unacknowledged data remote host
    #                         is allowed to send before receiving an packet.
    #                         Defaults to: WINDOW_DEFAULT
    #
    # @return [ Void ]
    def initialize(session, type = :session, pkg_size = nil, win_size = nil)
      @session                   = session
      @type                      = type.to_s.freeze
      @local_maximum_packet_size = pkg_size || PACKET_DEFAULT
      @local_maximum_window_size = win_size || WINDOW_DEFAULT
      @properties                = {}
    end

    # The type of this channel, usually 'session'.
    #
    # @return [ String ]
    attr_reader :type

    # A hash of properties for this channel. These can be used to store state
    # information about this channel.
    #
    # @return [ Hash ]
    attr_reader :properties

    # The remote exit code
    #
    # @return [ Int ]
    attr_reader :exitstatus

    # The maximum packet size that the local host can receive.
    #
    # @return [ Int ]
    attr_reader :local_maximum_packet_size

    # The maximum amount of data that the local end of this channel can receive.
    # This is a total, not per-packet.
    #
    # @return [ Int ]
    attr_reader :local_maximum_window_size

    # Open the channel but close before if already opened.
    #
    # @param [ String ] cmd See SSH::Channel#open.
    #
    # @return [ Void ]
    def reopen(cmd = nil)
      close(true) && open(cmd)
    end

    # If the channel is connected to the host.
    #
    # @return [ Boolean ]
    def open?
      !closed?
    end

    # A shortcut for accessing properties of the channel.
    #
    # @param [ Object ] key The name of the property.
    #
    # @return [ Object ] The associated value.
    def [](key)
      @properties[key]
    end

    # A shortcut for setting properties of the channel.
    #
    # @param [ Object ] key   The name of the property.
    # @param [ Object ] value The property value.
    #
    # @return [ Object ] The property value.
    def []=(key, value)
      @properties[key] = value
    end

    # Syntactic sugar for executing a command. Sends a channel request asking
    # that the given command be invoked.
    #
    # @param [ String ]         cmd        The command to execute.
    # @param [ Hash<Symbol, _>] opts       Additional options.
    # @param [ Boolean ]        wait_closed Wait until closed on remote site.
    #                                       Defaults to: true
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def exec(cmd, opts = nil, wait_closed = true)
      request('exec', cmd, EXT_IGNORE)
      Stream.new(self).gets(opts)
    rescue SSH::ChannelRequestFailed
      nil
    ensure
      close(wait_closed)
    end

    # Open stdin and stdout streams and start remote executable.
    #
    # @param [ String ] cmd    The command to execute.
    # @param [ Proc ]   &block If given it will be invoked with the streams.
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def popen2(cmd, &block)
      __popen__(cmd, EXT_IGNORE, &block)
    end

    # Open stdin and stdout streams and start remote executable.
    #
    # @param [ String ] cmd    The command to execute.
    # @param [ Proc ]   &block If given it will be invoked with the streams.
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def popen2e(cmd, &block)
      __popen__(cmd, EXT_MERGE, &block)
    end

    # Open stdin, stdout, and stderr streams and start remote executable.
    #
    # @param [ String ] cmd    The command to execute.
    # @param [ Proc ]   &block If given it will be invoked with the streams.
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def popen3(cmd, &block)
      __popen__(cmd, EXT_NORMAL, &block)
    end

    # Captures the standard output of a command.
    #
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def capture2(cmd, opts = {})
      __capture__(cmd, opts, EXT_IGNORE)
    end

    # Captures the standard output and the standard error of a command.
    #
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def capture2e(cmd, opts = {})
      __capture__(cmd, opts, EXT_MERGE)
    end

    # Captures the standard output and the standard error of a command.
    #
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def capture3(cmd, opts = {})
      __capture__(cmd, opts, EXT_NORMAL)
    end

    # Syntactic sugar for requesting that a subsystem be started. Subsystems are
    # a way for other protocols (like SFTP) to be run, using SSH as the
    # transport.
    #
    # @param [ String ] subsystem The name of the subsystem.
    # @param [ Int ]    ext       How to handle extended data (stderr).
    #                             Defaults to: EXT_NORMAL
    #
    # @return [ Boolean ] true if the subsystem could be requested.
    def subsystem(subsystem, ext = EXT_NORMAL, &block)
      ok = true

      begin
        request('subsystem', subsystem, ext)
      rescue SSH::ChannelRequestFailed
        ok = false
      end

      block ? yield(ok) && nil : ok
    ensure
      close if block
    end

    private

    # Open stdin, stdout, and stderr streams and start remote executable.
    #
    # @param [ String ] cmd  The command to execute.
    # @param [ Int ]    ext  How to handle extended data (stderr).
    #                        Defaults to: EXT_NORMAL
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def __popen__(cmd, ext, &block)
      ok = true

      begin
        request('exec', cmd, ext)
      rescue SSH::ChannelRequestFailed
        ok = false
      end

      res = [Stream.new(self, Stream::STDIO)]
      res << Stream.new(self, Stream::STDERR) if ext == EXT_NORMAL
      res << ok

      block ? yield(*res) && nil : res
    ensure
      close if block
    end

    # Captures the standard output and the standard error of a command.
    #
    # @param [ String ] cmd  The command to execute.
    # @param [ Hash]    opts Additional options.
    # @param [ Int ]    ext  How to handle extended data (stderr).
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def __capture__(cmd, opts, ext)
      request('exec', cmd, ext)

      res = [Stream.new(self, 0).gets(opts)]
      res << Stream.new(self, 1).gets(opts) if ext == EXT_NORMAL
      res << true
    rescue SSH::ChannelRequestFailed
      [false]
    ensure
      close(true)
    end
  end
end
