# encoding: utf-8
module Appium::Android
  # Returns an array of android classes that match the tag name
  # @param tag_name [String] the tag name to convert to an android class
  # @return [String]
  def tag_name_to_android tag_name
    tag_name = tag_name.to_s.downcase.strip

    # @private
    def prefix *tags
      tags.map!{ |tag| "android.widget.#{tag}" }
    end
    # note that 'secure' is not an allowed tag name on android
    # because android can't tell what a secure textfield is
    # they're all edittexts.

    # must match names in AndroidElementClassMap (Appium's Java server)
    case tag_name
      when 'button'
        prefix 'Button', 'ImageButton'
      when 'text'
        prefix 'TextView'
      when 'list'
        prefix 'ListView'
      when 'window', 'frame'
        prefix 'FrameLayout'
      when 'grid'
        prefix 'GridView'
      when 'relative'
        prefix 'RelativeLayout'
      when 'linear'
        prefix 'LinearLayout'
      when 'textfield'
        prefix 'EditText'
      else
        raise "Invalid tag name #{tag_name}"
    end # return result of case
  end
  # Find all elements matching the attribute
  # On android, assume the attr is name (which falls back to text).
  #
  # ```ruby
  #   find_eles_attr :text
  # ```
  #
  # @param tag_name [String] the tag name to search for
  # @return [Element]
  def find_eles_attr tag_name, attribute=nil
=begin
    sel1 = [ [4, 'android.widget.Button'], [100] ]
    sel2 = [ [4, 'android.widget.ImageButton'], [100] ]

    args = [ 'all', sel1, sel2 ]

    mobile :find, args
=end
    array = ['all']

    tag_name_to_android(tag_name).each do |name|
      # sel.className(name).getStringAttribute("name")
      array.push [ [4, name], [100] ]
    end

    mobile :find, array
  end

  # Selendroid only.
  # Returns a string containing interesting elements.
  # @return [String]
  def get_selendroid_inspect
    # @private
    def run node
      r = []

      run_internal = lambda do |node|
        if node.kind_of? Array
          node.each { |node| run_internal.call node }
          return
        end

        keys = node.keys
        return if keys.empty?

        obj = {}
        # name is id
        obj.merge!( { id: node['name'] } ) if keys.include?('name') && !node['name'].empty?
        obj.merge!( { text: node['value'] } ) if keys.include?('value') && !node['value'].empty?
        # label is name
        obj.merge!( { name: node['label'] } ) if keys.include?('label') && !node['label'].empty?
        obj.merge!( { class: node['type'] } ) if keys.include?('type') && !obj.empty?
        obj.merge!( { shown: node['shown'] } ) if keys.include?('shown')

        r.push obj if !obj.empty?
        run_internal.call node['children'] if keys.include?('children')
      end

      run_internal.call node
      r
    end

    json = get_source
    node = json['children']
    results = run node

    out = ''
    results.each { |e|
      no_text = e[:text].nil?
      no_name = e[:name].nil? || e[:name] == 'null'
      next unless e[:shown] # skip invisible
      # Ignore elements with id only.
      next if no_text && no_name

      out += e[:class].split('.').last + "\n"

      # name is id when using selendroid.
      # remove id/ prefix
      e[:id].sub!(/^id\//, '') if e[:id]

      out += "  class: #{e[:class]}\n"
      # id('back_button').click
      out += "  id: #{e[:id]}\n" unless e[:id].nil?
      # find_element(:link_text, 'text')
      out += "  text: #{e[:text]}\n" unless no_text
      # label is name. default is 'null'
      # find_element(:link_text, 'Facebook')
      out += "  name: #{e[:name]}\n" unless no_name
      # out += "  visible: #{e[:shown]}\n" unless e[:shown].nil?
    }
    out
  end

  # Android only.
  # Returns a string containing interesting elements.
  # @return [String]
  def get_android_inspect
    # @private
    def run node
      r = []

      run_internal = lambda do |node|
        if node.kind_of? Array
          node.each { |node| run_internal.call node }
          return
        end

        keys = node.keys
        return if keys.empty?

        obj = {}
        obj.merge!( { desc: node['@content-desc'] } ) if keys.include?('@content-desc') && !node['@content-desc'].empty?
        obj.merge!( { text: node['@text'] } ) if keys.include?('@text') && !node['@text'].empty?
        obj.merge!( { class: node['@class'] } ) if keys.include?('@class') && !obj.empty?

        r.push obj if !obj.empty?
        run_internal.call node['node'] if keys.include?('node')
      end

      run_internal.call node
      r
    end

    json = get_source
    node = json['hierarchy']
    results = run node

    out = ''
    results.each { |e|
      out += e[:class].split('.').last + "\n"

      out += "  class: #{e[:class]}\n"
      if e[:text] == e[:desc]
        out += "  text, name: #{e[:text]}\n" unless e[:text].nil?
      else
        out += "  text: #{e[:text]}\n" unless e[:text].nil?
        out += "  name: #{e[:desc]}\n" unless e[:desc].nil?
      end
    }
    out
  end

  # Automatically detects selendroid or android.
  # Returns a string containing interesting elements.
  # @return [String]
  def get_inspect
    @selendroid ? get_selendroid_inspect : get_android_inspect
  end

  # Intended for use with console.
  # Inspects and prints the current page.
  def page
    puts get_inspect
    nil
  end

  # JavaScript code from https://github.com/appium/appium/blob/master/app/android.js
  #
  # ```javascript
  # Math.round((duration * 1000) / 200)
  # (.20 * 1000) / 200 = 1
  # ```
  #
  # We want steps to be exactly 1. If it's zero then a tap is used instead of a swipe.
  def fast_duration
    0.20
  end
end # module Appium::Android