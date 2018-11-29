require 'prawn'

Prawn::Document.class_eval do
  def styled_text( data, opts = {} )
    parts = []
    text_options = {}
    extra_options = { margin_left: 0 }
    oga = Oga.parse_html data

    adjust_font_size = opts[:adjust_font_size]
    raise PrawnStyledText::AdjustFontSizeError if adjust_font_size && !adjust_font_size.respond_to?(:call)

    PrawnStyledText::traverse oga.children do |type, text, data|
      context = if type == :text_node
          PrawnStyledText::text_node( self, data, adjust_font_size )
        elsif type == :opening_tag
          PrawnStyledText::opening_tag( self, data, adjust_font_size )
        else
          PrawnStyledText::closing_tag( self, data, adjust_font_size )
        end
      if context[:flush] && parts.any? # flush current parts
        parts[0][:text] = parts[0][:text].lstrip
        parts.shift if parts[0][:text].empty?
        if parts.any?
          parts[-1][:text] = parts[-1][:text].rstrip
          parts.pop if parts[-1][:text].empty?
        end
        if parts.any?
          self.indent( extra_options[:margin_left] ) do
            if (pre = extra_options[:pre])
              formatted_text_with_pre(parts, pre, text_options)
            else
              self.formatted_text parts, text_options
            end
          end
        end
        parts = []
        text_options = {}
        extra_options = { margin_left: 0 }
      end
      options = context[:options]
      if type == :text_node
        text_options[:align] = serialize_text_align(options[:'text-align']) if options[:'text-align']
        margin_top = options.delete( :'margin-top' ).to_i
        self.move_down( margin_top ) if margin_top > 0
        margin_left = options.delete( :'margin-left' ).to_i
        extra_options[:margin_left] = margin_left if margin_left > 0
        if !text_options[:leading] && ( leading = options.delete( :'line-height' ).to_i ) > 0
          text_options[:leading] = leading
        end
        text_options[:mode] = options[:mode].to_sym if options[:mode]
        extra_options[:pre] = context[:pre] if context[:pre]
        parts << { text: text }.merge( options ) # push the data
      elsif type == :closing_tag
        self.formatted_text( context[:text] ) if context[:text]
        if context[:tag] == :hr
          self.dash( options[:dash].include?( ',' ) ? options[:dash].split( ',' ).map( &:to_i ) : options[:dash].to_i ) if options[:dash]
          if options[:color]
            last_stroke_color = self.stroke_color
            self.stroke_color( options[:color] )
          end
          self.stroke_horizontal_rule
          self.stroke_color( last_stroke_color ) if options[:color]
          self.undash if options[:dash]
        elsif context[:tag] == :img && context[:src]
          image_options = {}
          image_options[:scale] = options[:'image-scale'].to_f if options[:'image-scale']
          if options[:'image-at']
            xy = options[:'image-at'].split( ',' ).map &:to_i
            image_options[:at] = xy if xy.count == 2
          end
          if options[:'image-position']
            pos = options[:'image-position'].to_i
            image_options[:position] = pos > 0 ? pos : options[:'image-position']
          end
          image_options[:width]  = options[:width]  if options[:width]
          image_options[:height] = options[:height] if options[:height]
          self.image context[:src], image_options
        elsif context[:tag] == :p
          if opts[:margin_bottom]
            self.move_down opts[:margin_bottom]
          end
        end
      end
    end
    self.formatted_text parts, text_options
  end

  private

  def formatted_text_with_pre(parts, pre, text_options)
    self.float do
      self.formatted_text([parts.first.merge(text: pre)], text_options)
    end

    self.indent(self.width_of(pre)) do
      self.formatted_text(parts, text_options)
    end
  end

  def serialize_text_align(align)
    case align
    when 'start'
      :left
    when 'end'
      :right
    else
      align.to_sym
    end
  end
end
