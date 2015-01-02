class Sane
  module API
    extend FFI::Library

    lib_paths = Array(ENV["SANE_LIB"] || Dir["/{opt,usr}/{,local/}lib{,64}/libsane.{1.dylib,so.1*}"])
    fallback_names = %w(libsane.1.dylib libsane.so.1 sane1.dll)
    ffi_lib(lib_paths + fallback_names)

    enum :status, [:good, 0, :unsupported, :cancelled, :device_busy, :inval, :eof, :jammed, :no_docs, :cover_open, :io_error, :no_mem, :access_denied]
    enum :value_type, [:bool, 0, :int, :fixed, :string, :button, :group]
    enum :unit, [:none, 0, :pixel, :bit, :mm, :dpi, :percent, :microsecond]
    enum :action, [:get_value, 0, :set_value, :set_auto]
    enum :frame, [:gray, :rgb, :red, :green, :blue]
    ConstraintType = enum :none, 0, :range, :word_list, :string_list

    class Device < FFI::Struct
      layout :name, :string, :vendor, :string, :model, :string, :type, :string

      def to_hash
        {
          :name => self[:name],
          :vendor => self[:vendor],
          :model => self[:model],
          :type => self[:type]
        }
      end
    end

    class OptionDescriptor < FFI::Struct
      class Range < Struct.new(:min, :max, :quant)
        include Comparable
        include Enumerable
        def <=> x
          (min..max) <=> x
        end

        def include? x
          (min..max).include?( x) and 0 == (x-min) % quant
        end

        def === x
          x.kind_of?( Numeric) and include?( x)
        end

        def each
          min.step( max, [1,quant].max)
        end
      end

      layout :name, :string,
        :title, :string,
        :desc, :string,
        :type, :value_type,
        :unit, :unit,
        :size, :int,
        :cap, :int,
        :constraint_type, ConstraintType,
        :constraint, :pointer

      alias method_missing []

      def constraint
        c = self[:constraint]
        case self[:constraint_type]
        when 0, :none then nil
        when 1, :range
          Range.new *c.read_array_of_int( 3)
        when 2, :word_list
          c[FFI::Type::INT.size].read_array_of_int c.read_int
        when 3, :string_list
          i, r, p = 0, [], nil
          while 0 < (p = c[i].read_pointer).address
            STDERR.puts p.inspect
            r << p.read_string_to_null
            i += FFI::Type::POINTER.size
          end
          r
        end
      end

      def to_hash
        {
          :name => self[:name],
          :title => self[:title],
          :desc => self[:desc],
          :type => self[:type],
          :unit => self[:unit],
          :size => self[:size],
          :cap => self[:cap],
          :constraint => constraint
        }
      end
    end

    class Parameters < FFI::Struct
      layout :format, :frame, :last_frame, :int, :bytes_per_line, :int, :pixels_per_line, :int, :lines, :int, :depth, :int

      def to_hash
        {
          :format => self[:format],
          :last_frame => self[:last_frame],
          :bytes_per_line => self[:bytes_per_line],
          :pixels_per_line => self[:pixels_per_line],
          :lines => self[:lines],
          :depth => self[:depth]
        }
      end
    end

    # extern SANE_Status sane_init (SANE_Int * version_code, SANE_Auth_Callback authorize);
    attach_function :sane_init, [:pointer, :pointer], :status
    # extern void sane_exit (void);
    attach_function :sane_exit, [], :void
    # extern SANE_Status sane_get_devices (const SANE_Device *** device_list, SANE_Bool local_only);
    attach_function :sane_get_devices, [:pointer, :int], :status
    # extern SANE_Status sane_open (SANE_String_Const devicename, SANE_Handle * handle);
    attach_function :sane_open, [:string, :pointer], :status
    # extern void sane_close (SANE_Handle handle);
    attach_function :sane_close, [:pointer], :void
    # extern const SANE_Option_Descriptor * sane_get_option_descriptor (SANE_Handle handle, SANE_Int option);
    attach_function :sane_get_option_descriptor, [:pointer, :int], :pointer
    # extern SANE_Status sane_control_option (SANE_Handle handle, SANE_Int option, SANE_Action action, void *value, SANE_Int * info);
    attach_function :sane_control_option, [:pointer, :int, :action, :pointer, :pointer], :status
    # extern SANE_Status sane_get_parameters (SANE_Handle handle, SANE_Parameters * params);
    attach_function :sane_get_parameters, [:pointer, :pointer], :status
    # extern SANE_Status sane_start (SANE_Handle handle);
    attach_function :sane_start, [:pointer], :status
    # extern SANE_Status sane_read (SANE_Handle handle, SANE_Byte * data, SANE_Int max_length, SANE_Int * length);
    attach_function :sane_read, [:pointer, :pointer, :int, :pointer], :status
    # extern void sane_cancel (SANE_Handle handle);
    attach_function :sane_cancel, [:pointer], :void
    # extern SANE_Status sane_set_io_mode (SANE_Handle handle, SANE_Bool non_blocking);
    attach_function :sane_set_io_mode, [:pointer, :int], :status
    # extern SANE_Status sane_get_select_fd (SANE_Handle handle, SANE_Int * fd);
    attach_function :sane_get_select_fd, [:pointer, :pointer], :status
    # extern SANE_String_Const sane_strstatus (SANE_Status status);
    attach_function :sane_strstatus, [:status], :string
  end
end
