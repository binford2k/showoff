<!SLIDE>
# Code highlighting examples
## Puppet

    @@@ Puppet
    file { '/tmp/foobs':
      ensure  => file,
      content => 'monkeys',
    }

<!SLIDE>
# Code highlighting examples
## Terminal Window

    @@@ Shell
    [root@localhost]# tree example
    example
    ├── directory
    │   ├── file.rb
    │   ├── file2.rb
    │   ├── notes.txt
    │   └── version.rb
    └── example.rb
