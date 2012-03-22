require 'ffi'
require 'stringio'

module MP3Lame
  extend FFI::Library
  base_path = File.dirname(__FILE__)
  case RUBY_PLATFORM
    when /darwin/
  	  ffi_lib File.join(base_path, 'libs/lame/macos/libmp3lame.0.dylib')
    when /mingw/
  		ffi_lib File.join(base_path, 'libs/lame/win/libmp3lame.dll')
  end
  
  ffi_convention :stdcall
  
  class Report < FFI::Struct
    layout :msgf, :pointer,
           :debugf, :pointer,
           :errorf, :pointer
  end
  
  class AsmOptimizations < FFI::Struct
    layout :mmx, :int,
           :amd3dnow, :int,
           :sse, :int
  end
  
  class LameGlobalFlags < FFI::Struct
    layout :class_id, :uint,
           :num_samples, :ulong,
           :num_channels, :int,
           :in_samplerate, :int,
           :out_samplerate, :int,
           :scale, :float,
           :scale_left, :float,
           :scale_right, :float,
           :analysis, :int,
           :bWriteVbrTag, :int,
           :decode_only, :int,
           :quality, :int,
           :mode, :int,
           :force_ms, :int,
           :free_format, :int,
           :findReplayGain, :int,
           :decode_on_the_fly, :int,
           :write_id3tag_automatic, :int,
           :brate, :int,
           :compression_ratio, :float,
           :copyright, :int,
           :original, :int,
           :extension, :int,
           :emphasis, :int,
           :error_protection, :int,
           :strict_ISO, :int,
           :disable_reservoir, :int,
           :quant_comp, :int,
           :quant_comp_short, :int,
           :experimentalY, :int,
           :experimentalZ, :int,
           :exp_nspsytune, :int,
           :preset, :int,
           :VBR, :int,
           :VBR_q_frac, :int,
           :VBR_q, :int,
           :VBR_mean_bitrate_kbps, :int,
           :VBR_min_bitrate_kbps, :int,
           :VBR_max_bitrate_kbps, :int,
           :VBR_hard_min, :int,
           :lowpassfreq, :int,
           :highpassfreq, :int,
           :lowpasswidth, :int,
           :highpasswidth, :int,
           :maskingadjust, :float,
           :maskingadjust_short, :float,
           :ATHonly, :int,
           :ATHshort, :int,
           :noATH, :int,
           :ATHtype, :int,
           :ATHcurve, :float,
           :ATHlower, :float,
           :athaa_type, :int,
           :athaa_loudapprox, :int,
           :athaa_sensitivity, :int,
           :short_blocks, :int,
           :useTemporal, :int,
           :interChRatio, :float,
           :msfix, :float,
           :tune, :int,
           :tune_value_a, :float,
           :report, Report,
           :version, :int,
           :encoder_delay, :int,
           :encoder_padding, :int,
           :framesize, :int,
           :frameNum, :int,
           :lame_allocated_gfp, :int,
           :internal_flags, :pointer,
           :asm_optimizations, AsmOptimizations 
  end

  attach_function :get_lame_version, [], :string

  attach_function :lame_init, [], :pointer
  attach_function :lame_set_num_channels, [:pointer, :int], :void
  attach_function :lame_set_in_samplerate, [:pointer, :int], :void
  attach_function :lame_set_brate, [:pointer, :int], :void
  attach_function :lame_set_mode, [:pointer, :int], :void
  attach_function :lame_set_quality, [:pointer, :int], :void
  
  attach_function :lame_init_params, [:pointer], :int
  attach_function :lame_encode_buffer, [:pointer, :pointer, :pointer, :int, :pointer, :int], :int
  attach_function :lame_encode_buffer_float, [:pointer, :pointer, :pointer, :int, :pointer, :int], :int
  attach_function :lame_encode_flush, [:pointer , :pointer, :int], :int
  attach_function :lame_encode_finish, [:pointer , :pointer, :int], :int
end

class MP3Encoder
  def initialize(n_channels, sample_rate)
    @n_channels = n_channels
    @sample_rate = sample_rate
    
    @mp3lame = MP3Lame::lame_init
    @buffer = nil
    
    gfp = MP3Lame::LameGlobalFlags.new(@mp3lame)
    MP3Lame::lame_set_num_channels(@mp3lame, @n_channels)
    MP3Lame::lame_set_in_samplerate(@mp3lame, @sample_rate)
    MP3Lame::lame_set_brate(@mp3lame, 128)
    MP3Lame::lame_set_mode(@mp3lame,1);
    MP3Lame::lame_set_quality(@mp3lame,2);
    puts gfp[:num_channels]
    puts gfp[:in_samplerate]
    puts gfp[:mode]
    puts gfp[:quality]
    puts gfp[:brate]
    
    return true if MP3Lame::lame_init_params(@mp3lame) >= 0
    return nil
  end
  
  def feed(left, right, file_name='encoded_channel')
    puts left.class, left.size
    puts right.class, right.size
    
    to_read = [left.size, right.size].min
    num_samples = to_read
    buffer_size = 1.25 * num_samples + 7200
    
    puts "required #{buffer_size.ceil} bytes to process #{num_samples} wav samples"
    
    buffer = FFI::MemoryPointer.new(:float, buffer_size.ceil)
    
    left_pcm = left.shift(to_read).pack 'F*'
    right_pcm = right.shift(to_read).pack 'F*'
    
    puts "#{left_pcm.bytesize} bytes LEFT CHANNEL"
    puts "#{right_pcm.bytesize} bytes RIGHT CHANNEL"
    
    mp3_bytes = MP3Lame::lame_encode_buffer_float(@mp3lame, left_pcm, right_pcm, num_samples, buffer, buffer_size)
    File.open(file_name, 'ab') {|f| f.write(buffer.read_string(mp3_bytes)) }
    puts "encoded #{mp3_bytes} bytes of MP3 data"
    
    mp3_bytes = MP3Lame::lame_encode_flush(@mp3lame, buffer, buffer_size)
    File.open(file_name, 'ab') {|f| f.write(buffer.read_string(mp3_bytes)) }
    puts "flushed #{mp3_bytes} bytes of MP3 data"
  end
end

