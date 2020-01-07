require 'i18n'
require 'i18n/backend/fallbacks'
require 'iso-639'

I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
I18n.load_path += Dir[File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'locales', '*.yml'))]
I18n.backend.load_translations
I18n.enforce_available_locales = false

class Showoff::Locale
  @@contentLocale = nil

  # Set the minimized canonical version of the specified content locale, selecting
  # the nearest match to whatever exists in the presentation's locales directory.
  # If the locale doesn't exist on disk, it will just default to no translation
  #
  # @todo: I don't think this is right at all -- it doesn't autoselect content
  #   languages, just built in Showoff languages. It only worked by accident before
  #
  # @param user_locale [String, Symbol] The locale to select.
  #
  # @returns [Symbol] The selected and saved locale.
  def self.setContentLocale(user_locale = nil)
    if [nil, '', 'auto'].include? user_locale
      languages = I18n.available_locales
      @@contentLocale = I18n.fallbacks[I18n.locale].select { |f| languages.include? f }.first
    else
      locales = Dir.glob('*',  :base => "#{Showoff::Config.root}/locales")
      locales.delete 'strings.json'

      @@contentLocale = with_locale(user_locale) do |str|
        str.to_sym if locales.include? str
      end
    end
  end

  def self.contentLocale
    @@contentLocale
  end

  # Find the closest match to current locale in an array of possibilities
  #
  # @param items [Array] An array of possibilities to check
  # @return [Symbol] The closest match to the current locale.
  def self.resolve(items)
    with_locale(contentLocale) do |str|
      str.to_sym if items.include? str
    end
  end

  # Turns a locale code into a string name
  #
  # @param locale [String, Symbol] The code of the locale to translate
  # @returns [String] The name of the locale.
  def self.languageName(locale = contentLocale)
    with_locale(locale) do |str|
      result = ISO_639.find(str)
      result[3] unless result.nil?
    end
  end

  # This function returns the directory containing translated *content*, defaulting
  # to the presentation root. This works similarly to I18n fallback, but we cannot
  # reuse that as it's a different translation mechanism.

  # @returns [String] Path to the translated content.
  def self.contentPath
    root = Showoff::Config.root

    with_locale(contentLocale) do |str|
      path = "#{root}/locales/#{str}"
      return path if File.directory?(path)
    end || root
  end

  # Generates a hash of all language codes available and the long name description of each
  #
  # @returns [Hash] The language code/name hash.
  def self.contentLanguages
    root = Showoff::Config.root

    strings = JSON.parse(File.read("#{root}/locales/strings.json")) rescue {}
    locales = Dir.glob("#{root}/locales/*")
                 .select {|f| File.directory?(f) }
                 .map    {|f| File.basename(f)   }

    (strings.keys + locales).inject({}) do |memo, locale|
      memo.update(locale => languageName(locale))
    end
  end


  # Generates a hash of all translations for the current language. This is used
  # for the javascript half of the UI translations
  #
  # @returns [Hash] The locale code/strings hash.
  def self.translations
    languages = I18n.backend.send(:translations)
    fallback  = I18n.fallbacks[I18n.locale].select { |f| languages.keys.include? f }.first
    languages[fallback]
  end

  # Finds the language key from strings.json and returns the strings hash. This is
  # used for user translations in the presentation content, e.g. SVG translations.
  #
  # @returns [Hash] The user translation code/strings hash.
  def self.userTranslations
    path = "#{Showoff::Config.root}/locales/strings.json"
    return {} unless File.file? path
    strings = JSON.parse(File.read(path)) rescue {}

    with_locale(contentLocale) do |key|
      return strings[key] if strings.include? key
    end
    {}
  end

  # This is just a unified lookup method that takes a full locale name
  # and then resolves it to an available version of the name
  def self.with_locale(locale)
    locale = locale.to_s
    until (locale.empty?) do
      result = yield(locale)
      return result unless result.nil?

      # if not found, chop off a section and try again
      locale = locale.rpartition(/[-_]/).first
    end
  end
  private_class_method :with_locale

end
