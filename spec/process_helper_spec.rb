require 'spec_helper'

def run(*args)
  process = ProcessHelper::ProcessHelper.new
  process.start(*args)
  process.wait_for_exit
  process
end

module ProcessHelper

  describe ProcessHelper do
    context 'Things...' do
      it 'It should start a process and capture the exit status (success)' do
        process = ProcessHelper.new
        process.start('true')
        expect(process.wait_for_exit).to eq(true)
        expect(process.exit_status).to eq(0)
      end

      it 'It should start a process and capture the exit status (failure)' do
        process = ProcessHelper.new
        process.start('false')
        expect(process.wait_for_exit).to eq(false)
        expect(process.exit_status).to eq(1 << 8)
      end

      it 'It should pass arguments' do
        process = ProcessHelper.new
        process.start(['sh', '-c', 'exit 4'])
        expect(process.wait_for_exit).to eq(false)
        expect(process.exit_status).to eq(4 << 8)
      end

      it 'It capture the exit status (signal)' do
        process = ProcessHelper.new
        process.start(%w(sleep 10))
        process.kill
        expect(process.wait_for_exit).to eq(false)
        expect(Signal.signame(process.exit_status.to_i)).to eq('TERM')
      end

      it 'It should expose stdout' do
        process = run(['sh', '-c', 'echo hello ; echo there'])
        out = process.get_log(:out)
        expect(out).to eq(["hello\n", "there\n"])
      end

      it 'It should expose stdout and stderr' do
        process = run(['sh', '-c', 'echo hello; echo there >&2'])
        expect(process.get_log(:out)).to eq(["hello\n", "there\n"])
        expect(process.get_log(:err)).to eq([])
      end

      it 'It should expose stderr' do
        process = run(['sh', '-c', 'echo hello >&2; echo there >&2'], nil, nil, {}, stderr: true)
        expect(process.get_log(:err)).to eq(["hello\n", "there\n"])
      end

      it 'It should expose the pid' do
        process = ProcessHelper.new
        process.start(['sh', '-c', 'echo this is process $$'])
        pid = process.pid
        process.wait_for_exit
        out = process.get_log(:out)
        expect(out[0]).to eq("this is process #{pid}\n")
      end

      it 'It should timestamp the logs' do
        t0 = Time.now
        process = run(['sh', '-c', 'echo a ; sleep 1 ; echo b ; sleep 1 ; echo c'])
        t1 = Time.now

        out = process.get_log(:out)
        expect(out[0].time).to be >= t0
        # For some reason my attempts to use be_within failed...
        expect(out[1].time).to be > out[0].time - 1.1
        expect(out[1].time).to be < out[0].time + 1.1
        expect(out[2].time).to be > out[1].time - 1.1
        expect(out[2].time).to be < out[1].time + 1.1
        expect(t1).to be >= out[2].time

        expect(out.join('')).to eq("a\nb\nc\n")
      end

      it 'It should wait for a pattern in stdout' do
        t0 = Time.now
        process = ProcessHelper.new
        process.start(
          ['sh', '-c', 'echo frog >&2 ; sleep 1 ; echo cat ; sleep 1 ; echo dog ; sleep 1 ; echo frog'],
          /fro/, nil, {}, stderr: true
        )
        t1 = Time.now

        expect(t1).to be > (t0 + 3)
        expect(t1).to be < (t0 + 5)

        startup_log = process.get_log(:out)
        expect(startup_log.size).to eq(3)
        expect(startup_log[-1]).to eq("frog\n")
      end

      it 'It should give up when EOF is hit' do
        t0 = Time.now
        process = ProcessHelper.new
        expect {
          process.start(
            ['sh', '-c', 'sleep 1'],
            /this message never appears/,
            5,
          )
        }.to raise_error(/EOF/)
        t1 = Time.now

        expect((t1-t0-1).abs).to be < 0.5 # didn't wait for timeout
      end

      it 'It should be able to arbitrarly wait for output' do
        t0 = Time.now
        process = ProcessHelper.new
        process.start(
          ['sh', '-c', 'echo frog >&2 ; sleep 1 ; echo cat ; sleep 1 ; echo dog ; sleep 1 ; echo frog; sleep 3; echo goat'],
          /fro/, nil, {}, stderr: true
        )
        t1 = Time.now

        expect(t1).to be > t0 + 3
        expect(t1).to be < t0 + 5

        process.wait_for_output(:out, /goat/)
        t2 = Time.now
        expect(t2).to be > t0 + 6
        expect(t2).to be < t0 + 8
      end

      it 'It should support draining the logs' do
        process = ProcessHelper.new
        process.start(
          ['bash', '-c', 'for ((i=0; $i<10; i=$i+1)) ; do echo out $i ; echo err $i >&2 ; sleep 1 ; done'],
          nil, nil, {}, stderr: true
        )

        sleep 3
        out = process.get_log! :out
        err = process.get_log! :err
        expect(out.size).to be > 1
        expect(err.size).to be > 1

        process.wait_for_exit
        out2 = process.get_log :out
        err2 = process.get_log :err

        expect((out + out2).size).to eq(10)
        expect((err + err2).size).to eq(10)

        out3 = process.get_log! :out
        err3 = process.get_log! :err
        expect(out3).to eq(out2)
        expect(err3).to eq(err2)

        expect(process.get_log(:out).size).to eq(0)
        expect(process.get_log(:err).size).to eq(0)
      end
    end
  end
end
