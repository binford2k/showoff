module Keymap
  def self.default()
    {
      'space'       => 'NEXT',
      'd'           => 'DEBUG',
      'up'          => 'PREV',
      'left'        => 'PREV',
      'pageup'      => 'PREV',
      'down'        => 'NEXT',
      'right'       => 'NEXT',
      'pagedown'    => 'NEXT',
      'r'           => 'RELOAD',
      'c'           => 'CONTENTS',
      't'           => 'CONTENTS',
      'h'           => 'HELP',
      '/'           => 'HELP',
      '?'           => 'HELP',
      'b'           => 'BLANK',
      '.'           => 'BLANK',
      'F'           => 'FOOTER',
      'f'           => 'FOLLOW',
      'n'           => 'NOTES',
      'esc'         => 'CLEAR',
      'p'           => 'PAUSE',
      'P'           => 'PRESHOW',
      'x'           => 'EXECUTE',
      'f5'           => 'EXECUTE',
    }
  end
end
