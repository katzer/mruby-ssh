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

class MRuby::Build
  # If the build target points to Windows OS.
  #
  # @return [ Boolean ]
  def targets_win32?
    ENV['OS'] == 'Windows_NT' ? true : is_a?(MRuby::CrossBuild) && host_target.to_s =~ /mingw/
  end

  # Exclude support for channels, streams, ...
  #
  # @return [ Boolean ]
  def tiny_ssh?
    cc.defines.include? 'MRB_SSH_TINY'
  end

  # Link dynamically with libssh
  # instead of static compilation.
  #
  # @return [ Boolean ]
  def link_lib?
    cc.defines.include? 'MRB_SSH_LINK_LIB'
  end

  # Link dynamically with a custom crypto lib
  # instead of statically linked with mbedtls.
  #
  # @return [ Boolean ]
  def link_crypto?
    cc.defines.include?('MRB_SSH_LINK_CRYPTO')
  end

  # Compile libssh2 with zlib support
  # for compression.
  #
  # @return [ Boolean ]
  def zlib?
    cc.defines.include? 'LIBSSH2_HAVE_ZLIB'
  end
end
