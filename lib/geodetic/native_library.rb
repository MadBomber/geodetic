# frozen_string_literal: true

require 'fiddle'

module Geodetic
  # Mixin for modules that bind to a native C/C++ shared library via Fiddle.
  #
  # Provides the common infrastructure for discovering, loading, and binding
  # functions from optional system libraries (GEOS, H3, S2, etc.).
  #
  # Usage:
  #   module LibFoo
  #     extend Geodetic::NativeLibrary
  #
  #     load_library(
  #       env_var: 'LIBFOO_PATH',
  #       lib_name: 'libfoo',
  #       error_message: "libfoo not found. Install: brew install foo"
  #     )
  #
  #     F_SOME_FUNC = bind('some_func', [INT, DBL], PTR)
  #   end
  #
  # The extending module gets:
  #   - available? / require_library! / handle class methods
  #   - bind(name, args, ret) for creating Fiddle::Function bindings
  #   - Fiddle type constants: PTR, INT, DBL, CHAR, VOID, UINT64, INT64

  module NativeLibrary
    # Fiddle type aliases — copied into each extending module
    PTR    = Fiddle::TYPE_VOIDP
    INT    = Fiddle::TYPE_INT
    CHAR   = Fiddle::TYPE_CHAR
    DBL    = Fiddle::TYPE_DOUBLE
    VOID   = Fiddle::TYPE_VOID
    UINT64 = -Fiddle::TYPE_LONG_LONG   # unsigned
    INT64  = Fiddle::TYPE_LONG_LONG

    # Standard search directories for shared libraries across platforms
    LIBRARY_SEARCH_DIRS = [
      '/opt/homebrew/lib',             # macOS ARM64 (Homebrew)
      '/usr/local/lib',                # macOS x86_64 / manual installs
      '/usr/lib',                      # Linux system
      '/usr/lib/x86_64-linux-gnu',     # Debian/Ubuntu x86_64
      '/usr/lib/aarch64-linux-gnu',    # Debian/Ubuntu ARM64
    ].freeze

    def self.extended(mod)
      mod.instance_variable_set(:@handle, nil)
      mod.instance_variable_set(:@available, false)

      # Copy type constants into the extending module
      constants.each do |name|
        next if name == :LIBRARY_SEARCH_DIRS
        mod.const_set(name, const_get(name)) unless mod.const_defined?(name)
      end
    end

    attr_reader :handle

    def available?
      @available
    end

    def require_library!
      return if @available
      raise Geodetic::Error, @error_message
    end

    # Bind a named symbol to a Fiddle::Function.
    # Returns nil (instead of raising) when the library is unavailable
    # or the symbol is not found, so bindings can be defined at load time.
    def bind(name, args, ret)
      return nil unless @available
      ptr = @handle[name]
      Fiddle::Function.new(ptr, args, ret)
    rescue Fiddle::DLError
      nil
    end

    # Discover and load a shared library.
    #
    # Options:
    #   env_var:        Environment variable for a custom library path (e.g. 'LIBGEOS_PATH')
    #   lib_name:       Base library name without extension (e.g. 'libgeos_c')
    #   lib_names:      Array of base names to try (e.g. ['libs2', 'libs2.0'])
    #   error_message:  Message for require_library! when the library is missing
    def load_library(env_var:, lib_name: nil, lib_names: nil, error_message:)
      @error_message = error_message

      names = lib_names || [lib_name]
      search_paths = build_search_paths(env_var, names)

      begin
        path = search_paths.find { |p| File.exist?(p) }
        if path
          @handle = Fiddle.dlopen(path)
          @available = true
        end
      rescue Fiddle::DLError
        @available = false
      end
    end

    private

    def build_search_paths(env_var, lib_names)
      paths = []

      # User-specified path takes priority
      custom = ENV[env_var]
      paths << custom if custom

      # Generate platform-specific paths for each library name
      lib_names.each do |name|
        LIBRARY_SEARCH_DIRS.each do |dir|
          paths << "#{dir}/#{name}.dylib"
          paths << "#{dir}/#{name}.so"
        end
      end

      paths.freeze
    end
  end
end
