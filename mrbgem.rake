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

def target_win32?
  return true if ENV['OS'] == 'Windows_NT'
  build.is_a?(MRuby::CrossBuild) && build.host_target.to_s =~ /mingw/
end

MRuby::Gem::Specification.new('mruby-ssh') do |spec|
  spec.license = 'MIT'
  spec.authors = 'Sebastian Katzer'
  spec.summary = 'mruby bindings for libssh2'

  spec.cc.include_paths << "#{dir}/mbedtls/include"
  spec.cc.include_paths += %W[#{dir}/ssh2/include #{dir}/ssh2/src]

  if target_win32?
    spec.cc.include_paths << "#{dir}/ssh2/win32"
    spec.linker.libraries << 'ws2_32'
  end

  file "#{dir}/mbedtls" do
    sh "curl -s https://tls.mbed.org/download/mbedtls-2.6.0-apache.tgz | tar xzC . && mv mbedtls-2.6.0 #{dir}/mbedtls"
  end

  file "#{dir}/ssh2" => "#{dir}/mbedtls" do
    sh "curl -s https://www.libssh2.org/download/libssh2-1.8.0.tar.gz | tar xzC . && mv libssh2-1.8.0 #{dir}/ssh2"
  end

  file "#{dir}/ssh2/src/libssh2_config.h" => "#{dir}/ssh2" do
    cp "#{dir}/libssh2_config.h", "#{dir}/ssh2/src/"
  end

  Rake::Task["#{dir}/ssh2/src/libssh2_config.h"].invoke

  spec.objs += Dir["#{dir}/mbedtls/library/*.c"].map! do |f|
    f.relative_path_from(dir).pathmap("#{build_dir}/%X.o")
  end

  spec.objs += Dir["#{dir}/ssh2/src/*.c"].map! do |f|
    f.relative_path_from(dir).pathmap("#{build_dir}/%X.o")
  end
end
