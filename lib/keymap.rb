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
      'z'           => 'HELP',
      '/'           => 'HELP',
      '?'           => 'HELP',
      'b'           => 'BLANK',
      'f'           => 'FOOTER',
      'g'           => 'FOLLOW',
      'n'           => 'NOTES',
      'esc'         => 'CLEAR',
      'p'           => 'PAUSE',
      'P'           => 'PRESHOW',
      'x'           => 'EXECUTE',
    }
  end
end
