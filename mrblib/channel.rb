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
    #
    # @return [ Void ]
    def initialize(session, type = :session, max_pkg_size = nil, max_win_size = nil)
      @session                   = session
      @type                      = type.to_s.freeze
      @local_maximum_packet_size = max_pkg_size || PACKET_DEFAULT
      @local_maximum_window_size = max_win_size || WINDOW_DEFAULT
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
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def exec(cmd, opts = {})
      ok = request('exec', cmd, EXT_IGNORE)
      io = Stream.new(self).gets(chomp: opts[:chomp]) if ok
    ensure
      yield(io, ok) if block_given?
    end

    # Open stdin and stdout streams and start remote executable.
    #
    # @param [ String ] cmd    The command to execute.
    # @param [ Proc ]   &block If given it will be invoked with the streams.
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def popen2(cmd)
      __popen2__(cmd, EXT_IGNORE)
    end

    # Open stdin and stdout streams and start remote executable.
    #
    # @param [ String ] cmd    The command to execute.
    # @param [ Proc ]   &block If given it will be invoked with the streams.
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def popen2e(cmd)
      __popen2__(cmd, EXT_MERGE)
    end

    # Open stdin, stdout, and stderr streams and start remote executable.
    #
    # @param [ String ] cmd    The command to execute.
    # @param [ Proc ]   &block If given it will be invoked with the streams.
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def popen3(cmd)
      ok = request('exec', cmd, EXT_NORMAL)
      io = Stream.new(self, Stream::STDIO)
      er = Stream.new(self, Stream::STDERR)
      block_given? ? yield(io, er, ok) : [io, er, ok]
    end

    # Captures the standard output of a command.
    #
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def capture2(cmd, opts = {})
      __capture2__(cmd, opts, EXT_IGNORE)
    end

    # Captures the standard output and the standard error of a command.
    #
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def capture2e(cmd, opts = {})
      __capture2__(cmd, opts, EXT_MERGE)
    end

    # Captures the standard output and the standard error of a command.
    #
    # @param [ String ]         cmd  The command to execute.
    # @param [ Hash<Symbol, _>] opts Additional options.
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def capture3(cmd, opts = {})
      ok = request('exec', cmd, EXT_NORMAL)
      io = Stream.new(self, Stream::STDIO).gets(chomp: opts[:chomp])  if ok
      er = Stream.new(self, Stream::STDERR).gets(chomp: opts[:chomp]) if ok
      block_given? ? yield(io, er, ok) : [io, er, ok]
    end

    # Syntactic sugar for requesting that a subsystem be started. Subsystems are
    # a way for other protocols (like SFTP) to be run, using SSH as the
    # transport.
    #
    # @param [ String ] subsystem The name of the subsystem.
    # @param [ Int ]    ext_data  How to handle extended data (stderr).
    #                             Defaults to: EXT_NORMAL
    #
    # @return [ Boolean ] true if the subsystem could be requested.
    def subsystem(subsystem, ext_data = EXT_NORMAL)
      ok = request('subsystem', subsystem, ext_data)
    ensure
      yield(ok) if block_given?
    end

    private

    # Open stdin, stdout, and stderr streams and start remote executable.
    #
    # @param [ String ] cmd       The command to execute.
    # @param [ Int ]    ext_data  How to handle extended data (stderr).
    #                             Defaults to: EXT_NORMAL
    #
    # @return [ Array<SSH::Stream> ] nil if &block is given.
    def __popen2__(cmd, ext_data)
      ok = request('exec', cmd, ext_data)
      io = Stream.new(self, Stream::STDIO)
      block_given? ? yield(io, ok) : [io, ok]
    end

    # Captures the standard output and the standard error of a command.
    #
    # @param [ String ] cmd       The command to execute.
    # @param [ Hash]    opts      Additional options.
    # @param [ Int ]    ext_data  How to handle extended data (stderr).
    #                             Defaults to: EXT_NORMAL
    #
    # @return [ String ] nil if the subsystem could not be requested.
    def __capture2__(cmd, opts, ext_data)
      ok = request('exec', cmd, ext_data)
      io = Stream.new(self).gets(chomp: opts[:chomp]) if ok
      block_given? ? yield(io, ok) : [io, ok]
    end
  end
end
