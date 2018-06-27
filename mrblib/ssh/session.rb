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
  # A session class representing the connection service running on top of the
  # SSH transport layer. It manages the creation of channels (see open_channel),
  # and the dispatching of messages to the various channels.
  #
  # You will rarely (if ever) need to instantiate this class directly; rather,
  # you'll almost always use Net::SSH.start to initialize a new network
  # connection, authenticate a user, and return a new connection session, all in
  # one call.
  class Session
    # Creates and returns a new SSH::Session object. If a host is given,
    # a connection is made.
    #
    # @param [ String ] host Optional host name.
    # @param [ Hash ]   opts Each key of which is a symbol.
    #
    # @return [ SSH::Session ]
    def initialize(host = nil, opts = {})
      @properties = (opts[:properties] || {}).dup

      return unless host

      SSH.startup
      connect(host, opts)

      __login__(opts)
    end

    # The hostname specified when calling 'connect'.
    #
    # @return [ String ]
    attr_reader :host

    # A hash of properties. These can be used to store
    # state information about this session.
    #
    # @return [ Hash ]
    attr_reader :properties

    # If the socket is connected to the host.
    #
    # @return [ Boolean ]
    def connected?
      !closed?
    end

    # Retrieves a custom property from this instance. This can be used to store
    # additional state in applications that must manage multiple SSH sessions.
    #
    # @param [ Object ] key The name of the property.
    #
    # @return [ Object ] The associated value.
    def [](key)
      @properties[key]
    end

    # Sets a custom property for this instance.
    #
    # @param [ Object ] key   The name of the property.
    # @param [ Object ] value The property value.
    #
    # @return [ Object ] The property value.
    def []=(key, value)
      @properties[key] = value
    end

    # Authenticate the SSH session without any interactive prompts
    # if the password is nil.
    #
    # @param [ String ] user The username to login.
    # @param [ String ] pass Optional password.
    #
    # @return [ Void ]
    def login_without_password_prompt(user, pass = nil)
      login(user, pass, false)
    end

    # Authenticate the SSH session with public/private key pair.
    #
    # @param [ String ] user   The username to login.
    # @param [ String ] key    The path of the private key.
    # @param [ String ] phrase Optional passphrase for the key.
    #
    # @return [ Void ]
    def login_with_public_key(user, key, phrase = nil)
      login(user, key, nil, true, phrase)
    end

    # List of supported authentication methods.
    #
    # @param [ String ] user Username which will be used while authenticating.
    #
    # @return [ Array<String> ] nil if already authenticated.
    def userauth_methods(user)
      userauth_list(user).split(',')
    rescue NoMethodError
      []
    end

    # Test if the method is supported for the user.
    #
    # @param [ String ] user Username which will be used while authenticating.
    # @param [ String ] method The method to check for.
    #
    # @return [ Boolean ]
    def userauth_method_supported?(user, method)
      userauth_methods(user).include? method
    end

    private

    # Do the login after connect.
    #
    # @param [ Hash<Symbol, String> ] opts See SSH::Session#initialize
    #
    # @return [ Void ]
    def __login__(opts)
      return unless opts[:user]

      if opts[:key]
        login(opts[:user], opts[:key], nil, true, opts[:passphrase])
      else
        login(opts[:user], opts[:password], opts[:non_interactive] != true)
      end
    end
  end
end
