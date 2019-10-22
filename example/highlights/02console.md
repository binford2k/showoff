!SLIDE

## example1

    @@@ Console code_wrap nochrome
    class profile::mymodule{ 
        
      file {'/my_module':
        ensure  => 'directory',
        owner   => 'root',
        group   => root,
      }
    }

## example 2

    @@@ PowerShellConsole code_wrap nochrome
    class profile::mymodule{ 
      
        
      file {'/my_module':
        ensure  => 'directory',
        owner   => 'root',
        group   => root,
      }
    }