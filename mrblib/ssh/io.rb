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
  module IO
    # Calls the block once for each line in the named file on the remote server.
    # Yields the line to the block.
    #
    # @param [ Hash ] opts The path of the remote directory.
    # @param [ Proc ] proc Optional config settings { chomp: false }
    #
    # @return [ Void ]
    def each_line(opts = { chomp: false })
      return to_enum(:each, opts) unless block_given?
      open || loop { break unless (line = gets(opts)) && yield(line) }
    ensure
      close
    end

    alias each each_line

    # Reads a one-character string. Returns nil if called at end of file.
    #
    # @return [ String ]
    def getc
      gets(1)
    end

    # Reads up to n bytes of data from the stream. Fewer bytes will be returned
    # if EOF is encountered before the requested number of bytes could be read.
    # Without an argument (or with a nil argument) all data to the end of the
    # file will be read and returned.
    #
    # @param [ Int ] bytes Number of bytes to read.
    #
    # @return [ String ]
    def read(bytes = nil)
      raise TypeError if bytes && !bytes.is_a?(Integer)
      gets(bytes)
    end

    # Same as gets, but raises EOFError if EOF is encountered before any data
    # could be read.
    #
    # @param [ String ] sep  The string where to seperate from next line.
    # @param [ Hash ]   opts Optional config settings { chomp: true }
    #
    # @return [ String ]
    def readline(sep = "\n", opts = nil)
      raise TypeError unless sep.is_a?(String) || sep.is_a?(Hash)
      line = gets(sep, opts)
      raise EOFError unless line
      line
    end

    # Reads all of the lines and returns them in an array.
    #
    # @param [ Object] sep Lines are separated by the optional sep. If sep is
    #                      nil, the rest of the stream is returned as a single
    #                      record. If the first argument is an integer, or an
    #                      optional second argument is given, the returning
    #                      string would not be longer than the given value in
    #                      bytes.
    # @param [ Hash ] opts Optional config settings { chomp: true }
    #
    # @return [ Array<String> ]
    def readlines(sep = "\n", opts = nil)
      lines = []
      loop { break unless (line = gets(sep, opts)) && lines << line }
      lines
    end

    # Writes each argument to the stream. If +$+ is set, it will be written
    # after all arguments have been written.
    #
    # @param [ String ] *items One or more strings to write.
    #
    # @return [ Void ]
    def print(*items)
      items.each { |item| write(item.to_s) }
      write($\) && nil if $\
    end

    # Writes each argument to the stream, appending a newline to any item that
    # does not already end in a newline.
    #
    # @param [ String ] *items One or more strings to write.
    #
    # @return [ Void ]
    def puts(*items)
      items.each do |item|
        data = item.to_s
        write(data[-1] == "\n" ? data : "#{data}\n")
      end
      nil
    end

    # Writes the string to the stream.
    #
    # @param [ String ] str The string to write.
    #
    # @return [ SFTP::File ] self
    def <<(str)
      write(str.to_s) && self
    end
  end
end
