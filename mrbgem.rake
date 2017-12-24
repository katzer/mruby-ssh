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
  spec.summary = 'mruby bindings for libssh2'

  spec.add_test_dependency 'mruby-print', core: 'mruby-print'

  target = build.name
  target = RbConfig::CONFIG['target'] if target == 'host'
  target = target[0..-3]              if target =~ /darwin/
  target += '-glibc-2.12'             if target =~ /linux/ && target !~ /glibc/ && system(%(exit "$(readelf -V $(which ruby) | grep -c 'GLIBC_2.14')"))

  libs = %w[ssh2 mbedtls mbedx509 mbedcrypto]
  libs << 'z'          if target =~ /(musl|mingw32)/
  libs << 'winpthread' if target == 'i686-w64-mingw32'
  libs.map! { |lib| %("#{spec.dir}/lib/#{target}/lib#{lib}.a") }

  case target
  when /mingw/
    build.linker.libraries << 'ws2_32'
    build.linker.libraries << 'pthread' if target !~ /i686/
  when /glibc/
    build.linker.libraries << 'rt'
  when /musl/
    build.linker.libraries << 'pthread'
  else
    build.linker.libraries += %w[z pthread]
  end

  build.linker.link_options.sub!('{objs}', "{objs} #{libs.join(' ')}")
end
