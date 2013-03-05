require 'optparse'
require 'ostruct'
require '../cdk'

class Example
  def Example.parse_opts(opts, params)
    if params.box
      opts.on('-N', "Disable box") do
        params.box = false
      end
    else
      opts.on('-N', "Enable box") do
        params.box = true
      end
    end

    if params.shadow
      opts.on('-S', 'Disable shadow') do
        params.shadow = false
      end
    else
      opts.on('-S', "Enable shadow") do
        params.shadow = true
      end
    end

    opts.on('-X XPOS', OptionParser::DecimalInteger, "X position") do |x|
      params.x_value = x
    end

    opts.on('-Y YPOS', OptionParser::DecimalInteger, "Y position") do |y|
      params.y_value = y
    end
  end

  def Example.parse(args)
    params = OpenStruct.new
    opt_parser = OptionParser.new do |opts|
      parse_opts(opts, params)
    end

    opt_parser.parse!(args)

    return params
  end
end

class CLIExample < Example
  def CLIExample.parse_opts(opts, params)
    super(opts, params)

    opts.on('-H HEIGHT', OptionParser::DecimalInteger, "Widget height") do |h|
      puts "H: %s" % [h]
      params.h_value = h
    end

    opts.on('-W WIDTH', OptionParser::DecimalInteger, "Widget width") do |w|
      params.w_value = w
    end

    return params
  end
end
