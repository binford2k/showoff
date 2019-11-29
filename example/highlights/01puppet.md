!SLIDE

## example 
    @@@ Puppet code_wrap nochrome
    class profile::mymodule{     
      file {'/my_module':
        ensure  => 'directory',
        owner   => 'root',
        group   => root,
      }
    }

## example 2


    @@@ Bash code_wrap nochrome
          class profile::mymodule{     
            file {'/my_module':
              ensure  => 'directory',
              owner   => 'root',
              group   => root,
            } 


