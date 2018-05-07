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

MRuby::Gem::Specification.new('mruby-ssh') do |spec|
  spec.license = 'MIT'
  spec.authors = 'Sebastian Katzer'
  spec.summary = 'SSH client for mruby'

  spec.export_include_paths << "#{dir}/ssh2/include"
  spec.cc.include_paths += %W[#{dir}/mbedtls/include #{dir}/ssh2/include]

  if target_win32?
    spec.cc.include_paths << "#{dir}/ssh2/win32"
    spec.linker.libraries += %w[ws2_32 advapi32]
  end

  file "#{dir}/mbedtls" do
    download_mbedtls(dir, ENV.fetch('MBET_VERSION', '2.9.0'))
  end

  file "#{dir}/ssh2" => "#{dir}/mbedtls" do
    download_ssh2(dir, ENV.fetch('SSH2_VERSION', '1.8.0'))
    cp "#{dir}/libssh2_config.h", "#{dir}/ssh2/src/"
  end

  Rake::Task["#{dir}/ssh2"].invoke

  spec.objs += Dir["#{dir}/{mbedtls/library,ssh2/src}/*.c"].map! do |f|
    f.relative_path_from(dir).pathmap("#{build_dir}/%X#{spec.exts.object}")
  end
end

# If the build target points to Windows OS.
#
# @return [ Boolean ]
def target_win32?
  return true if ENV['OS'] == 'Windows_NT'
  build.is_a?(MRuby::CrossBuild) && build.host_target.to_s =~ /mingw/
end

# Download mbedtls.
#
# @param [ String ] dir     The place where to place them.
# @param [ String ] version The version to download.
#                           Defaults to: head
#
# @return [ Void ]
def download_mbedtls(dir, version = 'head')
  if version == 'head'
    sh "git clone git://github.com/ARMmbed/mbedtls.git #{dir}/mbedtls"
  else
    sh "curl -s --fail --retry 3 --retry-delay 1 https://tls.mbed.org/download/mbedtls-#{version}-apache.tgz | tar xzC . && mv mbedtls-#{version} #{dir}/mbedtls" # rubocop:disable LineLength
  end
end

# Download libssh2.
#
# @param [ String ] dir     The place where to place them.
# @param [ String ] version The version to download.
#                           Defaults to: head
#
# @return [ Void ]
def download_ssh2(dir, version = 'head')
  if version == 'head'
    sh "git clone git://github.com/libssh2/libssh2.git #{dir}/ssh2"
  else
    sh "curl -s --fail --retry 3 --retry-delay 1 https://www.libssh2.org/download/libssh2-#{version}.tar.gz | tar xzC . && mv libssh2-#{version} #{dir}/ssh2" # rubocop:disable LineLength
  end
end
