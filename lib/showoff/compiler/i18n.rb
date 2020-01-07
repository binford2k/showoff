# Adds slide language selection to the compiler
class Showoff::Compiler::I18n

  def self.selectLanguage!(content)
    translations = {}
    content.scan(/^((~~~LANG:([\w-]+)~~~\n)(.+?)(\n~~~ENDLANG~~~))/m).each do |match|
      markup, opentag, code, text, closetag = match
      translations[code] = {:markup => markup, :content => text}
    end

    lang = Showoff::Locale.resolve(translations.keys).to_s

    translations.each do |code, translation|
      if code == lang
        content.sub!(translation[:markup], translation[:content])
      else
        content.sub!(translation[:markup], "\n")
      end
    end

    content
  end

end
