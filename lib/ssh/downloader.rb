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
  class Downloader
    # Tells the downloaded from where to download the source.
    #
    # @param [ Symbol ] name    The name of the library.
    # @param [ String ] archive The URL to the release archives.
    # @param [ String ] github  The URL to the git repository.
    #
    # @return [ Void ]
    def self.add_source(name, archive: nil, github: nil)
      (@@archives ||= {})[name] = archive if archive
      (@@repos    ||= {})[name] = github  if github
    end

    add_source :mbedtls, archive: 'https://github.com/ARMmbed/mbedtls/archive/v%s.tar.gz',
                         github: ENV.fetch('MBETTLS_SOURCE', 'ARMmbed/mbedtls#master')

    add_source :libssh2, archive: 'https://www.libssh2.org/download/libssh2-%s.tar.gz',
                         github: ENV.fetch('LIBSSH2_SOURCE', 'libssh2/libssh2#master')

    add_source :zlib, archive: 'https://zlib.net/fossils/zlib-%s.tar.gz',
                      github: ENV.fetch('ZLIB_SOURCE', 'madler/zlib#master')

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
        git_clone name, @@repos[name]
      else
        curl name, format(@@archives[name], version)
      end
    end

    private

    # Clones the git repo.
    #
    # @param [ Symbol ] name The name of the dependency.
    # @param [ String ] repo The name of the github repo.
    #
    # @return [ Void ]
    def git_clone(name, repo_with_branch)
      repo, branch = repo_with_branch.split('#')
      dir          = "#{@dir}/#{name}"

      sh "git clone --depth 1 -b #{branch} https://github.com/#{repo}.git #{dir}"
    end

    # Downloads the archive and extracts it.
    #
    # @param [ Symbol ] name The name of the dependency.
    # @param [ String ] url  A HTTP URI.
    #
    # @return [ Void ]
    def curl(name, url)
      sh "curl -L --fail --retry 3 --retry-delay 1 #{url} -s -o - | tar zxf -"

      Dir["#{name}-*"].each { |path| mv path, "#{@dir}/#{name}" }
    end
  end
end
