<!SLIDE>
# Code execution examples
## Click on each:

    @@@ Puppet execute
    file { '/tmp/foobs':
      ensure  => file,
      content => 'monkeys',
    }

.break text

    @@@ Ruby execute
    "Ruby version #{RUBY_VERSION} on #{RUBY_PLATFORM}"

.break text

    @@@ Python execute
    import sys
    print (sys.version)

.break text

    @@@ Perl execute
    printf("Perl version %d", $^V);
