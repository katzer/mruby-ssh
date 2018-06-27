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

  spec.mruby.cc.defines     << 'HAVE_MRB_SSH_H'
  spec.export_include_paths << "#{dir}/ssh2/include"

  if target_win32?
    spec.cc.include_paths << "#{dir}/ssh2/win32"
    spec.linker.libraries += %w[ws2_32 advapi32]
  else
    spec.objs.delete objfile("#{build_dir}/src/getpass")
  end

  file "#{dir}/mbedtls" do
    download_mbedtls(dir, ENV.fetch('MBET_VERSION', '2.11.0'))
  end

  file "#{dir}/zlib" do
    download_zlib(dir, ENV.fetch('ZLIB_VERSION', '1.2.11'))
  end

  file "#{dir}/ssh2" => "#{dir}/mbedtls" do
    download_ssh2(dir, ENV.fetch('SSH2_VERSION', '1.8.0'))
    cp "#{dir}/libssh2_config.h", "#{dir}/ssh2/src/"
  end

  Rake::Task["#{dir}/ssh2"].invoke

  if spec.mruby.cc.defines.include? 'LIBSSH2_HAVE_ZLIB'
    Rake::Task["#{dir}/zlib"].invoke
  else
    rm_rf "#{dir}/zlib"
  end

  spec.cc.include_paths += Dir["#{dir}/{mbedtls/include,ssh2/include,zlib}"]

  spec.objs += Dir["#{dir}/{mbedtls/library,ssh2/src,zlib}/*.c"].map! do |f|
    f.relative_path_from(dir).pathmap("#{build_dir}/%X#{spec.exts.object}")
  end

  if spec.mruby.cc.defines.include?('MRB_SSH_TINY')
    %w[channel stream session_ext].each do |f|
      spec.objs.delete objfile("#{build_dir}/src/#{f}")
      spec.rbfiles.delete "#{spec.dir}/mrblib/ssh/#{f}.rb"
      spec.test_rbfiles.delete "#{spec.dir}/test/#{f}.rb"
    end
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
    sh "git clone --depth 1 git://github.com/ARMmbed/mbedtls.git #{dir}/mbedtls"
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
    sh "git clone --depth 1 git://github.com/libssh2/libssh2.git #{dir}/ssh2"
  else
    sh "curl -s --fail --retry 3 --retry-delay 1 https://www.libssh2.org/download/libssh2-#{version}.tar.gz | tar xzC . && mv libssh2-#{version} #{dir}/ssh2" # rubocop:disable LineLength
  end
end

# Download zlib.
#
# @param [ String ] dir     The place where to place them.
# @param [ String ] version The version to download.
#                           Defaults to: head
#
# @return [ Void ]
def download_zlib(dir, version = 'head')
  if version == 'head'
    sh "git clone --depth 1 git://github.com/madler/zlib.git #{dir}/zlib"
  else
    sh "curl -s --fail --retry 3 --retry-delay 1 http://zlib.net/zlib-#{version}.tar.gz | tar xzC . && mv zlib-#{version} #{dir}/zlib" # rubocop:disable LineLength
  end
end
