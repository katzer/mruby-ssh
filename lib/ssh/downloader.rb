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

require 'rake/file_utils'

module SSH
  # Knows how to download dependencies.
  class Downloader
    # List of GitHub repositories
    REPOS = {
      mbedtls: 'ARMmbed/mbedtls',
      libssh2: 'libssh2/libssh2',
      zlib: 'madler/zlib'
    }.freeze

    # List of URI from where to download the archive
    ARCHIVES = {
      mbedtls: 'https://tls.mbed.org/download/mbedtls-%s-apache.tgz',
      libssh2: 'https://www.libssh2.org/download/libssh2-%s.tar.gz',
      zlib: 'http://zlib.net/zlib-%s.tar.gz'
    }.freeze

    include Rake::FileUtilsExt

    # Initializes the download for libssh2, mbedtls,..
    #
    # @param [ String ] dir Where to copy the dependencies.
    #
    # @return [ Void ]
    def initialize(dir)
      @dir = dir
    end

    # Download the dependency.
    #
    # @param [ Symbol ] name    The name of the dependency.
    # @param [ String ] version The version to download.
    #
    # @return [ Void ]
    def download(name, version = 'head')
      if version == 'head'
        git_clone REPOS[name]
      else
        curl format(ARCHIVES[name], version)
      end
    end

    private

    # Clones the git repo.
    #
    # @param [ String ] repo The name of the github repo.
    #
    # @return [ Void ]
    def git_clone(repo)
      folder = repo.split('/')[-1]
      sh "git clone --depth 1 git://github.com/#{repo}.git #{@dir}/#{folder}"
    end

    # Downloads the archive and extracts it.
    #
    # @param [ String ] url A HTTP URI.
    #
    # @return [ Void ]
    def curl(url)
      folder = url.scan(/[a-z0-9]+(?=-)/)[0]
      sh "curl -s --fail --retry 3 --retry-delay 1 #{url} | tar xzC . && find . -maxdepth 1 -name '#{folder}-*' -exec mv '{}' #{@dir}/#{folder} \\;" # rubocop:disable LineLength
    end
  end
end