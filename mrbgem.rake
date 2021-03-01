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

require_relative 'lib/mruby/build'
require_relative 'lib/mruby/specification'
require_relative 'lib/ssh/downloader'

MRuby::Gem::Specification.new('mruby-ssh') do |spec|
  spec.license = 'MIT'
  spec.authors = 'Sebastian Katzer'
  spec.summary = 'SSH client for mruby'

  build.cc.defines << 'HAVE_MRB_SSH_H'

  if build.targets_win32?
    spec.cc.include_paths << "#{dir}/libssh2/win32"
    spec.linker.libraries += %w[ws2_32 advapi32]
  else
    spec.objs.delete objfile("#{build_dir}/src/getpass")
  end

  file "#{dir}/mbedtls" do
    download mbedtls: ENV.fetch('MBETTLS_VERSION', '2.25.0')
  end

  task "#{build.name}:mbedtls" => "#{dir}/mbedtls" do
    spec.cc.include_paths << "#{dir}/mbedtls/include"
    spec.objs += objfiles_relative_from_build_dir('mbedtls/library/*.c')
  end

  file "#{dir}/zlib" do
    download zlib: ENV.fetch('ZLIB_VERSION', '1.2.11')
  end

  task "#{build.name}:zlib" => "#{dir}/zlib" do
    spec.cc.include_paths << "#{dir}/zlib"
    spec.objs += objfiles_relative_from_build_dir('zlib/*.c')
  end

  file "#{dir}/libssh2" do
    download libssh2: ENV.fetch('LIBSSH2_VERSION', 'head')
    cp "#{dir}/libssh2_config.h", "#{dir}/libssh2/src/"
  end

  task "#{build.name}:libssh2" => "#{dir}/libssh2" do
    spec.export_include_paths << "#{dir}/libssh2/include"
    spec.cc.include_paths << "#{dir}/libssh2/include"
    spec.objs += objfiles_relative_from_build_dir('libssh2/src/*.c')
  end

  if build.link_lib?
    spec.linker.libraries << 'ssh2'
  else
    Rake::Task["#{build.name}:libssh2"].invoke
    Rake::Task["#{build.name}:mbedtls"].invoke unless build.link_crypto?
    Rake::Task["#{build.name}:zlib"].invoke if build.zlib?
  end

  if build.tiny_ssh?
    %w[channel stream session_ext].each do |f|
      spec.objs.delete objfile("#{build_dir}/src/#{f}")
      spec.rbfiles.delete "#{spec.dir}/mrblib/ssh/#{f}.rb"
      spec.test_rbfiles.delete "#{spec.dir}/test/#{f}.rb"
    end
  end
end
