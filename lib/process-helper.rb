# rubocop:disable Style/FileName
require 'English'

module ProcessHelper
  class ProcessHelper
    attr_reader :pid, :exit_status

    # opts can contain:
    # :print_lines:: echo the STDOUT and STDERR of the process to STDOUT as well as capturing them.
    # :poll_rate:: rate, in seconds (default is 0.25) to poll the capturered output for matching lines.
    def initialize(opts = {})
      @opts =
        {
          :print_lines => false
        }.merge!(opts)
    end

    # Starts a process defined by `command_and_args`
    # command_and_args:: Array with the first element as the process to start, the rest being the parameters to the new process.
    # output_to_wait_for:: Regex containing expected output, +start+ will block until a line of STDOUT matches this regex, if this is nil, then no waiting occurs.
    # wait_timeout:: Timeout while waiting for particular output.
    # env:: Hash of extra environment variables with which to start the process.
    def start(command_and_args = [], output_to_wait_for = nil, wait_timeout = nil, env = {}, opts = {})
      out_r, out_w = IO.pipe
      @out_log = ProcessLog.new(out_r, @opts).start
      if opts[:stderr]
        err_r, err_w = IO.pipe
        @err_log = ProcessLog.new(err_r, @opts).start
      else
        err_w = out_w
      end
      @pid = spawn(env, *command_and_args, :out => out_w, :err => err_w)
      out_w.close
      err_w.close if opts[:stderr]
      @out_log.wait_for_output(output_to_wait_for, :timeout => wait_timeout) unless output_to_wait_for.nil?
    end

    # returns true if the process exited with an exit code of 0.
    def wait_for_exit
      @out_log.wait
      @err_log.wait unless @err_log.nil?

      Process.wait(@pid)
      @exit_status = $CHILD_STATUS

      @pid = nil
      @exit_status == 0
    end

    # Send the specified signal to the wrapped process.
    def kill(signal = 'TERM')
      Process.kill(signal, @pid)
    end

    # Gets an array containing all the lines for the specified output stream.
    # +which+ can be either of:
    # * +:out+
    # * +:err+
    def get_log(which)
      log = _get_log(which)
      log.nil? ? [] : log.to_a
    end

    # Gets an array containing all the lines for the specified stream, emptying the stored buffer.
    # +which+ can be either of:
    # * +:out+
    # * +:err+
    def get_log!(which)
      log = _get_log(which)
      log.nil? ? [] : log.drain
    end

    # Blocks the current thread until the specified regex has been matched in the output.
    # +which+ can be either of:
    # * +:out+
    # * +:err+
    # opts can contain:
    # :timeout:: timeout in seconds to wait for the specified output.
    # :poll_rate:: rate, in seconds (default is 0.25) to poll the capturered output for matching lines.
    def wait_for_output(which, regexp, opts = {})
      _get_log(which).wait_for_output(regexp, opts)
    end

    private

    def _get_log(which)
      case which
      when :out
        @out_log
      when :err
        @err_log
      else
        fail "Unknown log '#{which}'"
      end
    end
  end

  class ProcessLog
    def initialize(io, opts, prefill = [])
      @io = io
      @lines = prefill.dup
      @mutex = Mutex.new
      @opts = opts
      @eof = false
    end

    def start
      @thread = Thread.new do
        @io.each_line do |l|
          l = TimestampedString.new(l)
          STDOUT.puts l if @opts[:print_lines]
          @mutex.synchronize { @lines.push l }
        end
        @mutex.synchronize { @eof = true }
      end
      self
    end

    def eof
      @mutex.synchronize { !!@eof }
    end

    def wait_for_output(regex, opts = {})
      opts = { :poll_rate => 0.25 }.merge(opts)
      opts[:timeout] ||= 30
      cutoff = Time.now + opts[:timeout].to_i
      until _any_line_matches(regex)
        sleep(opts[:poll_rate])
        fail "Timeout of #{opts[:timeout]} seconds exceeded while waiting for output that matches '#{regex}'" if Time.now > cutoff
        fail "EOF encountered while waiting for output that matches '#{regex}'" if eof and !_any_line_matches(regex)
      end
    end

    def wait
      @thread.join
      @thread = nil
      self
    end

    def to_a
      @mutex.synchronize { @lines.dup }
    end

    def drain
      @mutex.synchronize do
        r = @lines.dup
        @lines.clear
        r
      end
    end

    def to_s
      @mutex.synchronize { @lines.join '' }
    end

    private

    def _any_line_matches(regex)
      to_a.any? { |line| line.match(regex) }
    end
  end

  class TimestampedString < String
    attr_reader :time

    def initialize(string, time = nil)
      time ||= Time.now
      super(string)
      @time = time
    end
  end
end
