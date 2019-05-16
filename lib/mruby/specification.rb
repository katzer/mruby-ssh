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

class MRuby::Gem::Specification
  # Download the dependency.
  #
  # @param [ Symbol ] name    The name of the dependency.
  # @param [ String ] version The version to download.
  #
  # @return [ Void ]
  def download(**args)
    (@__downloader ||= SSH::Downloader.new(dir)).download(*args.first)
  end

  # Converts the path of the source file (e.g. file.c)
  # into the path for the object file (e.g. file.o).
  #
  # @param [ Pathname ] path The path of the sourcefile
  #
  # @return [ Pathname ]
  def objfile_relative_from_build_dir(path)
    path.relative_path_from(dir).pathmap("#{build_dir}/%X#{exts.object}")
  end
end
