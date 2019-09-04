# \~\~\~CONFIG:\~\~\~ data

### Using \~\~\~CONFIG\~\~\~: data

This is extra data, added to showoff's settings in `showoff.json`:

|                                               |                                |
| --------------------------------------------- | ------------------------------ |
| `data_string` (value should be "foo")         | ~~~CONFIG:data_string~~~       |
| `data_hash.foo.bar` (value should be "baz")   | ~~~CONFIG:data_hash.foo.bar~~~ |




### Missing or unsupported \~\~\~CONFIG:\~\~\~ data

Each of the following \~\~\~CONFIG:\~\~\~ keys should log a warning message and
fail to resolve:

|                         |                                    |
| ----------------------- | ---------------------------------- |
| `missing_string`        | ~~~CONFIG:missing_string~~~        |
| `data_hash.foo.missing` | ~~~CONFIG:data_hash.foo.missing~~~ |
| `data_list`             | ~~~CONFIG:data_list~~~             |
