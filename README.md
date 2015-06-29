## Process Helper

Provides a wrapper around external processes

It collects standard-out and standard-error, allowing:

* the output to be searched for particular output
* the parent process wait for particular output to appear

## License

This is licensed under the Apache 2.0 License

## Example usage

```ruby
executable_args = ['echo', 'hello $USER, ruby passed me "$V"']
wait_for = /(hello .*)/
process = ProcessHelper::ProcessHelper.new()
process.start(executable_args, wait_for, 30, {'V' => 'v'})
```

This will start the process `echo` and wait for it to have printed a line matching the regex to STDOUT.


For a longer running process that you want to interact with:

```ruby
process = ProcessHelper::ProcessHelper.new()
process.start(['java', '-jar', 'some.jar'], /(Server Started)/)

# Interactions with the java process...

process.kill
process.wait_for_exit
```

## Caveats

There should be one ProcessHelper instance per external process. For example,
the following will only kill the second process.

```ruby
process = ProcessHelper::ProcessHelper.new()
process.start(['long_running_process', 'one'])
process.start(['long_running_process', 'two'])
process.kill
```
